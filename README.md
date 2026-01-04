# WebSubHub Deployment

[![Validation](https://github.com/ayeshLK/websubhub-deployment/actions/workflows/validation.yml/badge.svg)](https://github.com/ayeshLK/websubhub-deployment/actions/workflows/validation.yml)

This repository provides Docker and Kubernetes-based deployment configurations for WSO2 WebSubHub with support for multiple message broker backends. It's designed to simulate WebSubHub deployments and facilitate running various test scenarios.

## Overview

WebSubHub is a publish-subscribe hub implementation based on the W3C WebSub specification. This repository helps you:
- Build Docker images for WebSubHub components
- Deploy WebSubHub with different message broker backends (Solace, Kafka)
- Deploy WebSubHub on Kubernetes using Helm charts
- Run integration tests and validate WebSub functionality

## Prerequisites

### Required for All Deployment Scenarios

- **Docker** and **Docker Compose**
- **Git** for cloning repositories

**System Configuration:**

Add the following entries to `/etc/hosts` on your machine:

```shell
127.0.0.1 dev.websubhub.com
127.0.0.2 dev.websubhub.com
```

### Additional Requirements Based on Deployment Mode

#### If Building from Source (`--clone-dir`)

- **Docker Buildx** - For building multi-architecture images
- **Java 21+** - Verified automatically by the build script
- **Ballerina SL 2201.13.1+** - Required for building WebSubHub components

#### If Using Released Versions (`--deployment-version`)

No additional requirements. The script will only update configuration files with the specified version.

#### If Deploying on Kubernetes

- **Kubernetes cluster** (v1.19+) or **Minikube** for local development
- **Helm 3.x** for managing chart deployments
- **kubectl** configured to access your cluster

## Preparing for Deployment

The `prepare-deployment.sh` script supports **two deployment modes**. Choose the appropriate mode based on your needs:

### Mode 1: Build from Source

Use this mode when you want to build WebSubHub components from the latest source code or a specific branch.

**Basic Command:**
```bash
./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-tests
```

**What this does:**
1. Clones the WebSubHub repository to the specified directory
2. Validates Java 21+ is installed
3. Builds the project with Gradle
4. Creates Docker images for all components (Hub, Consolidator)
5. Loads images into local Docker daemon
6. Generates `.env` files in `docker/kafka/` and `docker/solace/` with the extracted version

**Available Options:**
```bash
./prepare-deployment.sh --clone-dir <directory> [OPTIONS]

Required:
  --clone-dir <dir>    Directory where WebSubHub source will be cloned

Optional:
  --skip-tests         Skip running tests during Gradle build (faster)
  --skip-build         Skip Gradle build (use existing artifacts)
```

**Examples:**
```bash
# Build with tests
./prepare-deployment.sh --clone-dir /tmp/websubhub

# Build without tests (recommended for faster builds)
./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-tests

# Skip build entirely (use existing build artifacts)
./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-build --skip-tests
```

### Mode 2: Use a Released Version

Use this mode when you want to deploy a specific released version of WebSubHub without building from source.

**Command:**
```bash
./prepare-deployment.sh --deployment-version <version>
```

**What this does:**
1. Updates `.env` files in `docker/kafka/` and `docker/solace/` with the specified version
2. Exits immediately (no cloning, building, or image creation)

**Important:** Version must be in plain format (e.g., `1.0.0`), not semver-tagged (e.g., `v1.0.0`).

**Example:**
```bash
./prepare-deployment.sh --deployment-version 1.0.0
```

**Note:** This mode assumes the Docker images for the specified version are already available in a registry that your Docker daemon can pull from.

## Deploying WebSubHub

After preparing your deployment (building images or configuring a released version), you can deploy WebSubHub using Docker Compose or Kubernetes with your preferred message broker.

### Supported Message Brokers

This repository provides deployment configurations for:
- **Apache Kafka** - High-throughput distributed streaming platform
- **Solace PubSub+** - Enterprise-grade messaging platform

### Docker Deployment

WebSubHub can be deployed locally using Docker Compose with either Kafka or Solace as the message broker backend.

#### Quick Start

1. **Navigate to your broker directory:**
   ```bash
   cd docker/kafka    # For Kafka deployment
   # OR
   cd docker/solace   # For Solace deployment
   ```

2. **Start all services:**
   ```bash
   docker compose up -d
   ```

   This starts three services in the following order:
   - Message broker (Kafka or Solace)
   - WebSubHub Consolidator (depends on broker)
   - WebSubHub Hub (depends on Consolidator)

3. **Verify services are running:**
   ```bash
   docker compose ps
   ```

#### Accessing Services

**For Kafka Deployment:**
- WebSubHub Hub: `https://dev.websubhub.com/hub`
- Kafka Bootstrap Server: `localhost:9092` (for external clients)

**For Solace Deployment:**
- WebSubHub Hub: `https://dev.websubhub.com/hub`
- Solace Admin UI: `http://localhost:8085` (username: `admin`, password: `admin`)
- Solace SMF Port: `55555`

#### Managing Your Deployment

**View all logs:**
```bash
docker compose logs -f
```

**View logs for a specific service:**
```bash
docker compose logs -f hub           # Hub service logs
docker compose logs -f consolidator  # Consolidator service logs
docker compose logs -f kafka         # Kafka broker logs
docker compose logs -f solace        # Solace broker logs
```

**Check service health:**
```bash
docker compose ps
```

**Stop all services:**
```bash
docker compose down
```

**Clean deployment (remove volumes):**
```bash
docker compose down -v
```

#### Configuration Files

Each broker deployment directory contains configuration files:

- `Config.hub.toml` - Hub service configuration (ports, SSL, topics)
- `Config.consolidator.toml` - Consolidator configuration (broker connection settings)
- `.env` - Version configuration (auto-generated by `prepare-deployment.sh`)
- `docker-compose.yml` - Service orchestration and networking

**Version Synchronization:**
The `.env` file contains `WEBSUBHUB_VERSION` which must match the version in your Docker images. This is automatically managed by the preparation script.

### Deploying on Kubernetes

WebSubHub can also be deployed on Kubernetes using Helm charts. This provides better scalability, high availability, and production-grade orchestration.

### Prerequisites for Kubernetes

- Kubernetes cluster (v1.19+)
- Helm 3.x installed
- kubectl configured to access your cluster
- Docker images built (using the build script above)

### Kubernetes Deployment with Solace

Navigate to the Kubernetes Solace directory:
```bash
cd k8s/solace
```

For detailed deployment instructions, configuration options, and troubleshooting, see the [Kubernetes Solace README](k8s/solace/README.md).

**Quick Start (for Cloud/Production):**

1. Deploy Solace broker:
   ```bash
   kubectl create namespace websubhub
   kubectl apply -f manifests/solace-deployment.yaml -n websubhub
   ```

2. Deploy WebSubHub Consolidator:
   ```bash
   helm install websubhub-consolidator ./helm/websubhub-consolidator --namespace websubhub
   ```

3. Deploy WebSubHub Hub:
   ```bash
   helm install websubhub ./helm/websubhub --namespace websubhub
   ```

4. Access services via port-forwarding:
   ```bash
   kubectl port-forward svc/websubhub-service 9000:9000 -n websubhub
   ```

**Quick Start (for Minikube/Local Development):**

When using Minikube, build images directly in Minikube's Docker daemon:

```bash
# Point Docker to Minikube's daemon
eval $(minikube docker-env)

# Build images
./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-tests

# Deploy (note: using IfNotPresent for local images)
kubectl create namespace websubhub
kubectl apply -f k8s/solace/manifests/solace-deployment.yaml -n websubhub
helm install websubhub-consolidator ./k8s/solace/helm/websubhub-consolidator \
  --namespace websubhub \
  --set deployment.image.pullPolicy=IfNotPresent
helm install websubhub ./k8s/solace/helm/websubhub \
  --namespace websubhub \
  --set deployment.image.pullPolicy=IfNotPresent

# Access services
kubectl port-forward svc/websubhub-service 9000:9000 -n websubhub
```

For complete documentation including Minikube setup, scaling, monitoring, and advanced configuration, refer to the [k8s/solace/README.md](k8s/solace/README.md).

## Testing WebSubHub

### Step 1: Register a Topic

Register a topic with the hub:

```bash
curl -X POST https://dev.websubhub.com/hub \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "hub.mode=register" \
  -d "hub.topic=news" \
  -k
```

### Step 2: Subscribe to the Topic

First, create a webhook at [webhook.site](https://webhook.site) and copy your unique URL.

Then, subscribe to the topic (replace `<callback-url>` with your URL-encoded webhook URL):

```bash
curl -X POST "https://dev.websubhub.com/hub" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "hub.topic=news" \
  -d "hub.callback=<callback-url>" \
  -d "hub.mode=subscribe" \
  -d "hub.secret=mysecret" \
  -d "hub.lease_seconds=50000000" \
  -k
```

### Step 3: Publish Content

Publish content to the topic:

```bash
curl -X POST "https://dev.websubhub.com/hub?hub.mode=publish&hub.topic=news" \
  -H "Content-Type: application/json" \
  -d '{"message": "This is a test message"}' \
  -k
```

### Step 4: Verify Delivery

Check your webhook.site URL to see the delivered content. You should see the published message arrive at your webhook endpoint.

## Project Structure

```
websubhub-deployment/
├── .github/
│   └── workflows/
│       └── validation.yml       # CI workflow for syntax validation
├── docker/
│   ├── kafka/                   # Kafka broker deployment
│   │   ├── docker-compose.yml
│   │   ├── Config.hub.toml
│   │   ├── Config.consolidator.toml
│   │   └── .env                 # Auto-generated version file
│   └── solace/                  # Solace broker deployment
│       ├── docker-compose.yml
│       ├── Config.hub.toml
│       ├── Config.consolidator.toml
│       └── .env                 # Auto-generated version file
├── k8s/
│   └── solace/                  # Kubernetes deployment with Solace
│       ├── helm/
│       │   ├── websubhub/       # Helm chart for WebSubHub Hub
│       │   └── websubhub-consolidator/  # Helm chart for Consolidator
│       ├── manifests/
│       │   └── solace-deployment.yaml   # Solace broker manifests
│       └── README.md            # Kubernetes deployment guide
├── prepare-deployment.sh        # Build and preparation script
├── .gitignore
└── README.md
```

## Continuous Integration

This repository includes a GitHub Actions workflow that automatically validates:
- Build script syntax (`prepare-deployment.sh`)
- Docker Compose configuration files
- Required files and directory structure

The validation runs on every push and pull request to ensure the repository remains in a working state. Check the status badge at the top of this README.

## Troubleshooting

### Port Conflicts

If you encounter port conflicts, modify the port mappings in `docker-compose.yml`:
```yaml
ports:
  - '9001:9000'  # Change left side to available port
```

### Health Check Failures

If services fail to start, check the logs:
```bash
docker compose logs <service-name>
```

Common issues:
- Java version mismatch (ensure Java 21+ is used during build)
- Ballerina version mismatch (ensure Ballerina SL 2201.13.1+ is used)
- Missing configuration files
- Insufficient Docker resources (increase memory/CPU allocation)

### Kafka Connectivity Issues

If WebSubHub can't connect to Kafka:
1. Verify Kafka is healthy:
   ```bash
   docker compose logs kafka
   ```

2. Check if Kafka advertised listeners are configured correctly in `docker-compose.yml`:
   ```yaml
   KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
   ```

3. Verify the consolidator config uses the correct bootstrap server:
   ```toml
   [websubhub.consolidator.config.store.kafka]
   bootstrapServers = "kafka:9092"
   ```

4. Test Kafka connectivity from consolidator:
   ```bash
   docker exec -it websubhub-consolidator nc -zv kafka 9092
   ```

### Rebuilding Images

To rebuild after code changes:
```bash
# Rebuild with the build script
./prepare-deployment.sh --clone-dir /tmp/websubhub

# Restart services (use your broker directory)
cd docker/kafka  # or docker/solace
docker compose down
docker compose up -d
```

## Additional Resources

- [WebSubHub Documentation](https://wso2.github.io/docs-websubhub/)
- [WebSubHub GitHub Repository](https://github.com/wso2/product-integrator-websubhub)
- [W3C WebSub Specification](https://www.w3.org/TR/websub/)
- [Solace Documentation](https://docs.solace.com/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Ballerina Documentation](https://ballerina.io/learn/)
