# Podman Rules for Bazel

A fully hermetic Bazel toolchain for Podman. Run containers and Kubernetes pods in your builds and tests without
installing Podman globally.

## Highlights

- **Hermetic**: Podman and all required helper binaries (`gvproxy`, `vfkit`) are downloaded by Bazel. No system
  installation required.
- **Easy Setup**: One-command initialization for macOS and Windows. Native execution on Linux.
- **Developer Experience**: Fully compatible with [`bazel_env`](https://github.com/buildbuddy-io/bazel_env.bzl) for a
  seamless shell experience.

## Installation

Add the following to your `MODULE.bazel`:

```starlark
bazel_dep(name = "bazel_podman", version = "0.0.1") # Check for latest version

podman = use_extension("@bazel_podman//:extensions.bzl", "podman")
use_repo(podman, "podman")

register_toolchains("@bazel_podman//:podman_toolchain")
```

## Getting Started

### 1. First Time Setup

**Linux Users:**
No setup required! Podman runs natively.

**macOS & Windows Users:**
Podman requires a Linux VM (machine) to run containers. We provide a setup script to configure the helper binaries and
initialize the machine.

Run this **once**:

```bash
# 1. Configure helper binaries and create ~/.config/containers/containers.conf
bazel run @podman//:setup

# 2. Initialize the Podman machine
bazel run @podman//:podman -- machine init

# 3. Start the machine
bazel run @podman//:podman -- machine start
```

### 2. Verify Installation

```bash
bazel run @podman//:podman -- info
```

## Usage

### Using Podman directly

You can run any Podman command via Bazel:

```bash
# Run a container
bazel run @podman//:podman -- run --rm docker.io/library/alpine echo "Hello from Podman!"

# List containers
bazel run @podman//:podman -- ps -a
```

### Using Bazel Rules

We provide ergonomic rules for running containers and Kubernetes manifests.

#### `container_run`

Starts a container. Handles idempotency (won't restart if already running) and lifecycle management.

```starlark
load("@bazel_podman//:container.bzl", "container_run")

container_run(
    name = "postgres",
    image_ref = "docker.io/library/postgres:15",
    ports = {"5432": "5432"},
    env = {
        "POSTGRES_PASSWORD": "mysecretpassword",
        "POSTGRES_DB": "mydb",
    },
)
```

**Commands:**

- Start: `bazel run //:postgres`
- Stop: `bazel run //:postgres.stop`
- Logs: `bazel run //:postgres.logs`
- Shell: `bazel run //:postgres.bash`

#### `podman_play_kube`

Deploys a Kubernetes manifest using `podman play kube`.

```starlark
load("@bazel_podman//:kube.bzl", "podman_play_kube")

podman_play_kube(
    name = "app",
    manifest = "deployment.yaml",
)
```

**Commands:**

- Deploy: `bazel run //:app`
- Teardown: `bazel run //:app.down`

## Development Environment (`bazel_env`)

For the best developer experience, use `bazel_env` to add `podman` to your PATH automatically when inside the project.
This allows you to use `podman` commands directly without `bazel run`.

1. Add `bazel_env` to your `MODULE.bazel`:
    ```starlark
    bazel_dep(name = "bazel_env.bzl", version = "0.3.0")
    ```

2. Configure it in your `BUILD.bazel`:
    ```starlark
    load("@bazel_env.bzl", "bazel_env")

    bazel_env(
        name = "env",
        tools = {
            "podman": "@podman//:podman",
        },
    )
    ```

3. Setup `direnv`:
    ```bash
    bazel run //:env
    # Follow instructions to hook into direnv
    ```

Now `podman` is in your PATH!
```bash
podman ps
podman run hello-world
```

## Documentation

Detailed documentation for rules:

- [Container Rules](container.md)
- [Kubernetes Rules](kube.md)
