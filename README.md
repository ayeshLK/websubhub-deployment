# WebSubHub Deployment

[![Validation](https://github.com/ayeshLK/websubhub-deployment/actions/workflows/validation.yml/badge.svg)](https://github.com/ayeshLK/websubhub-deployment/actions/workflows/validation.yml)

This repository provides Docker and Kubernetes-based deployment configurations for WSO2 WebSubHub with support for multiple message broker backends. It's designed to simulate WebSubHub deployments and facilitate running various test scenarios.

## Overview

WebSubHub is a publish-subscribe hub implementation based on the W3C WebSub specification. This repository helps you:
- Build Docker images for WebSubHub components
- Deploy WebSubHub with different message broker backends (Kafka, Solace, IBM MQ)
- Deploy WebSubHub on Kubernetes using Helm charts
- Run integration tests and validate WebSub functionality

## Quick Start Guide

**Choose your deployment path:**

1. **First-time user / Testing**: Use Kafka (simplest setup)
   ```bash
   ./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-tests
   cd docker/kafka && docker compose up -d
   ```

2. **Enterprise messaging**: Use Solace
   ```bash
   ./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-tests
   cd docker/solace && docker compose up -d
   ```

3. **Legacy JMS integration**: Use IBM MQ (requires pre-configured JMS libraries)
   ```bash
   ./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-tests
   cd docker/ibmmq && docker compose up -d
   ```

**After deployment**, access WebSubHub at: `https://dev.websubhub.com/hub`

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

#### If Building from Source (`--clone-dir` or `--repo-dir`)

- **Docker Buildx** - For building multi-architecture images
- **Java 21+** - Verified automatically by the build script
- **Ballerina SL 2201.13.1+** - Required for building WebSubHub components

#### If Using Released Versions (`--deployment-version`)

No additional requirements. The script will only update configuration files with the specified version.

#### If Deploying on Kubernetes

- **Kubernetes cluster** (v1.19+) or **Minikube** for local development
- **Helm 3.x** for managing chart deployments
- **kubectl** configured to access your cluster

#### If Deploying with IBM MQ

The IBM MQ deployment requires additional files that are **NOT** auto-generated:

- **IBM MQ JMS Client Libraries** in `docker/ibmmq/extensions/`:
  - `com.ibm.mq.allclient-9.4.0.10.jar` (IBM MQ all-client JAR)
  - `fscontext.jar` (JNDI filesystem context)
  - `providerutil.jar` (JNDI provider utilities)

- **JNDI Bindings Configuration** in `docker/ibmmq/jndi-bindings/`:
  - `.bindings` file containing connection factory definitions

These files must be pre-configured before running the IBM MQ deployment. The repository includes pre-configured versions for the `BALLERINA_QM1` queue manager.

## Preparing for Deployment

The `prepare-deployment.sh` script supports **three deployment modes**. Choose the appropriate mode based on your needs:

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
6. Generates `.env` files in `docker/kafka/`, `docker/solace/`, and `docker/ibmmq/` with the extracted version

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

### Mode 2: Use an Existing Repository

Use this mode when you already have the WebSubHub repository cloned and want to build from it without re-cloning.

**Basic Command:**
```bash
./prepare-deployment.sh --repo-dir /path/to/existing/websubhub
```

**What this does:**
1. Validates the directory contains a valid WebSubHub repository
2. Validates Java 21+ is installed
3. Builds the project with Gradle (can be skipped with `--skip-build`)
4. Creates Docker images for all components (Hub, Consolidator)
5. Loads images into local Docker daemon
6. Generates `.env` files in `docker/kafka/`, `docker/solace/`, and `docker/ibmmq/` with the extracted version

**Available Options:**
```bash
./prepare-deployment.sh --repo-dir <directory> [OPTIONS]

Required:
  --repo-dir <dir>     Path to existing WebSubHub repository

Optional:
  --skip-tests         Skip running tests during Gradle build (faster)
  --skip-build         Skip Gradle build (use existing artifacts)
```

**Examples:**
```bash
# Build from existing repository
./prepare-deployment.sh --repo-dir /path/to/websubhub

# Build without tests (recommended for faster builds)
./prepare-deployment.sh --repo-dir /path/to/websubhub --skip-tests

# Skip build entirely (use existing build artifacts)
./prepare-deployment.sh --repo-dir /path/to/websubhub --skip-build --skip-tests
```

**Use Cases:**
- You already have the repository cloned from a previous run
- Working with a specific branch or commit
- Iterating on builds without re-cloning
- Testing local changes before committing

**Important:** The repository must be a valid WebSubHub checkout with `gradle.properties` and `components` directory. The script does not perform any git operations (pull, checkout, etc.) and uses the repository as-is.

### Mode 3: Use a Released Version

Use this mode when you want to deploy a specific released version of WebSubHub without building from source.

**Command:**
```bash
./prepare-deployment.sh --deployment-version <version>
```

**What this does:**
1. Updates `.env` files in `docker/kafka/`, `docker/solace/`, and `docker/ibmmq/` with the specified version
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

This repository provides deployment configurations for three message brokers:

| Broker | Type | Connection Method | Setup Complexity | Best For |
|--------|------|-------------------|------------------|----------|
| **Apache Kafka** | Streaming Platform | Native Client | Low | High-throughput, distributed streaming |
| **Solace PubSub+** | Enterprise Messaging | Native Client | Low | Enterprise messaging, IoT, event mesh |
| **IBM MQ** | Enterprise Middleware | JMS/JNDI | Medium | Legacy integration, JMS applications |

**Quick Comparison:**

- **Apache Kafka**:
  - Direct connection via native client
  - Configuration: Single `bootstrapServers` parameter
  - Files needed: Config TOML only

- **Solace PubSub+**:
  - Direct connection via native client
  - Configuration: Single `url` parameter
  - Files needed: Config TOML only

- **IBM MQ**:
  - JMS abstraction with JNDI lookup
  - Configuration: JNDI context + connection factory reference
  - Files needed: Config TOML + JNDI bindings + JMS libraries

### Docker Deployment

WebSubHub can be deployed locally using Docker Compose with either Kafka or Solace as the message broker backend.

#### Architecture Overview

All Docker deployments include **4 services** with the following dependency chain:

```
NGINX Ingress → WebSubHub Hub → WebSubHub Consolidator → Message Broker
```

- **NGINX Ingress**: Reverse proxy providing HTTPS access (bound to `127.0.0.2:443`)
- **WebSubHub Hub**: Main WebSub hub service (internal port 9000)
- **WebSubHub Consolidator**: State consolidation service (internal port 10001)
- **Message Broker**: Kafka, Solace, or IBM MQ

**Important**: Hub and Consolidator services do NOT expose ports directly. All external access goes through the NGINX ingress layer using HTTPS.

#### Quick Start

1. **Navigate to your broker directory:**
   ```bash
   cd docker/kafka    # For Kafka deployment
   # OR
   cd docker/solace   # For Solace deployment
   # OR
   cd docker/ibmmq    # For IBM MQ deployment
   ```

2. **Start all services:**
   ```bash
   docker compose up -d
   ```

   This starts all four services in the following order:
   - Message broker (Kafka, Solace, or IBM MQ)
   - WebSubHub Consolidator (depends on broker)
   - WebSubHub Hub (depends on Consolidator)
   - NGINX Ingress (depends on Hub)

3. **Verify services are running:**
   ```bash
   docker compose ps
   ```

#### Accessing Services

**WebSubHub Hub (All Deployments):**
- URL: `https://dev.websubhub.com/hub`
- NGINX Ingress: `127.0.0.2:443`
- TLS: Self-signed certificates (use `-k` flag with curl)
- Configuration: Shared NGINX config in `docker/_common/nginx/`

**For Kafka Deployment:**
- Kafka Bootstrap Server: `localhost:9092` (for external clients)

**For Solace Deployment:**
- Solace Admin UI: `http://localhost:8085` (username: `admin`, password: `admin`)
- Solace SMF Port: `55555`

**For IBM MQ Deployment:**
- IBM MQ Port: `1414` (for external JMS clients)
- Queue Manager: `BALLERINA_QM1`
- Admin credentials: `admin/password`

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
docker compose logs -f ibmmq         # IBM MQ broker logs
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

# Build images (choose one method)
./prepare-deployment.sh --clone-dir /tmp/websubhub --skip-tests
# OR use existing repository
./prepare-deployment.sh --repo-dir /path/to/existing/websubhub --skip-tests

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
│   ├── _common/                 # Shared NGINX configuration
│   │   └── nginx/               # NGINX ingress configs and certificates
│   ├── kafka/                   # Kafka broker deployment
│   │   ├── docker-compose.yml
│   │   ├── Config.hub.toml
│   │   ├── Config.consolidator.toml
│   │   └── .env                 # Auto-generated version file
│   ├── solace/                  # Solace broker deployment
│   │   ├── docker-compose.yml
│   │   ├── Config.hub.toml
│   │   ├── Config.consolidator.toml
│   │   └── .env                 # Auto-generated version file
│   └── ibmmq/                   # IBM MQ broker deployment
│       ├── docker-compose.yml
│       ├── Config.hub.toml
│       ├── Config.consolidator.toml
│       ├── jndi-bindings/       # JNDI configuration for IBM MQ
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
- Docker Compose configuration files for all brokers (Kafka, Solace, IBM MQ)
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

### IBM MQ Connectivity Issues

If WebSubHub can't connect to IBM MQ:

1. **Verify IBM MQ is healthy:**
   ```bash
   docker compose logs ibmmq
   ```

2. **Check if IBM MQ queue manager is running:**
   ```bash
   docker exec -it ibmmq chkmqstarted
   ```

3. **Verify JNDI bindings are mounted correctly:**
   ```bash
   # Check the bindings file exists in the container
   docker exec -it websubhub-consolidator ls -la /home/wso2/jndi-bindings/

   # Should show: .bindings file (~103 KB)
   ```

4. **Verify JMS extensions are mounted:**
   ```bash
   # Check Hub extensions (replace version with your actual version)
   docker exec -it websubhub ls -la /home/wso2/wso2websubhub-1.0.0/wso2/extensions/

   # Check Consolidator extensions
   docker exec -it websubhub-consolidator ls -la /home/wso2/wso2websubhub-consolidator-1.0.0/wso2/extensions/

   # Should show: com.ibm.mq.allclient-9.4.0.10.jar, fscontext.jar, providerutil.jar
   ```

5. **Check the consolidator config uses correct JNDI settings:**
   ```toml
   [websubhub.consolidator.config.store.jms]
   initialContextFactory = "com.sun.jndi.fscontext.RefFSContextFactory"
   providerUrl = "file:/home/wso2/jndi-bindings"
   connectionFactoryName = "TestConnFac3"
   username = "admin"
   password = "password"
   ```

6. **Test IBM MQ port connectivity from consolidator:**
   ```bash
   docker exec -it websubhub-consolidator nc -zv ibmmq 1414
   ```

7. **Access IBM MQ CLI for debugging:**
   ```bash
   # Enter IBM MQ container
   docker exec -it ibmmq bash

   # Display queue managers
   dspmq

   # Should show: QMNAME(BALLERINA_QM1) STATUS(Running)
   ```

**Common IBM MQ Issues:**

- **Missing extensions**: If JMS client libraries are not in `extensions/`, you'll get ClassNotFoundException
- **Wrong connection factory name**: If `connectionFactoryName` doesn't match a factory in `.bindings`, you'll get NameNotFoundException
- **JNDI bindings not mounted**: If `/home/wso2/jndi-bindings/.bindings` is missing, JNDI lookup will fail
- **Queue manager not running**: Check with `docker exec -it ibmmq dspmq` to verify status
- **Version mismatch**: IBM MQ client version in JAR must be compatible with IBM MQ broker version

### Rebuilding Images

To rebuild after code changes:
```bash
# Rebuild with the build script (choose one method)
./prepare-deployment.sh --clone-dir /tmp/websubhub
# OR use existing repository
./prepare-deployment.sh --repo-dir /path/to/existing/websubhub

# Restart services (use your broker directory)
cd docker/kafka  # or docker/solace
docker compose down
docker compose up -d
```

## Additional Resources

- [WebSubHub Documentation](https://wso2.github.io/docs-websubhub/)
- [WebSubHub GitHub Repository](https://github.com/wso2/product-integrator-websubhub)
- [W3C WebSub Specification](https://www.w3.org/TR/websub/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Solace Documentation](https://docs.solace.com/)
- [IBM MQ Documentation](https://www.ibm.com/docs/en/ibm-mq)
- [Ballerina Documentation](https://ballerina.io/learn/)
