def _podman_play_kube_impl(ctx):
    toolchain = ctx.toolchains["@bazel_podman//:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file
    
    manifest = ctx.file.manifest
    command = ctx.attr.command
    
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    
    ctx.actions.expand_template(
        template = ctx.file._launcher,
        output = executable,
        substitutions = {
            "%{podman_path}": podman.short_path,
            "%{manifest_path}": manifest.short_path,
            "%{command}": command,
        },
        is_executable = True,
    )
    
    runfiles = ctx.runfiles(files = [podman, manifest])
    return [DefaultInfo(executable = executable, runfiles = runfiles)]

_podman_play_kube = rule(
    implementation = _podman_play_kube_impl,
    attrs = {
        "manifest": attr.label(allow_single_file = [".yaml", ".yml", ".json"], mandatory = True),
        "command": attr.string(default = "play", values = ["play", "down"]),
        "_launcher": attr.label(
            default = Label("//:kube_launcher.tpl"),
            allow_single_file = True,
        ),
    },
    toolchains = ["@bazel_podman//:podman_toolchain_type"],
    executable = True,
)

def podman_play_kube(name, manifest, **kwargs):
    """Deploys a Kubernetes manifest using Podman pods.

    Generates two targets:
      :name -> Plays the manifest (creates pods)
      :name.down -> Tears down the pods

    Args:
        name: Target name.
        manifest: The yaml manifest file.
        **kwargs: Arguments passed to underlying rules.
    """
    _podman_play_kube(
        name = name,
        manifest = manifest,
        command = "play",
        **kwargs
    )
    
    _podman_play_kube(
        name = name + ".down",
        manifest = manifest,
        command = "down",
        **kwargs
    )
