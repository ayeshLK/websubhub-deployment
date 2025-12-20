# WebSubHub Kubernetes Deployment - Solace

This directory contains Kubernetes deployment configurations for WSO2 WebSubHub with Solace PubSub+ as the message broker backend.

## Overview

The Kubernetes deployment consists of:
- **Solace PubSub+ Standard** - Message broker (StatefulSet)
- **WebSubHub Hub** - Main WebSub hub service (StatefulSet via Helm)
- **WebSubHub Consolidator** - Event processor (Deployment via Helm)

## Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.x installed
- kubectl configured to access your cluster
- Docker images for WebSubHub components (built using `websubhub-docker-build.sh`)

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
├── manifests/
│   └── solace-deployment.yaml  # Solace broker manifests
└── README.md
```

## Deployment Steps

### Step 1: Deploy Solace Broker

First, deploy the Solace PubSub+ message broker:

```bash
kubectl create namespace websubhub
kubectl apply -f manifests/solace-deployment.yaml -n websubhub
```

Wait for Solace to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=solace -n websubhub --timeout=300s
```

Check Solace pod status:

```bash
kubectl get pods -n websubhub -l app=solace
```

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
kubectl port-forward svc/solace 8085:8080 -n websubhub
```

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
kubectl logs -f statefulset/solace -n websubhub
```

Access Solace admin interface:
```bash
kubectl port-forward svc/solace 8085:8080 -n websubhub
```

Then navigate to `http://localhost:8085` (username: `admin`, password: `admin`)

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

# Delete Solace deployment
kubectl delete -f manifests/solace-deployment.yaml -n websubhub

# Delete namespace (optional)
kubectl delete namespace websubhub
```

## Resource Requirements

### Minimum Requirements

- **Solace Broker**: 1Gi memory, 500m CPU
- **WebSubHub Hub**: 512Mi memory, 250m CPU (per replica)
- **Consolidator**: 512Mi memory, 250m CPU (per replica)

### Storage Requirements

- **Solace**: 10Gi total (5Gi per PVC)
- **WebSubHub**: No persistent storage required (uses Solace for state)

You can adjust resource limits in the Helm values:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

## Additional Resources

- [WebSubHub Documentation](https://wso2.github.io/docs-websubhub/)
- [Solace Documentation](https://docs.solace.com/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
