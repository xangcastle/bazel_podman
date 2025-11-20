# Podman Container Toolchain - PostgreSQL 15 Example

## Quick Start - PostgreSQL 15

### First Time Setup (macOS only)

**Quick Setup (Recommended):**

Just run this single command to configure everything:

```bash
bazel run @podman//:podman_setup
```

This will:

- Create `~/.config/containers/containers.conf`
- Configure the helper binaries location
- Show you the next steps

Then initialize and start the machine:

```bash
bazel run @podman//:podman -- machine init
bazel run @podman//:podman -- machine start
```

**Manual Setup:**

If you prefer to configure manually:

```bash
# 1. Create containers.conf with helper binaries path
mkdir -p ~/.config/containers
BAZEL_OUTPUT_BASE=$(bazel info output_base)
cat > ~/.config/containers/containers.conf << EOF
[engine]
helper_binaries_dir=["${BAZEL_OUTPUT_BASE}/external/+container_engine+podman_engine"]
EOF

# 2. Initialize podman machine (first time only)
bazel run @podman//:podman -- machine init

# 3. Start the machine
bazel run @podman//:podman -- machine start

# 4. Verify it works
bazel run @podman//:podman -- ps
```

**Note:** The `containers.conf` file tells Podman where to find the helper binaries (`gvproxy`, `vfkit`, etc.) that were
downloaded by Bazel.

**Quick Setup (All-in-One Command):**

For new machines, you can run this single command to set everything up:

```bash
mkdir -p ~/.config/containers && \
cat > ~/.config/containers/containers.conf << EOF
[engine]
helper_binaries_dir=["$(bazel info output_base)/external/+container_engine+podman_engine"]
EOF
bazel run @podman//:podman -- machine init && \
bazel run @podman//:podman -- machine start && \
echo "✅ Podman is ready! Test with: bazel run @podman//:podman -- ps"
```

### Running PostgreSQL 15

Once the machine is initialized and started, you can run PostgreSQL:

```bash
# Start PostgreSQL 15
bazel run @podman//:podman -- run -d \
  --name postgres15 \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=admin \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  docker.io/library/postgres:15

# Check status
bazel run @podman//:podman -- ps

# View logs
bazel run @podman//:podman -- logs postgres15

# Connect to PostgreSQL
psql -h localhost -U admin -d mydb
# Password: mysecretpassword

# Stop PostgreSQL
bazel run @podman//:podman -- stop postgres15

# Remove container
bazel run @podman//:podman -- rm postgres15
```

## Configuration

The postgres15 target is configured with:

- Image: docker.io/library/postgres:15
- Port: 5432:5432
- User: admin
- Password: mysecretpassword
- Database: mydb

See MODULE.bazel for the full configuration.

**Available executables:**

- `@podman//:podman` - Podman CLI
- `@podman//:gvproxy` - gvproxy networking helper
- `@podman//:vfkit` - vfkit hypervisor (macOS only)
- `@podman//:setup` - Setup script (all platforms)

**Platform-specific notes:**

- **Linux**: Downloads `podman-static` (v5.2.2) which includes all required binaries: `podman`, `conmon`, `crun`,
  `runc`, etc. No machine setup needed (runs natively).
- **macOS**: Downloads `podman`, `gvproxy`, and `vfkit`. Machine setup required.
- **Windows**: Downloads `podman` and `gvproxy`. Machine setup required (uses Hyper-V or WSL2).

# Podman Container Toolchain

This toolchain downloads and provides Podman (container engine) for use in Bazel builds.

## Quick Start

### Use Podman directly (Recommended)

You can run podman directly with any command:

```bash
# Check version
bazel run @podman//:podman -- --version

# List containers
bazel run @podman//:podman -- ps

# List all containers (including stopped)
bazel run @podman//:podman -- ps -a

# Run a container
bazel run @podman//:podman -- run -d --name nginx -p 8080:80 docker.io/library/nginx

# Check container status
bazel run @podman//:podman -- ps --filter=name=nginx

# Stop a container
bazel run @podman//:podman -- stop nginx

# View logs
bazel run @podman//:podman -- logs nginx

# Execute command in container
bazel run @podman//:podman -- exec -it nginx bash

# Any other podman command...
bazel run @podman//:podman -- [any-podman-command]
```

## Using Podman with OCI Images (rules_oci)

### Load OCI images to Podman

By default, `oci_load` uses Docker. To use Podman instead, set the `DOCKER` environment variable:

```bash
# Method 1: Set DOCKER env var for a single command
DOCKER="podman" bazel run //contollo:static.image.load

# Method 2: Set globally in your shell
export DOCKER="podman"
bazel run //contollo:static.image.load

# Method 3: Create a shell alias for convenience
alias bazel-podman='DOCKER="podman" bazel'
bazel-podman run //contollo:static.image.load

# Verify the image was loaded
bazel run @podman//:podman -- images | grep contollo
```

### Configure your shell to always use Podman

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Use Podman instead of Docker for OCI operations
export DOCKER="podman"

# Or if you have Podman installed via Bazel toolchain:
export DOCKER="$(bazel info output_base)/external/+container_engine+podman_engine/podman-5.5.2/usr/bin/podman"
```

### Authenticate with private registries (ghcr.io)

To push/pull from private registries like GitHub Container Registry:

```bash
# Login to ghcr.io using Podman
bazel run @podman//:podman -- login ghcr.io
# Username: your-github-username
# Password: your-github-personal-access-token (with packages:write scope)

# Or login non-interactively
echo $GITHUB_TOKEN | bazel run @podman//:podman -- login ghcr.io -u your-username --password-stdin

# Verify authentication
bazel run @podman//:podman -- login --get-login ghcr.io

# Pull private images
bazel run @podman//:podman -- pull ghcr.io/itstar-tech/cosmos/contollo:latest

# Push images (after loading them)
bazel run @podman//:podman -- push contollo-static:latest ghcr.io/itstar-tech/cosmos/static:latest
```

### Complete workflow: Build, Load, and Push to ghcr.io

```bash
# 1. Build the OCI image
bazel build //contollo:static.image

# 2. Load to Podman
DOCKER="podman" bazel run //contollo:static.image.load

# 3. Verify it's loaded
bazel run @podman//:podman -- images | grep contollo

# 4. Tag for ghcr.io (if needed)
bazel run @podman//:podman -- tag contollo-static:latest ghcr.io/itstar-tech/cosmos/static:latest

# 5. Login to ghcr.io (once)
echo $GITHUB_TOKEN | bazel run @podman//:podman -- login ghcr.io -u your-username --password-stdin

# 6. Push to ghcr.io
bazel run @podman//:podman -- push ghcr.io/itstar-tech/cosmos/static:latest

# Or use the built-in oci_push target:
# Note: oci_push requires Docker or Podman to be available
bazel run //contollo:static.image.push
```

### Using Podman in CI/CD (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
- name: Setup Podman
  run: |
    # Podman is pre-installed on GitHub runners
    podman version

- name: Login to ghcr.io
  run: |
    echo "${{ secrets.GITHUB_TOKEN }}" | podman login ghcr.io -u ${{ github.actor }} --password-stdin

- name: Build and push image with Bazel
  env:
    DOCKER: podman
  run: |
    bazel run //contollo:static.image.load
    bazel run //contollo:static.image.push
```

### Podman Machine (macOS/Windows only)

On macOS/Windows, Podman requires a Linux VM. **Important:** You must configure the helper binaries location before
initializing the machine for the first time.

```bash
# STEP 1: Configure helper binaries location (REQUIRED FIRST TIME)
mkdir -p ~/.config/containers
BAZEL_OUTPUT_BASE=$(bazel info output_base)
cat > ~/.config/containers/containers.conf << EOF
[engine]
helper_binaries_dir=["${BAZEL_OUTPUT_BASE}/external/+container_engine+podman_engine"]
EOF

# STEP 2: Initialize Podman machine (first time only)
bazel run @podman//:podman -- machine init

# STEP 3: Start the VM
bazel run @podman//:podman -- machine start

# STEP 4: Check status
bazel run @podman//:podman -- machine list

# Now you can use Podman normally
bazel run @podman//:podman -- ps
```

**Why is containers.conf needed?**

The Bazel toolchain downloads `gvproxy` and `vfkit` to a non-standard location. Podman needs to know where to find these
helper binaries when initializing and starting the machine. The `containers.conf` file tells Podman where to look.

**Common error without containers.conf:**

```
Error: could not find "gvproxy" in one of [$BINDIR/../libexec/podman ...
```

This means Podman cannot find the helper binaries. Solution: Create `~/.config/containers/containers.conf` as shown
above.

#### ⚠️ Podman on macOS: Limitations and Alternatives

On **macOS (and Windows)**, you **cannot** run containers natively: all containers must run inside a Linux VM ("podman
machine"), because:

- Containers share the Linux kernel
- macOS uses Darwin/XNU, not Linux
- Even `podman ps` needs the VM running

**You CANNOT run containers or `podman load` without podman machine.**

If you see errors like:

```
Error: could not find "gvproxy" in one of [$BINDIR/../libexec/podman ...
```

it means required helper binaries (like `gvproxy`, `vfkit`, etc) are missing and the machine can't start.

**To summarize:**

- ✅ _You can build OCI images (e.g., `bazel build //contollo:static.image`)_
- ❌ _You CANNOT run containers or load images without starting podman machine_

---

**What works on macOS without podman machine:**

- Building OCI images with Bazel (does not require a running Linux VM)
- Inspecting OCI tarballs manually

**What requires podman machine (Linux VM):**

- `podman run`
- `podman ps`
- `podman load` / Bazel `oci_load`
- Running PostgreSQL or any container

---

**Solutions for running Podman machine on macOS (without Homebrew):**

**Option 1: Download the official installer (No Homebrew required)**

Download the complete Podman package from GitHub releases:

```bash
# For Apple Silicon (M1/M2/M3)
curl -LO https://github.com/containers/podman/releases/download/v5.5.2/podman-installer-macos-arm64.pkg

# For Intel Macs
curl -LO https://github.com/containers/podman/releases/download/v5.5.2/podman-installer-macos-amd64.pkg

# Install the package
sudo installer -pkg podman-installer-macos-*.pkg -target /

# Initialize and start the machine
podman machine init
podman machine start

# Verify it works
podman ps

# Now you can use Podman for everything:
export DOCKER="podman"
bazel run //contollo:static.image.load
podman run -d --name postgres -e POSTGRES_PASSWORD=pass -p 5432:5432 postgres:15
```

**Option 2: Install Podman via Homebrew (If you already use Homebrew)**

The easiest solution is to use Homebrew's Podman which includes all necessary binaries:

```bash
# Install Podman with all dependencies
brew install podman

# Initialize and start the machine
podman machine init
podman machine start

# Verify it works
podman ps

# Now you can use either:
# - System podman: podman [command]
# - Bazel podman: bazel run @podman//:podman -- [command]
# - With OCI images: DOCKER="podman" bazel run //...:image.load
```

If you have Podman installed system-wide, update your `BUILD.bazel`:

```starlark
bazel_env(
    name = "bazel_env",
    tools = {
        # Comment out or remove the Bazel podman
        # "podman": "@podman//:podman",

        # Add system podman instead (if in PATH)
        # Or point to a specific path
    },
)

# Then set DOCKER to use system podman
export DOCKER="podman"  # Uses system podman from PATH
```

**Option 3: Alternative - Use Docker Desktop instead**

If you don't want to deal with Podman machine setup on macOS, you can use Docker:

```bash
# Install Docker Desktop for Mac
# https://www.docker.com/products/docker-desktop/

# Then use Docker instead of Podman
export DOCKER="docker"
bazel run //contollo:static.image.load

# Or keep using Bazel toolchain for CI/CD (Linux) where it works natively
```

**Option 4: Use Docker in CI/CD, build-only locally**

On macOS, focus on building and let CI/CD handle container operations:

```bash
# On macOS: Only build images
bazel build //contollo:static.image

# Let GitHub Actions handle loading/pushing (has Podman pre-installed)
# See CI/CD section below
```

**Option 5: Use system Podman with bazel_env**

If you have Podman installed system-wide, update your `BUILD.bazel`:

**Recommended workflow for macOS development:**

```bash
# 1. Install Podman via Homebrew (includes all helper binaries)
brew install podman

# 2. Initialize the machine once
podman machine init
podman machine start

# 3. Use for OCI image loading
export DOCKER="podman"
bazel run //contollo:static.image.load

# 4. For CI/CD or Linux, the Bazel toolchain works perfectly
#    (no machine needed on Linux)
```

## Networking with Podman

Podman provides full networking support compatible with Docker, including bridge networks, custom networks, DNS
resolution, and port mapping.

### Network Basics

```bash
# Create a custom network
bazel run @podman//:podman -- network create myapp-network

# List all networks
bazel run @podman//:podman -- network ls

# Inspect a network
bazel run @podman//:podman -- network inspect myapp-network

# Remove a network
bazel run @podman//:podman -- network rm myapp-network
```

### Container Communication

Containers on the same network can communicate using container names as hostnames. Podman provides automatic DNS
resolution.

**Example: Backend connecting to Database**

```bash
# 1. Create a network
bazel run @podman//:podman -- network create app-network

# 2. Run PostgreSQL
bazel run @podman//:podman -- run -d \
  --name postgres \
  --network app-network \
  -e POSTGRES_PASSWORD=mysecret \
  -e POSTGRES_USER=admin \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres:15

# 3. Run backend (connects to PostgreSQL using hostname "postgres")
bazel run @podman//:podman -- run -d \
  --name backend \
  --network app-network \
  -e DATABASE_URL=postgresql://admin:mysecret@postgres:5432/mydb \
  -p 8000:8000 \
  your-backend-image

# The backend can now connect to PostgreSQL at "postgres:5432"
```

### Full Stack Example

Here's how to run a complete application stack with database, cache, API, and frontend:

```bash
# Create network
bazel run @podman//:podman -- network create cosmos-network

# PostgreSQL database
bazel run @podman//:podman -- run -d \
  --name db \
  --network cosmos-network \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=cosmos \
  -v postgres-dev-data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:15

# Redis cache
bazel run @podman//:podman -- run -d \
  --name cache \
  --network cosmos-network \
  -p 6379:6379 \
  redis:alpine

# API (connects to db and cache by name)
bazel run @podman//:podman -- run -d \
  --name api \
  --network cosmos-network \
  -e DATABASE_URL=postgresql://postgres:secret@db:5432/cosmos \
  -e REDIS_URL=redis://cache:6379 \
  -p 8000:8000 \
  your-api-image

# Frontend application
bazel run @podman//:podman -- run -d \
  --name web \
  --network cosmos-network \
  -e API_URL=http://api:8000 \
  -p 3000:3000 \
  your-frontend-image

# Nginx reverse proxy
bazel run @podman//:podman -- run -d \
  --name nginx \
  --network cosmos-network \
  -p 80:80 \
  -p 443:443 \
  nginx:alpine
```

### Network Management Commands

```bash
# Connect existing container to network
bazel run @podman//:podman -- network connect app-network my-container

# Disconnect container from network
bazel run @podman//:podman -- network disconnect app-network my-container

# View container's network settings
bazel run @podman//:podman -- inspect --format='{{.NetworkSettings.Networks}}' my-container

# View all containers in a network
bazel run @podman//:podman -- network inspect app-network --format='{{range .Containers}}{{.Name}} {{end}}'

# Remove all unused networks
bazel run @podman//:podman -- network prune
```

### Port Mapping

Expose container ports to the host system:

```bash
# Single port
bazel run @podman//:podman -- run -d -p 8080:80 nginx:alpine

# Multiple ports
bazel run @podman//:podman -- run -d \
  -p 8080:80 \
  -p 8443:443 \
  nginx:alpine

# Specific interface
bazel run @podman//:podman -- run -d -p 127.0.0.1:8080:80 nginx:alpine

# Random host port
bazel run @podman//:podman -- run -d -p 80 nginx:alpine

# View port mappings
bazel run @podman//:podman -- port my-container
```

### Environment-specific Networking

**Development Setup:**

```bash
# Create dev network
bazel run @podman//:podman -- network create dev-network

# PostgreSQL with persistent volume
bazel run @podman//:podman -- run -d \
  --name postgres-dev \
  --network dev-network \
  -e POSTGRES_PASSWORD=devpass \
  -e POSTGRES_DB=cosmos_dev \
  -v postgres-dev-data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:15

# Redis for caching
bazel run @podman//:podman -- run -d \
  --name redis-dev \
  --network dev-network \
  -p 6379:6379 \
  redis:alpine

# Your app (built with Bazel)
DOCKER="podman" bazel run //your-app:image.load
bazel run @podman//:podman -- run -d \
  --name app-dev \
  --network dev-network \
  -e NODE_ENV=development \
  -e DATABASE_URL=postgresql://postgres:devpass@postgres-dev:5432/cosmos_dev \
  -e REDIS_URL=redis://redis-dev:6379 \
  -p 3000:3000 \
  your-app:latest
```

**Testing Setup:**

```bash
# Create isolated test network
bazel run @podman//:podman -- network create test-network

# Test database (ephemeral)
bazel run @podman//:podman -- run -d \
  --name postgres-test \
  --network test-network \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=cosmos_test \
  postgres:15

# Run tests
bazel run @podman//:podman -- run --rm \
  --network test-network \
  -e DATABASE_URL=postgresql://postgres:testpass@postgres-test:5432/cosmos_test \
  your-app-test:latest npm test

# Cleanup
bazel run @podman//:podman -- stop postgres-test
bazel run @podman//:podman -- rm postgres-test
bazel run @podman//:podman -- network rm test-network
```

### DNS and Service Discovery

Podman provides automatic DNS resolution for containers on the same network:

```bash
# Create network
bazel run @podman//:podman -- network create services-network

# Run services
bazel run @podman//:podman -- run -d --name api-service --network services-network your-api
bazel run @podman//:podman -- run -d --name auth-service --network services-network your-auth
bazel run @podman//:podman -- run -d --name payment-service --network services-network your-payment

# Each service can reach others by name:
# - http://api-service:8000
# - http://auth-service:8001
# - http://payment-service:8002

# Test connectivity
bazel run @podman//:podman -- run --rm \
  --network services-network \
  curlimages/curl:latest \
  curl http://api-service:8000/health
```

### Network Isolation

Use separate networks to isolate different environments or applications:

```bash
# Frontend network (public-facing)
bazel run @podman//:podman -- network create frontend-network

# Backend network (internal only)
bazel run @podman//:podman -- network create backend-network

# Database in backend network only
bazel run @podman//:podman -- run -d \
  --name db \
  --network backend-network \
  postgres:15

# API in both networks
bazel run @podman//:podman -- run -d \
  --name api \
  --network backend-network \
  your-api
bazel run @podman//:podman -- network connect frontend-network api

# Frontend in frontend network only
bazel run @podman//:podman -- run -d \
  --name web \
  --network frontend-network \
  -p 3000:3000 \
  your-frontend

# Result: Frontend can reach API, API can reach DB, but Frontend cannot directly reach DB
```

### Networking with Docker Compose / Podman Compose

If you have a `docker-compose.yml`, Podman can run it with `podman-compose`:

```yaml
# docker-compose.yml
version: "3.8"

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: cosmos
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

  redis:
    image: redis:alpine
    networks:
      - app-network

  api:
    image: your-api:latest
    environment:
      DATABASE_URL: postgresql://postgres:secret@db:5432/cosmos
      REDIS_URL: redis://redis:6379
    depends_on:
      - db
      - redis
    ports:
      - "8000:8000"
    networks:
      - app-network

  web:
    image: your-web:latest
    environment:
      API_URL: http://api:8000
    depends_on:
      - api
    ports:
      - "3000:3000"
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  postgres-data:
```

```bash
# Install podman-compose (if not already installed)
pip install podman-compose

# Run with Podman
podman-compose up -d

# Or use Podman's docker compatibility
export DOCKER=podman
docker-compose up -d
```

### Best Practices

1. **Use custom networks** instead of the default bridge network for better DNS and isolation
2. **Group related services** in the same network
3. **Use container names** for service discovery instead of IP addresses
4. **Clean up unused networks** regularly with `network prune`
5. **Document network dependencies** in your README or compose file
6. **Use network isolation** to limit attack surface
7. **Expose only necessary ports** to the host

### Networking Troubleshooting

**Check container connectivity:**

```bash
# Check if containers can ping each other
bazel run @podman//:podman -- exec api ping -c 3 db

# Check DNS resolution
bazel run @podman//:podman -- exec api nslookup db

# Check network configuration
bazel run @podman//:podman -- inspect api --format='{{json .NetworkSettings}}'

# View all containers in network
bazel run @podman//:podman -- network inspect app-network

# Check port mappings
bazel run @podman//:podman -- port api
```

**Common issues:**

- **Containers can't communicate**: Make sure they're on the same network
- **DNS not working**: Verify containers are using custom network (not default bridge)
- **Port already in use**: Check if another container or process is using the port
- **Connection refused**: Ensure the service is listening on `0.0.0.0` not `127.0.0.1`

### Networking Features Comparison

| Feature                         | Docker | Podman |
| ------------------------------- | ------ | ------ |
| Bridge networks                 | ✅     | ✅     |
| Custom networks                 | ✅     | ✅     |
| DNS resolution                  | ✅     | ✅     |
| Port mapping                    | ✅     | ✅     |
| Network isolation               | ✅     | ✅     |
| IPv6 support                    | ✅     | ✅     |
| Multiple networks per container | ✅     | ✅     |
| Network aliases                 | ✅     | ✅     |
| **Rootless networking**         | ❌     | ✅     |
| **Better security**             | -      | ✅     |

**Podman advantages:**

- Rootless networking (better security)
- No daemon required
- Compatible with Docker networking commands
- CNI plugins support

## Configuration in MODULE.bazel

```starlark
podman = use_extension("//tools/podman:container_engine.bzl", "podman")
podman.toolchain(
    name = "podman_engine",
    version = "v5.5.2",         # Podman version
    gvproxy_version = "v0.8.7",  # gvproxy version (auto-downloaded)
    vfkit_version = "v0.6.1",    # vfkit version (auto-downloaded for macOS only)
)
use_repo(podman, "podman")

# Register the toolchain (optional, only needed if using custom rules)
register_toolchains("//tools/podman:podman_toolchain")
```

### What gets downloaded?

The toolchain automatically downloads the appropriate binaries for your platform:

**Linux:**

- `podman-static` (complete engine, no helpers needed)

**macOS:**

- `podman-remote` (client binary)
- `podman-mac-helper` (included in podman release)
- `gvproxy` (networking helper, auto-downloaded)
- `vfkit` (virtualization hypervisor, auto-downloaded)

**Windows:**

- `podman-remote` (client binary)
- `podman-mac-helper` (included in podman release)
- `gvproxy` (networking helper, auto-downloaded)

**Available executables:**

- `@podman//:podman` - Podman CLI
- `@podman//:gvproxy` - gvproxy networking helper
- `@podman//:vfkit` - vfkit hypervisor (macOS only)
- `@podman//:podman_setup` - Setup script (all platforms)

### Run PostgreSQL 15 Example

```bash
# Start PostgreSQL 15
bazel run @podman//:podman -- run -d \
  --name postgres15 \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=admin \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  docker.io/library/postgres:15

# Check status (multiple ways)
bazel run @podman//:podman -- ps
bazel run @podman//:podman -- ps --filter=name=postgres15
bazel run @podman//:podman -- inspect postgres15

# View logs
bazel run @podman//:podman -- logs postgres15
bazel run @podman//:podman -- logs -f postgres15  # Follow logs

# Connect to PostgreSQL
psql -h localhost -U admin -d mydb
# Password: mysecretpassword

# Stop PostgreSQL
bazel run @podman//:podman -- stop postgres15

# Remove container
bazel run @podman//:podman -- rm postgres15
```

## Why no custom rules needed?

Since you can run podman directly with `bazel run @podman//:podman -- [command]`, there's no need for wrapper
rules like `container_run` or `container_status`. Just use podman commands directly!

## Advanced: Use in Custom Bazel Rules

If you need to integrate podman into custom Bazel rules, you can use the toolchain. See `container.bzl` and `defs.bzl`
for example implementations.

## Adding Podman to bazel_env

For convenient access to podman in your development environment, you can add it to `bazel_env`:

```starlark
# In your root BUILD.bazel file
load("@bazel_env.bzl", "bazel_env")

bazel_env(
    name = "bazel_env",
    toolchains = {
        "jdk": "@rules_java//podman:current_host_java_runtime",
    },
    tools = {
        "buildifier": "@buildifier_prebuilt//:buildifier",
        "go": "@rules_go//go",
        "podman": "@podman//:podman",
        "jar": "$(JAVABASE)/bin/jar",
        "java": "$(JAVA)",
    },
)
```

Then run:

```bash
# Setup the environment
bazel run //:bazel_env

# This will show:
# ====== bazel_env ======
# direnv is installed
# direnv added bazel-out/bazel_env-opt/bin/bazel_env/bin to PATH
#
# Tools available in PATH:
#   * buildifier: @buildifier_prebuilt//:buildifier
#   * go:         @rules_go//go
#   * podman:     @podman//:podman
#   * jar:        $(JAVABASE)/bin/jar
#   * java:       $(JAVA)

# Now you can use podman directly without the bazel run prefix
podman --version
podman ps
podman images
# etc...
```

This is especially useful for:

- Development workflows where you frequently use podman
- Scripts that need podman in PATH
- IDE integrations that expect podman to be available
- Team members who want a consistent environment setup

### Run PostgreSQL 15 Example

```bash
# Start PostgreSQL 15
bazel run @podman//:podman -- run -d \
  --name postgres15 \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_USER=admin \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  docker.io/library/postgres:15

# Check status (multiple ways)
bazel run @podman//:podman -- ps
bazel run @podman//:podman -- ps --filter=name=postgres15
bazel run @podman//:podman -- inspect postgres15

# View logs
bazel run @podman//:podman -- logs postgres15
bazel run @podman//:podman -- logs -f postgres15  # Follow logs

# Connect to PostgreSQL
psql -h localhost -U admin -d mydb
# Password: mysecretpassword

# Stop PostgreSQL
bazel run @podman//:podman -- stop postgres15

# Remove container
bazel run @podman//:podman -- rm postgres15
```

## Troubleshooting

### Error: "could not find gvproxy"

**Error message:**

```
Error: could not find "gvproxy" in one of [$BINDIR/../libexec/podman /usr/local/opt/podman/libexec/podman ...]
```

**Cause:** Podman cannot find the helper binaries (`gvproxy`, `vfkit`) that were downloaded by Bazel.

**Solution:** Configure `containers.conf` before running `machine init`:

```bash
mkdir -p ~/.config/containers
cat > ~/.config/containers/containers.conf << EOF
[engine]
helper_binaries_dir=["$(bazel info output_base)/external/+container_engine+podman_engine"]
EOF

# Then initialize/start the machine
bazel run @podman//:podman -- machine init
bazel run @podman//:podman -- machine start
```

### Error: "Cannot connect to Podman"

**Error message:**

```
Cannot connect to Podman. Please verify your connection to the Linux system...
Error: unable to connect to Podman socket: failed to connect: dial tcp 127.0.0.1:54333: connect: connection refused
```

**Cause:** The podman machine is not running.

**Solution:** Start the machine:

```bash
bazel run @podman//:podman -- machine start
```

### Error: "VM already exists"

**Error message:**

```
Error: podman-machine-default: VM already exists
```

**Cause:** You're trying to run `machine init` when a machine already exists.

**Solution:** Skip init and just start the machine:

```bash
bazel run @podman//:podman -- machine start
```

Or delete the existing machine and start fresh:

```bash
bazel run @podman//:podman -- machine rm podman-machine-default
bazel run @podman//:podman -- machine init
bazel run @podman//:podman -- machine start
```

### Error: podman command not found (when using bazel_env)

**Error message:**

```
zsh: command not found: podman
```

**Cause:** You haven't activated direnv in your current shell.

**Solution:** Load direnv:

```bash
# If direnv is installed and configured
eval "$(direnv export zsh)"  # for zsh
eval "$(direnv export bash)" # for bash

# Or cd to the project directory to trigger direnv
cd /path/to/cosmos

# Or use the full bazel run command instead
bazel run @podman//:podman -- ps
```

### Podman machine configuration file location

If you need to check or modify your containers.conf:

```bash
# View current config
cat ~/.config/containers/containers.conf

# Location where Bazel stores helper binaries
echo "$(bazel info output_base)/external/+container_engine+podman_engine"

# List downloaded binaries
ls -la "$(bazel info output_base)/external/+container_engine+podman_engine/"
```

### Error: "vfkit exited unexpectedly with exit code 1"

**Error message:**

```
Error: vfkit exited unexpectedly with exit code 1
```

**Causes:** This error can have several causes:

1. **Insufficient permissions** - vfkit may not have the necessary permissions
2. **Previous machine state** - A corrupted or incomplete previous machine initialization
3. **macOS Virtualization Framework issues** - macOS Ventura (13.0) or later is required

**Solutions:**

**1. Delete and recreate the machine:**

```bash
# Remove the existing machine
bazel run @podman//:podman -- machine rm podman-machine-default

# Recreate it
bazel run @podman//:podman -- machine init
bazel run @podman//:podman -- machine start
```

**2. Check vfkit directly:**

```bash
# Test vfkit
bazel run @podman//:vfkit -- --version

# If this fails, vfkit may not be compatible with your system
```

**3. Use the official Podman installer instead:**

If the Bazel-downloaded binaries don't work on your system, use the official installer which includes tested versions:

```bash
# Download official installer
curl -LO https://github.com/containers/podman/releases/download/v5.5.2/podman-installer-macos-arm64.pkg

# Install
sudo installer -pkg podman-installer-macos-arm64.pkg -target /

# Use system podman instead of Bazel's
podman machine init
podman machine start

# For OCI operations, use system podman
export DOCKER="podman"  # System podman from PATH
```

**4. Check macOS version:**

```bash
# vfkit requires macOS 13.0 (Ventura) or later
sw_vers

# If you're on an older version, you need to upgrade macOS or use the .pkg installer
```
