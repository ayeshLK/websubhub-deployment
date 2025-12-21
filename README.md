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

### For Docker Deployment
- **Docker** and **Docker Compose** installed
- **Docker Buildx** for multi-architecture builds
- **Java 21+** for building the project
- **Ballerina SL 2201.13.1+** for building the project
- **Git** for cloning repositories

### For Kubernetes Deployment (Optional)
- **Kubernetes cluster** (v1.19+) or **Minikube** for local development
- **Helm 3.x** for chart deployment
- **kubectl** configured to access your cluster

## Building Docker Images

Use the `websubhub-docker-build.sh` script to clone, build, and create Docker images for WebSubHub components.

### Basic Usage

```bash
./websubhub-docker-build.sh --clone-dir /tmp/websubhub
```

This will:
1. Clone the WebSubHub repository to the specified directory
2. Check Java version (requires Java 21+)
3. Build the project with Gradle
4. Build Docker images for all components
5. Create `.env` files in broker directories with the built version

### Script Options

```bash
./websubhub-docker-build.sh --clone-dir <dir> [OPTIONS]

Required:
  --clone-dir <dir>   Directory to clone the repository into (REQUIRED)

Options:
  --skip-build        Skip Gradle build step (use existing build artifacts)
  --skip-tests        Skip tests during Gradle build
  --push              Push images to Docker Hub
  --username <user>   Docker Hub username (default: wso2)
  --help              Show help message
```

### Examples

Build with tests:
```bash
./websubhub-docker-build.sh --clone-dir /tmp/websubhub
```

Build without tests (faster):
```bash
./websubhub-docker-build.sh --clone-dir /tmp/websubhub --skip-tests
```

Build and push to Docker Hub:
```bash
export DOCKERHUB_TOKEN="your-token"
./websubhub-docker-build.sh --clone-dir /tmp/websubhub --skip-tests --push --username yourusername
```

## Deploying WebSubHub

After building the Docker images, deploy WebSubHub using Docker Compose with your preferred message broker.

### Supported Message Brokers

This repository provides deployment configurations for multiple message brokers:
- **Solace PubSub+** - Enterprise-grade messaging platform
- **Apache Kafka** - High-throughput distributed streaming platform

### Deploying with Solace

Navigate to the Solace broker directory:
```bash
cd docker/solace
```

Start the services:
```bash
docker-compose up -d
```

This will start:
- **Solace PubSub+** message broker
- **WebSubHub Consolidator** (event processor)
- **WebSubHub Hub** (main service)

**Accessing Solace Services:**
- **WebSubHub Hub**: `https://localhost:9000`
- **Consolidator**: `http://localhost:10001`
- **Solace Admin**: `http://localhost:8085` (username: `admin`, password: `admin`)
- **Solace Messaging**: `localhost:55554`

### Deploying with Kafka

Navigate to the Kafka broker directory:
```bash
cd docker/kafka
```

Start the services:
```bash
docker-compose up -d
```

This will start:
- **Apache Kafka** (KRaft mode, no Zookeeper required)
- **WebSubHub Consolidator** (event processor)
- **WebSubHub Hub** (main service)

**Accessing Kafka Services:**
- **WebSubHub Hub**: `https://localhost:9000`
- **Consolidator**: `http://localhost:10001`
- **Kafka Broker**: `localhost:9092`

### Common Operations

Check the status:
```bash
docker-compose ps
```

View logs:
```bash
docker-compose logs -f
```

View logs for a specific service:
```bash
docker-compose logs -f hub
docker-compose logs -f consolidator
```

Stop the services:
```bash
docker-compose down
```

Remove volumes (clean state):
```bash
docker-compose down -v
```

### Configuration

Configuration files for each component are located in the broker directory:
- `Config.hub.toml` - Hub service configuration
- `Config.consolidator.toml` - Consolidator service configuration

The WebSubHub version is automatically set in `.env` files by the build script.

## Deploying on Kubernetes

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
./websubhub-docker-build.sh --clone-dir /tmp/websubhub --skip-tests

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
curl -X POST https://localhost:9000/hub \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "hub.mode=register" \
  -d "hub.topic=news" \
  -k
```

### Step 2: Subscribe to the Topic

First, create a webhook at [webhook.site](https://webhook.site) and copy your unique URL.

Then, subscribe to the topic (replace `<callback-url>` with your URL-encoded webhook URL):

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

### Step 3: Publish Content

Publish content to the topic:

```bash
curl -X POST "https://localhost:9000/hub?hub.mode=publish&hub.topic=news" \
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
├── websubhub-docker-build.sh    # Build script
├── .gitignore
└── README.md
```

## Continuous Integration

This repository includes a GitHub Actions workflow that automatically validates:
- Build script syntax (`websubhub-docker-build.sh`)
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
docker-compose logs <service-name>
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
   docker-compose logs kafka
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
./websubhub-docker-build.sh --clone-dir /tmp/websubhub

# Restart services (use your broker directory)
cd docker/kafka  # or docker/solace
docker-compose down
docker-compose up -d
```

## Additional Resources

- [WebSubHub Documentation](https://wso2.github.io/docs-websubhub/)
- [WebSubHub GitHub Repository](https://github.com/wso2/product-integrator-websubhub)
- [W3C WebSub Specification](https://www.w3.org/TR/websub/)
- [Solace Documentation](https://docs.solace.com/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Ballerina Documentation](https://ballerina.io/learn/)
