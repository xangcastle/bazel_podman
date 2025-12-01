load("//:container.bzl", "container_bash", "container_logs", "container_run", "container_stop")

def podman_container(name, image, ports = {}, env = {}, volumes = {}, tag = None, **kwargs):
    """Run a container with the specified configuration.

    Args:
        name: Name of the container
        image: Container image to run. Can be a string (remote ref like 'postgres:16') or a Label (loader target).
        ports: Port mappings, e.g., {"5432": "5432"}
        env: Environment variables, e.g., {"POSTGRES_PASSWORD": "secret"}
        volumes: Volume mappings, e.g., {":init.sql": "/docker-entrypoint-initdb.d/init.sql"}
        tag: Optional tag to run if image is a Label (loader).
        **kwargs: Additional arguments passed to the underlying rule
    """
    container_run(
        name = name,
        loader = image,
        tag = tag,
        ports = ports,
        env = env,
        volumes = volumes,
        **kwargs
    )

    base_name = name
    if name.endswith(".run"):
        base_name = name[:-4]

    container_stop(
        name = base_name + ".stop",
        container_name = name,
    )

    container_logs(
        name = base_name + ".logs",
        container_name = name,
    )

    container_bash(
        name = base_name + ".bash",
        container_name = name,
    )
