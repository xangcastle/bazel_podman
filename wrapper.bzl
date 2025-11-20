
def _podman_wrapper_impl(ctx):
    podman_binary = ctx.files.binary[0]

    wrapper_script = ctx.actions.declare_file(ctx.label.name)

    workspace = ctx.label.workspace_name if ctx.label.workspace_name else ctx.workspace_name
    binary_path = podman_binary.short_path

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = wrapper_script,
        substitutions = {
            "{workspace}": workspace,
            "{path}": binary_path,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = wrapper_script,
            runfiles = ctx.runfiles(files = [podman_binary]),
        ),
    ]

podman_wrapper = rule(
    implementation = _podman_wrapper_impl,
    attrs = {
        "binary": attr.label(allow_files = True),
        "_wrapper_template": attr.label(
            default = Label(":wrapper.tpl"),
            allow_single_file = True,
        ),
    },
    executable = True,
)