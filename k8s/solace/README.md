# WebSubHub Kubernetes Deployment - Solace

This directory contains Kubernetes deployment configurations for WSO2 WebSubHub with Solace PubSub+ as the message broker backend.

## Overview

The Kubernetes deployment consists of:
- **Solace PubSub+ Standard** - Message broker (deployed via official Helm chart)
- **WebSubHub Hub** - Main WebSub hub service (StatefulSet via Helm)
- **WebSubHub Consolidator** - Event processor (Deployment via Helm)

## Prerequisites

- Kubernetes cluster (v1.19+) or Minikube
- Helm 3.x installed
- kubectl configured to access your cluster
- Docker images for WebSubHub components (built using `websubhub-docker-build.sh`)
- Minimum resources for Solace dev deployment: 1 CPU, 2GB memory, 5Gi storage

## Using Minikube for Local Development

If you're using Minikube for local Kubernetes development, you can build Docker images directly in Minikube's Docker daemon. This eliminates the need to push images to a remote registry.

### Setup Minikube Environment

1. **Start Minikube** (if not already running):
   ```bash
   minikube start
   ```

2. **Point your Docker CLI to Minikube's Docker daemon**:
   ```bash
   eval $(minikube docker-env)
   ```

   This command configures your shell to use Minikube's Docker daemon. All `docker` commands in this shell will now interact with Minikube's internal Docker registry.

3. **Build WebSubHub images** using the build script:
   ```bash
   cd /path/to/websubhub-deployment
   ./websubhub-docker-build.sh --clone-dir /tmp/websubhub --skip-tests
   ```

   The images will be built directly in Minikube's Docker daemon and will be immediately available to the cluster.

4. **Verify images are available in Minikube**:
   ```bash
   minikube ssh docker images | grep wso2
   ```

   You should see:
   - `wso2/wso2websubhub:latest`
   - `wso2/wso2websubhub-consolidator:latest`

### Important Notes for Minikube

When deploying with locally built images in Minikube:

- **Image Pull Policy**: Set `imagePullPolicy: IfNotPresent` or `imagePullPolicy: Never` in your Helm values to prevent Kubernetes from trying to pull images from Docker Hub.

- **Separate Terminal Sessions**: The `eval $(minikube docker-env)` command only affects the current shell session. If you open a new terminal, you'll need to run it again.

- **Reset to Local Docker**: To switch back to your local Docker daemon:
  ```bash
  eval $(minikube docker-env -u)
  ```

### Minikube Deployment Example

```bash
# Point to Minikube's Docker daemon
eval $(minikube docker-env)

# Build WebSubHub images
./websubhub-docker-build.sh --clone-dir /tmp/websubhub --skip-tests

# Create namespace
kubectl create namespace websubhub

# Add Solace Helm repository
helm repo add solacecharts https://solaceproducts.github.io/pubsubplus-kubernetes-helm-quickstart/helm-charts
helm repo update

# Deploy Solace broker using official Helm chart
cd k8s/solace
helm install solace solacecharts/pubsubplus-dev -n websubhub --set solace.usernameAdminPassword="password"

# Deploy WebSubHub components with local images (using IfNotPresent)
helm install websubhub-consolidator ./helm/websubhub-consolidator -n websubhub

helm install websubhub ./helm/websubhub -n websubhub
```

## Directory Structure

```
k8s/solace/
├── helm/
│   ├── websubhub/              # Helm chart for WebSubHub Hub
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── confs/
│   │   │   └── Config.toml     # Templated configuration
│   │   └── templates/
│   │       ├── conf.yaml       # ConfigMap
│   │       ├── service.yaml    # Service
│   │       └── statefulset.yaml # StatefulSet
│   └── websubhub-consolidator/ # Helm chart for Consolidator
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── confs/
│       │   └── Config.toml     # Templated configuration
│       └── templates/
│           ├── conf.yaml       # ConfigMap
│           ├── service.yaml    # Service
│           └── deployment.yaml # Deployment
├── solace-values.yaml          # Custom values for Solace Helm chart
└── README.md
```

## Deployment Steps

### Step 1: Deploy Solace Broker

First, deploy the Solace PubSub+ message broker using the official Helm chart:

```bash
# Create namespace
kubectl create namespace websubhub

# Add Solace Helm repository
helm repo add solacecharts https://solaceproducts.github.io/pubsubplus-kubernetes-helm-quickstart/helm-charts
helm repo update

# Deploy Solace PubSub+ (minimal dev configuration)
helm install solace solacecharts/pubsubplus-dev \
  --namespace websubhub \
  -f solace-values.yaml
```

Wait for Solace to be ready:

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=solace -n websubhub --timeout=300s
```

Check Solace pod status:

```bash
kubectl get pods -n websubhub -l app.kubernetes.io/instance=solace
```

### Step 1.1: Test Solace Broker Connection

Once the Solace broker is running, test the connection:

**1. Check broker logs to verify it's running:**
```bash
kubectl logs -l app.kubernetes.io/instance=solace -n websubhub --tail=50
```

Look for messages indicating the broker is ready, such as:
```
*                          Solace PubSub+ Standard                          *
*                            (Standalone Mode)                              *
```

**2. Access the Solace Admin UI:**
```bash
kubectl port-forward svc/solace-pubsubplus-dev 8080:8080 -n websubhub
```

Then open your browser to `http://localhost:8080` and login with:
- **Username**: `admin`
- **Password**: `admin`

You should see the Solace PubSub+ Manager interface showing broker status and statistics.

**3. Test SMF port connectivity:**

Create a test pod to verify connectivity to the SMF port (55555):

```bash
kubectl run test-solace --image=busybox --rm -it --restart=Never -n websubhub -- sh -c "nc -zv solace-pubsubplus-dev 55555"
```

Expected output:
```
solace-pubsubplus-dev (10.x.x.x:55555) open
```

**4. Verify broker services:**
```bash
kubectl get svc -l app.kubernetes.io/instance=solace -n websubhub
```

You should see the Solace services with the following ports exposed:
- `55555` - SMF (messaging protocol)
- `8080` - SEMP/Admin UI
- `9000` - REST messaging (if enabled)
- `1883` - MQTT (if enabled)

**5. Check broker health status:**

You can use the Solace CLI through the pod:

```bash
kubectl exec -it -n websubhub $(kubectl get pod -l app.kubernetes.io/instance=solace -n websubhub -o jsonpath='{.items[0].metadata.name}') -- cli

# Once in the CLI, run:
show service
show redundancy
```

Type `exit` to leave the CLI.

If all tests pass, your Solace broker is ready and you can proceed to deploy the WebSubHub components.

### Step 2: Deploy WebSubHub Consolidator

Deploy the Consolidator using Helm:

```bash
helm install websubhub-consolidator ./helm/websubhub-consolidator \
  --namespace websubhub \
  --set deployment.image.tag=latest
```

Verify the deployment:

```bash
kubectl get pods -n websubhub -l app=websubhub-consolidator
```

### Step 3: Deploy WebSubHub Hub

Deploy the Hub using Helm:

```bash
helm install websubhub ./helm/websubhub \
  --namespace websubhub \
  --set deployment.image.tag=latest
```

Verify the deployment:

```bash
kubectl get pods -n websubhub -l app=websubhub
```

### Step 4: Verify All Services

Check all deployments:

```bash
kubectl get all -n websubhub
```

You should see:
- `solace-0` pod (Solace broker)
- `websubhub-consolidator-deployment-*` pod (Consolidator)
- `websubhub-deployment-0` pod (Hub)
- Services for each component

## Accessing Services

### Port Forwarding

To access services from your local machine:

**WebSubHub Hub:**
```bash
kubectl port-forward svc/websubhub-service 9000:9000 -n websubhub
```

**Consolidator:**
```bash
kubectl port-forward svc/websubhub-consolidator-service 10001:10001 -n websubhub
```

**Solace Admin:**
```bash
kubectl port-forward svc/solace-pubsubplus-dev 8080:8080 -n websubhub
```

Then access the admin UI at `http://localhost:8080` (username: `admin`, password: `admin`)

### Ingress (Optional)

To expose services externally, update the Helm values:

```yaml
# For WebSubHub Hub
ingress:
  enabled: true
  hostname: websubhub.example.com
  path: /hub
  pathType: Prefix

# For Consolidator
ingress:
  enabled: true
  hostname: websubhub-consolidator.example.com
  path: /consolidator
  pathType: Prefix
```

Then upgrade the Helm releases:

```bash
helm upgrade websubhub ./helm/websubhub -n websubhub -f custom-values.yaml
helm upgrade websubhub-consolidator ./helm/websubhub-consolidator -n websubhub -f custom-values.yaml
```

## Configuration

### Customizing Values

You can customize the deployment by creating a `custom-values.yaml` file:

```yaml
# Example custom-values.yaml for WebSubHub Hub
deployment:
  replicas: 2
  image:
    tag: "1.0.0"
  config:
    server:
      id: "websubhub-k8s"
    delivery:
      timeout: 90
      retry:
        count: 5

logging:
  level: "DEBUG"
```

Apply custom values:

```bash
helm install websubhub ./helm/websubhub -n websubhub -f custom-values.yaml
```

### Updating Configuration

To update the configuration after deployment:

1. Modify your custom values file
2. Upgrade the Helm release:

```bash
helm upgrade websubhub ./helm/websubhub -n websubhub -f custom-values.yaml
```

## Scaling

### Scale WebSubHub Hub

```bash
kubectl scale statefulset websubhub-deployment -n websubhub --replicas=3
```

Or update via Helm:

```bash
helm upgrade websubhub ./helm/websubhub -n websubhub --set deployment.replicas=3
```

### Scale Consolidator

```bash
kubectl scale deployment websubhub-consolidator-deployment -n websubhub --replicas=2
```

Or update via Helm:

```bash
helm upgrade websubhub-consolidator ./helm/websubhub-consolidator -n websubhub --set deployment.replicas=2
```

## Monitoring

### View Logs

**WebSubHub Hub:**
```bash
kubectl logs -f statefulset/websubhub-deployment -n websubhub
```

**Consolidator:**
```bash
kubectl logs -f deployment/websubhub-consolidator-deployment -n websubhub
```

**Solace:**
```bash
kubectl logs -f statefulset/solace -n websubhub
```

### Check Service Health

```bash
# Check pod status
kubectl get pods -n websubhub

# Describe pod for details
kubectl describe pod <pod-name> -n websubhub

# Check events
kubectl get events -n websubhub --sort-by='.lastTimestamp'
```

## Testing WebSubHub

Once deployed, you can test WebSubHub by port-forwarding and following the testing steps from the main README:

1. Port forward the Hub service:
   ```bash
   kubectl port-forward svc/websubhub-service 9000:9000 -n websubhub
   ```

2. Register a topic:
   ```bash
   curl -X POST https://localhost:9000/hub \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "hub.mode=register" \
     -d "hub.topic=news" \
     -k
   ```

3. Subscribe to the topic (replace with your webhook URL):
   ```bash
   curl -X POST "https://localhost:9000/hub" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "hub.topic=news" \
     -d "hub.callback=<callback-url>" \
     -d "hub.mode=subscribe" \
     -d "hub.secret=mysecret" \
     -d "hub.lease_seconds=50000000" \
     -k
   ```

4. Publish content:
   ```bash
   curl -X POST "https://localhost:9000/hub?hub.mode=publish&hub.topic=news" \
     -H "Content-Type: application/json" \
     -d '{"message": "Kubernetes deployment test"}' \
     -k
   ```

## Troubleshooting

### Pod Not Starting

Check pod status and events:
```bash
kubectl describe pod <pod-name> -n websubhub
kubectl logs <pod-name> -n websubhub
```

Common issues:
- Image pull errors: Verify Docker images are available
- ConfigMap errors: Check if ConfigMaps are created correctly
- Network issues: Verify service names and ports

### Service Connectivity Issues

Test service connectivity from within the cluster:

```bash
# Create a test pod
kubectl run test-pod --image=busybox -n websubhub --rm -it -- sh

# Test Solace connectivity
nc -zv solace 55555

# Test Consolidator connectivity
nc -zv websubhub-consolidator-service 10001

# Test Hub connectivity
nc -zv websubhub-service 9000
```

### Solace Broker Issues

Check Solace logs:
```bash
kubectl logs -l app.kubernetes.io/instance=solace -n websubhub
```

Access Solace admin interface:
```bash
kubectl port-forward svc/solace-pubsubplus-dev 8080:8080 -n websubhub
```

Then navigate to `http://localhost:8080` (username: `admin`, password: `admin`)

Check Helm release status:
```bash
helm status solace -n websubhub
```

If the deployment fails, you can check the Helm release:
```bash
helm list -n websubhub
helm get values solace -n websubhub
```

For detailed pod information:
```bash
kubectl describe pod -l app.kubernetes.io/instance=solace -n websubhub
```

### Configuration Issues

Verify ConfigMaps are created correctly:
```bash
kubectl get configmap -n websubhub
kubectl describe configmap websubhub-svc-cm -n websubhub
kubectl describe configmap websubhub-consolidator-svc-cm -n websubhub
```

## Uninstalling

To remove the deployment:

```bash
# Uninstall Helm releases
helm uninstall websubhub -n websubhub
helm uninstall websubhub-consolidator -n websubhub
helm uninstall solace -n websubhub

# Delete namespace (optional)
kubectl delete namespace websubhub
```

## Resource Requirements

### Minimum Requirements

- **Solace Broker** (dev chart): 1 CPU, 2GB memory, 5Gi storage
- **WebSubHub Hub**: 512Mi memory, 250m CPU (per replica)
- **Consolidator**: 512Mi memory, 250m CPU (per replica)

### Storage Requirements

- **Solace**: 5Gi (configured in solace-values.yaml)
- **WebSubHub**: No persistent storage required (uses Solace for state)

The `pubsubplus-dev` Helm chart is optimized for development with minimal resource footprint. For production deployments, consider using the `pubsubplus` or `pubsubplus-ha` charts with appropriate resource allocation.

You can customize Solace resources in `solace-values.yaml`:

```yaml
resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 2
    memory: 4Gi
```

## About the Solace Deployment

This deployment uses the official Solace PubSub+ Helm chart (`pubsubplus-dev`) which provides:

- **Official Support**: Maintained by Solace, following best practices
- **Minimal Footprint**: Optimized for development with 1 CPU, 2GB RAM
- **Easy Upgrades**: Simple version management through Helm
- **Production Path**: Easy migration to `pubsubplus` or `pubsubplus-ha` charts for production

The `pubsubplus-dev` chart is specifically designed for development and testing. It provides a standalone broker instance with minimal resource requirements and no guaranteed performance.

### Customization

You can customize the deployment by modifying `solace-values.yaml`:

```yaml
# Example customizations
solace:
  usernameAdminPassword: your-password

storage:
  size: 10Gi  # Increase storage

service:
  type: LoadBalancer  # Expose externally
```

For more configuration options, see the [Solace Helm Chart documentation](https://github.com/SolaceProducts/pubsubplus-kubernetes-helm-quickstart).

## Additional Resources

- [WebSubHub Documentation](https://wso2.github.io/docs-websubhub/)
- [Solace PubSub+ Helm Chart](https://github.com/SolaceProducts/pubsubplus-kubernetes-helm-quickstart)
- [Solace Documentation](https://docs.solace.com/)
- [Solace Kubernetes Quick Start](https://docs.solace.com/Developer-Tools/QuickStarts/Quickstart-Kubernetes.htm)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
