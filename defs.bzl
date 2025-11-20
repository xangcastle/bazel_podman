load("@//tools/podman:provider.bzl", "PodmanInfo")

podman_toolchain_rule = rule(
    implementation = lambda ctx: [
        platform_common.ToolchainInfo(
            engine_info = PodmanInfo(
                executable_file = ctx.files.executable[0], 
                executable_path = ctx.files.executable[0].path,
            ),
        ),
    ],
    attrs = {"executable": attr.label(allow_files = True, cfg = "exec")},
)


def _container_run_impl(ctx):
    toolchain = ctx.toolchains["//tools/podman:podman_toolchain_type"]
    engine_executable = toolchain.engine_info.executable_file

    env_flags = ""
    if ctx.attr.env:
        for key, value in ctx.attr.env.items():
            env_flags += "-e " + key + "=" + value + " "

    port_flags = ""
    if ctx.attr.ports:
        for host_port, container_port in ctx.attr.ports.items():
            port_flags += "-p " + host_port + ":" + container_port + " "

    engine_short_path = engine_executable.short_path

    script_content = """
#!/bin/bash
set -e

if [[ -z "${{RUNFILES_DIR:-}}" ]]; then
    if [[ -d "$0.runfiles/_main" ]]; then
        RUNFILES_DIR="$0.runfiles/_main"
    elif [[ -d "$0.runfiles" ]]; then
        RUNFILES_DIR="$0.runfiles"
    else
        echo "ERROR: Cannot find runfiles directory"
        exit 1
    fi
fi

ENGINE="${{RUNFILES_DIR}}/{engine_path}"

echo "Starting container with image: {image}"
if "$ENGINE" ps --filter=name={name} | grep -q {name}; then
    echo "Container '{name}' is already running."
elif "$ENGINE" ps -a --filter=name={name} | grep -q {name}; then
    echo "Container '{name}' exists but is stopped. Starting it..."
    "$ENGINE" start {name}
    echo "Container '{name}' started."
else
    "$ENGINE" run -d {env_flags}{port_flags}--name {name} {image}
    echo "Container '{name}' created and started."
fi
echo "To stop the container, use: podman stop {name}"
echo "To remove the container, use: podman rm {name}"
echo "To view container logs, use: podman logs {name}"
""".format(
        engine_path = engine_short_path,
        image = ctx.attr.image,
        name = ctx.attr.name,
        port_flags = port_flags,
        env_flags = env_flags,
    )

    script = ctx.actions.declare_file(ctx.attr.name + ".sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [engine_executable])

    return [DefaultInfo(executable = script, runfiles = runfiles)]

container_run = rule(
    implementation = _container_run_impl,
    attrs = {
        "image": attr.string(mandatory = True, doc = "The container image to run."),
        "ports": attr.string_dict(doc = "Port mappings as a dictionary, e.g., {'5432': '5432'} maps host port 5432 to container port 5432"),
        "env": attr.string_dict(doc = "Environment variables to pass to the container"),
    },
    toolchains = ["//tools/podman:podman_toolchain_type"],
    executable = True,
)
