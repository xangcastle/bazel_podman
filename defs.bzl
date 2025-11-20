ContainerEngineInfo = provider(
    fields = {"executable_file": "The file object of the container engine binary", "executable_path": "The path to the container engine binary"},
)

container_engine_toolchain = rule(
    implementation = lambda ctx: [
        platform_common.ToolchainInfo(
            engine_info = ContainerEngineInfo(
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
    engine_path = toolchain.engine_info.executable_path

    env_flags = ""
    if ctx.attr.env:
        for key, value in ctx.attr.env.items():
            env_flags += "-e " + key + "=" + value + " "

    script_content = """
#!/bin/bash
set -e
echo "Starting container with image: {image}"
if {engine} ps -a --filter=name={name} | grep -q {name}; then
    echo "Container '{name}' is already running."
else
    {engine} run -d {env_flags}--name {name} -p {ports} {image}
    echo "Container '{name}' started."
fi
echo "To stop the container, use: {engine} stop {name}"
echo "To remove the container, use: {engine} rm {name}"
echo "To view container logs, use: {engine} logs {name}"
""".format(
        engine = engine_path,
        image = ctx.attr.image,
        name = ctx.attr.name,
        ports = ctx.attr.ports,
        env_flags = env_flags,
    )

    script = ctx.actions.declare_file(ctx.attr.name + ".sh")
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [engine_executable])
    runfiles = runfiles.merge(ctx.runfiles(files = [script]))

    return [DefaultInfo(executable = script, runfiles = runfiles)]

container_run = rule(
    implementation = _container_run_impl,
    attrs = {
        "image": attr.string(mandatory = True, doc = "The container image to run."),
        "ports": attr.string(doc = "Port mapping, e.g., '5432:5432'"),
        "env": attr.string_dict(doc = "Environment variables to pass to the container"),
    },
    toolchains = ["//tools/podman:podman_toolchain_type"],
    executable = True,
)
