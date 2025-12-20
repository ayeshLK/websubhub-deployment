# WebSubHub Deployment

This repository provides Docker-based deployment configurations for WSO2 WebSubHub with support for multiple message broker backends. It's designed to simulate WebSubHub deployments and facilitate running various test scenarios.

## Overview

WebSubHub is a publish-subscribe hub implementation based on the W3C WebSub specification. This repository helps you:
- Build Docker images for WebSubHub components
- Deploy WebSubHub with different message broker backends (e.g., Solace)
- Run integration tests and validate WebSub functionality

## Prerequisites

- **Docker** and **Docker Compose** installed
- **Docker Buildx** for multi-architecture builds
- **Java 21+** for building the project
- **Git** for cloning repositories

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

Check the status:
```bash
docker-compose ps
```

View logs:
```bash
docker-compose logs -f
```

Stop the services:
```bash
docker-compose down
```

### Accessing Services

Once deployed, the following services are available:

- **WebSubHub Hub**: `https://localhost:9000`
- **Consolidator**: `http://localhost:10001`
- **Solace Admin**: `http://localhost:8080` (username: `admin`, password: `admin`)
- **Solace Messaging**: `localhost:55554`

### Configuration

Configuration files for each component are located in the broker directory:
- `Config.hub.toml` - Hub service configuration
- `Config.consolidator.toml` - Consolidator service configuration

The WebSubHub version is automatically set in `.env` files by the build script.

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
├── docker/
│   └── solace/              # Solace broker deployment
│       ├── docker-compose.yml
│       ├── Config.hub.toml
│       ├── Config.consolidator.toml
│       └── .env             # Auto-generated version file
├── websubhub-docker-build.sh  # Build script
├── .gitignore
└── README.md
```

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
- Missing configuration files
- Insufficient Docker resources (increase memory/CPU allocation)

### Rebuilding Images

To rebuild after code changes:
```bash
# Rebuild with the build script
./websubhub-docker-build.sh --clone-dir /tmp/websubhub

# Restart services
cd docker/solace
docker-compose down
docker-compose up -d
```

## Additional Resources

- [WebSubHub Documentation](https://wso2.github.io/docs-websubhub/)
- [WebSubHub GitHub Repository](https://github.com/wso2/product-integrator-websubhub)
- [W3C WebSub Specification](https://www.w3.org/TR/websub/)
- [Solace Documentation](https://docs.solace.com/)
