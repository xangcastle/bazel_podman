PodmanInfo = provider(
    # todo: investigate in the podman repo what's the correct names
    doc = "Information about the Podman toolchain.",
    fields = {
        "executable_file": "File: The podman executable file.",
        "executable_path": "string: The short path to the podman executable.",
    },
)

def _podman_toolchain_impl(ctx):
    executable = ctx.files.executable[0]
    return [
        platform_common.ToolchainInfo(
            podman_info = PodmanInfo(
                executable_file = executable,
                executable_path = executable.short_path,
            ),
        ),
    ]

podman_toolchain_rule = rule(
    implementation = _podman_toolchain_impl,
    attrs = {
        "executable": attr.label(
            doc = "The podman executable.",
            allow_files = True, 
            cfg = "exec",
            mandatory = True,
        ),
    },
    doc = "Defines a podman toolchain.",
)
