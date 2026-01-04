#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLONE_DIR=""
DEPLOYMENT_VERSION=""
BUILD_PROJECT=${BUILD_PROJECT:-true}
SKIP_TESTS=${SKIP_TESTS:-false}
REPO_URL="https://github.com/wso2/product-integrator-websubhub"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --clone-dir)
      CLONE_DIR="$2"
      shift 2
      ;;
    --deployment-version)
      DEPLOYMENT_VERSION="$2"
      shift 2
      ;;
    --skip-build)
      BUILD_PROJECT=false
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--clone-dir <dir> | --deployment-version <version>] [OPTIONS]"
      echo ""
      echo "Prepare WSO2 WebSubHub deployment by either building from source or using a released version"
      echo ""
      echo "Required (mutually exclusive):"
      echo "  --clone-dir <dir>              Clone repository to specified directory and build from source"
      echo "  --deployment-version <version> Use a released version (updates .env files with version)"
      echo "                                 Note: Cannot be used with --skip-build or --skip-tests"
      echo "                                 Version format: plain format (e.g., 1.0.0) without 'v' prefix"
      echo ""
      echo "Options (only applicable with --clone-dir):"
      echo "  --skip-build                   Skip Gradle build step (use existing build artifacts)"
      echo "  --skip-tests                   Skip tests during Gradle build"
      echo "  --help                         Show this help message"
      echo ""
      echo "Environment Variables:"
      echo "  BUILD_PROJECT       Set to 'false' to skip Gradle build"
      echo "  SKIP_TESTS          Set to 'true' to skip tests during build"
      echo ""
      echo "Examples:"
      echo "  # Clone, build, and create images from source"
      echo "  $0 --clone-dir /tmp/websubhub"
      echo ""
      echo "  # Clone, build (skip tests), and create images"
      echo "  $0 --clone-dir /tmp/websubhub --skip-tests"
      echo ""
      echo "  # Use a released version (e.g., 1.0.0)"
      echo "  $0 --deployment-version 1.0.0"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$CLONE_DIR" ] && [ -z "$DEPLOYMENT_VERSION" ]; then
  echo -e "${RED}Error: Either --clone-dir or --deployment-version is required${NC}"
  echo "Use --help for usage information"
  exit 1
fi

if [ -n "$CLONE_DIR" ] && [ -n "$DEPLOYMENT_VERSION" ]; then
  echo -e "${RED}Error: --clone-dir and --deployment-version are mutually exclusive${NC}"
  echo "Use --help for usage information"
  exit 1
fi

# Additional validations for --deployment-version
if [ -n "$DEPLOYMENT_VERSION" ]; then
  # Check if --deployment-version is used with incompatible flags
  if [ "$BUILD_PROJECT" = false ] || [ "$SKIP_TESTS" = true ]; then
    echo -e "${RED}Error: --deployment-version cannot be used with --skip-build or --skip-tests${NC}"
    echo "The --deployment-version flag only updates .env files and does not build images"
    echo "Use --help for usage information"
    exit 1
  fi

  # Validate version format (should not start with 'v')
  if [[ "$DEPLOYMENT_VERSION" =~ ^v ]]; then
    echo -e "${RED}Error: Version should be in plain format (e.g., 1.0.0) without 'v' prefix${NC}"
    echo "Provided: $DEPLOYMENT_VERSION"
    echo "Expected format: 1.0.0"
    exit 1
  fi
fi

# Save the original directory (deployment repo)
DEPLOYMENT_DIR=$(pwd)

echo -e "${GREEN}=== WSO2 WebSubHub Deployment Preparation Script ===${NC}"
echo ""

# If deployment version is provided, skip clone and build steps
if [ -n "$DEPLOYMENT_VERSION" ]; then
  echo -e "${BLUE}=== Using Deployment Version: ${DEPLOYMENT_VERSION} ===${NC}"
  VERSION="$DEPLOYMENT_VERSION"

  # Update .env files in all docker broker subdirectories
  DOCKER_DIR="${DEPLOYMENT_DIR}/docker"
  if [ -d "$DOCKER_DIR" ]; then
    echo -e "${YELLOW}Updating .env files in docker subdirectories...${NC}"
    for broker_dir in "$DOCKER_DIR"/*; do
      if [ -d "$broker_dir" ]; then
        env_file="${broker_dir}/.env"
        echo "WEBSUBHUB_VERSION=${VERSION}" > "$env_file"
        echo -e "${GREEN}✓ Updated $(basename "$broker_dir")/.env with version ${VERSION}${NC}"
      fi
    done
  else
    echo -e "${RED}Error: ${DOCKER_DIR} not found${NC}"
    exit 1
  fi
  echo ""
  echo -e "${GREEN}=== Deployment preparation complete ===${NC}"
  echo -e "${GREEN}Updated .env files with version: ${VERSION}${NC}"
  exit 0
fi

# Step 1: Clone repository
echo -e "${BLUE}=== Step 1: Cloning Repository ===${NC}"

if [ -d "$CLONE_DIR" ]; then
  echo -e "${YELLOW}Directory $CLONE_DIR already exists${NC}"
  read -p "Do you want to remove it and re-clone? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing existing directory..."
    rm -rf "$CLONE_DIR"
  else
    echo "Using existing directory"
  fi
fi

if [ ! -d "$CLONE_DIR" ]; then
  echo -e "${YELLOW}Cloning repository from ${REPO_URL}${NC}"
  git clone "$REPO_URL" "$CLONE_DIR"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to clone repository${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Repository cloned successfully${NC}"
fi

echo "Changing to repository directory: $CLONE_DIR"
cd "$CLONE_DIR"
echo ""

# Step 2: Check Java version
echo -e "${BLUE}=== Step 2: Checking Java Version ===${NC}"

if ! command -v java &> /dev/null; then
  echo -e "${RED}Error: Java is not installed${NC}"
  echo "Please install Java 21 before running this script"
  echo "Download from: https://adoptium.net/"
  exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | cut -d'.' -f1)

if [ -z "$JAVA_VERSION" ]; then
  # Try alternative method for newer Java versions
  JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk '{print $3}' | tr -d '"' | cut -d'.' -f1)
fi

echo "Detected Java version: $JAVA_VERSION"

if [ "$JAVA_VERSION" -lt 21 ]; then
  echo -e "${RED}Error: Java 21 or higher is required${NC}"
  echo "Current Java version: $JAVA_VERSION"
  echo "Please install Java 21 from: https://adoptium.net/"
  exit 1
fi

echo -e "${GREEN}✓ Java $JAVA_VERSION detected (meets requirement of Java 21+)${NC}"
echo ""

# Step 3: Build project with Gradle
if [ "$BUILD_PROJECT" = true ]; then
  echo -e "${BLUE}=== Step 3: Building Project with Gradle ===${NC}"

  if [ ! -f "gradlew" ]; then
    echo -e "${RED}Error: gradlew not found in current directory${NC}"
    echo "Make sure you're in the project root directory"
    exit 1
  fi

  # Make gradlew executable
  chmod +x ./gradlew

  BUILD_CMD="./gradlew clean build"
  if [ "$SKIP_TESTS" = true ]; then
    echo -e "${YELLOW}Building project (skipping tests)${NC}"
    BUILD_CMD="./gradlew clean build -x test"
  else
    echo -e "${YELLOW}Building project (including tests)${NC}"
  fi

  echo "Running: $BUILD_CMD"
  echo ""

  set +e  # Temporarily disable exit on error to capture build status
  $BUILD_CMD
  BUILD_EXIT_CODE=$?
  set -e

  if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}Error: Gradle build failed${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Project built successfully${NC}"
  echo ""
else
  echo -e "${YELLOW}=== Skipping Gradle build (using existing artifacts) ===${NC}"
  echo ""
fi

# Step 4: Build Docker images
echo -e "${BLUE}=== Step 4: Building Docker Images ===${NC}"
echo ""

# Get version from gradle.properties
if [ ! -f "gradle.properties" ]; then
  echo -e "${RED}Error: gradle.properties not found${NC}"
  exit 1
fi

VERSION=$(grep -w 'version' gradle.properties | cut -d= -f2)
if [ -z "$VERSION" ]; then
  echo -e "${RED}Error: Could not determine version from gradle.properties${NC}"
  exit 1
fi

echo -e "${GREEN}Release version: ${VERSION}${NC}"

# Create .env files in all docker broker subdirectories
DOCKER_DIR="${DEPLOYMENT_DIR}/docker"
if [ -d "$DOCKER_DIR" ]; then
  echo -e "${YELLOW}Creating .env files in docker subdirectories...${NC}"
  for broker_dir in "$DOCKER_DIR"/*; do
    if [ -d "$broker_dir" ]; then
      env_file="${broker_dir}/.env"
      echo "WEBSUBHUB_VERSION=${VERSION}" > "$env_file"
      echo -e "${GREEN}✓ Created $(basename "$broker_dir")/.env${NC}"
    fi
  done
else
  echo -e "${YELLOW}Warning: ${DOCKER_DIR} not found${NC}"
fi
echo ""

# Set up Docker Buildx
echo -e "${YELLOW}Setting up Docker Buildx${NC}"
docker buildx version > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Docker Buildx is not available${NC}"
  echo "Please install Docker Buildx: https://docs.docker.com/buildx/working-with-buildx/"
  exit 1
fi

# Create builder instance if it doesn't exist
BUILDER_NAME="multiarch-builder"
if ! docker buildx inspect "$BUILDER_NAME" > /dev/null 2>&1; then
  echo "Creating buildx builder instance: $BUILDER_NAME"
  docker buildx create --name "$BUILDER_NAME" --use
else
  echo "Using existing buildx builder: $BUILDER_NAME"
  docker buildx use "$BUILDER_NAME"
fi

docker buildx inspect --bootstrap
echo ""

# Discover components
echo -e "${YELLOW}Discovering components...${NC}"
if [ ! -d "components" ]; then
  echo -e "${RED}Error: components directory not found${NC}"
  exit 1
fi

COMPONENTS=$(find components -maxdepth 1 -type d -not -path components | sed 's|components/||' | tr '\n' ' ' | sed 's/ $//')

if [ -z "$COMPONENTS" ]; then
  echo -e "${RED}Error: No components found${NC}"
  exit 1
fi

echo -e "${GREEN}Found components: ${COMPONENTS}${NC}"
echo -e "${GREEN}Component count: $(echo ${COMPONENTS} | wc -w)${NC}"
echo ""

# Build Docker images for each component
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

for component in $COMPONENTS; do
  echo -e "${YELLOW}Processing component: ${component}${NC}"

  DOCKERFILE_PATH="docker/components/${component}/Dockerfile"

  if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo -e "${YELLOW}No Dockerfile found at ${DOCKERFILE_PATH}, skipping...${NC}"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    echo ""
    continue
  fi

  IMAGE_TAG="wso2/wso2${component}:latest"
  echo -e "${GREEN}Building Docker image: ${IMAGE_TAG}${NC}"
  echo "  Dockerfile: ${DOCKERFILE_PATH}"
  echo "  Build args: SERVER_NAME=wso2${component}, SERVER_VERSION=${VERSION}"
  echo ""

  COMPONENT_CACHE_DIR="/tmp/.buildx-cache-${component}"

  set +e  # Disable exit on error for this build
  docker buildx build \
    --file "$DOCKERFILE_PATH" \
    --load \
    --tag "$IMAGE_TAG" \
    --build-arg "SERVER_NAME=wso2${component}" \
    --build-arg "SERVER_VERSION=${VERSION}" \
    --build-arg "SERVER_DIST_PATH=distribution/build/distributions" \
    --cache-from type=local,src=${COMPONENT_CACHE_DIR} \
    --cache-to type=local,dest=${COMPONENT_CACHE_DIR},mode=max \
    .
  BUILD_EXIT_CODE=$?
  set -e  # Re-enable exit on error

  if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully built ${IMAGE_TAG}${NC}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo -e "${RED}✗ Failed to build ${IMAGE_TAG}${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  echo ""
done

# Cache cleanup (optional - caches are stored per-component in /tmp/.buildx-cache-<component>)
# Uncomment the following lines to clean up cache after build:
# rm -rf /tmp/.buildx-cache-*

# Summary
echo -e "${GREEN}=== Build Summary ===${NC}"
echo -e "  ${GREEN}Successful: ${SUCCESS_COUNT}${NC}"
echo -e "  ${YELLOW}Skipped: ${SKIP_COUNT}${NC}"
echo -e "  ${RED}Failed: ${FAIL_COUNT}${NC}"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
  echo -e "${RED}Some builds failed!${NC}"
  exit 1
fi

echo -e "${GREEN}All images built successfully!${NC}"
