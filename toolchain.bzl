PodmanInfo = provider(
    fields = {
        "executable_file": "The file object of the podman binary",
        "executable_path": "The path to the podman binary",
    },
)

podman_toolchain_rule = rule(
    implementation = lambda ctx: [
        platform_common.ToolchainInfo(
            podman_info = PodmanInfo(
                executable_file = ctx.files.executable[0],
                executable_path = ctx.files.executable[0].path,
            ),
        ),
    ],
    attrs = {"executable": attr.label(allow_files = True, cfg = "exec")},
)
