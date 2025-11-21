load("@//tools/podman:container.bzl", "container_bash", "container_logs", "container_run", "container_stop")

def podman_container(name, image, ports = {}, env = {}, volumes = {}, **kwargs):
    """Run a container with the specified configuration.

    Args:
        name: Name of the container
        image: Container image to run
        ports: Port mappings, e.g., {"5432": "5432"}
        env: Environment variables, e.g., {"POSTGRES_PASSWORD": "secret"}
        volumes: Volume mappings, e.g., {":init.sql": "/docker-entrypoint-initdb.d/init.sql"}
        **kwargs: Additional arguments passed to the underlying rule
    """
    container_run(
        name = name,
        image = image,
        ports = ports,
        env = env,
        volumes = volumes,
    )

    container_stop(
        name = name + ".stop",
        container_name = name,
    )

    container_logs(
        name = name + ".logs",
        container_name = name,
    )

    container_bash(
        name = name + ".bash",
        container_name = name,
    )
