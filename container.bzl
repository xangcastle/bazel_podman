def _generate_common_substitutions(ctx, toolchain, label_name):
    # Environment variables
    env_flags = ""
    if ctx.attr.env:
        for key, value in ctx.attr.env.items():
            # Simple escaping
            val = value.replace("\"", "\\\"")
            env_flags += "-e \"{}={}\" ".format(key, val)

    # Ports
    port_flags = ""
    if ctx.attr.ports:
        for host_port, container_port in ctx.attr.ports.items():
            port_flags += "-p {}:{} ".format(host_port, container_port)

    # Volumes
    volume_files = []
    volume_setup_str = ""
    if ctx.attr.volumes:
        for target, dest in ctx.attr.volumes.items():
            for src_file in target.files.to_list():
                volume_files.append(src_file)
                # Determine robust path for the volume source
                volume_setup_str += """
src="{src}"
dest="{dest}"
resolved=$(resolve_path "$src")
VOLUME_FLAGS+=("-v" "$resolved:$dest:Z")
""".format(src = src_file.short_path, dest = dest)

    # Command
    cmd_args = ""
    if ctx.attr.command:
        # Join with quotes for bash array
        cmd_args = " ".join(["\"{}\"".format(c.replace("\"", "\\\"")) for c in ctx.attr.command])

    # Determine base label for auxiliary targets (matching podman_container macro logic)
    # label_name is like @repo//pkg:name
    if label_name.endswith(".run"):
        base_label = label_name[:-4]
    else:
        base_label = label_name

    return {
        "%{podman_path}": toolchain.podman_info.executable_file.short_path,
        "%{container_name}": ctx.attr.name,
        "%{image}": ctx.attr.image_ref,
        "%{env_flags}": env_flags,
        "%{port_flags}": port_flags,
        "%{volume_setup}": volume_setup_str,
        "%{command_args}": cmd_args,
        "%{label_name}": label_name,
        "%{label_stop}": base_label + ".stop",
        "%{label_logs}": base_label + ".logs",
        "%{label_bash}": base_label + ".bash",
    }, volume_files

def _container_run_impl(ctx):
    toolchain = ctx.toolchains["@bazel_podman//:podman_toolchain_type"]
    label_name = "@{}//{}:{}".format(ctx.label.repo_name, ctx.label.package, ctx.label.name)

    substitutions, volume_files = _generate_common_substitutions(ctx, toolchain, label_name)

    # Loader logic (for OCI images)
    loader_files = []
    if ctx.attr.loader:
        loader_info = ctx.attr.loader[DefaultInfo]
        loader_bin = loader_info.files_to_run.executable
        loader_files.append(loader_bin)
        # Add loader runfiles
        runfiles_from_loader = loader_info.default_runfiles
        
        substitutions["%{loader_block}"] = """
LOADER_BIN=$(resolve_path "{}")
""".format(loader_bin.short_path)
    else:
        substitutions["%{loader_block}"] = ""
        runfiles_from_loader = ctx.runfiles()

    # Generate script
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = executable,
        substitutions = substitutions,
        is_executable = True,
    )

    # Runfiles
    runfiles = ctx.runfiles(files = [toolchain.podman_info.executable_file] + volume_files + loader_files)
    runfiles = runfiles.merge(runfiles_from_loader)

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

_container_run_rule = rule(
    implementation = _container_run_impl,
    doc = """
Runs a container using Podman.

This rule generates an executable script that:
1. Loads the OCI image if a loader target is provided.
2. Checks if a container with the same name is already running.
3. If running, it does nothing (idempotent).
4. If stopped, it starts it.
5. If missing, it creates and starts it using `podman run`.

It automatically handles volume mounting from Bazel runfiles to the container.
""",
    attrs = {
        "image_ref": attr.string(
            mandatory = True, 
            doc = "The image reference string (e.g. 'localhost/my-image:latest' or 'postgres:16')."
        ),
        "loader": attr.label(
            executable = True, 
            cfg = "target", 
            doc = "Optional: Label of an `oci_load` target. If provided, this target runs before starting the container."
        ),
        "ports": attr.string_dict(
            doc = "Map of host ports to container ports (e.g. {'8080': '80'})."
        ),
        "env": attr.string_dict(
            doc = "Map of environment variables to set in the container."
        ),
        "volumes": attr.label_keyed_string_dict(
            allow_files = True, 
            doc = "Map of Bazel file targets to container paths (e.g. {':config.file': '/app/config'})."
        ),
        "command": attr.string_list(
            doc = "Command arguments to override the default entrypoint/cmd."
        ),
        "_launcher_template": attr.label(
            default = Label("//:launcher.tpl"),
            allow_single_file = True,
            doc = "Template for the launcher script.",
        ),
    },
    toolchains = ["@bazel_podman//:podman_toolchain_type"],
    executable = True,
)

def container_run(name, loader, tag = None, **kwargs):
    """
    Macro to run a container.

    Args:
        name: The name of the target.
        loader: Either a string (remote image reference) or a Label (an existing `oci_load` target).
                If `loader` is a Label, it is executed to load the image.
                If `loader` is a string, it is treated as a remote image reference (e.g. `postgres:16`) and no loader step is performed.
        tag: (Optional) The image tag/reference to run. Only used if `loader` is a Label. 
             If not provided, defaults to `{name}:latest`.
        **kwargs: Additional arguments passed to the underlying rule (ports, env, volumes, command).
    """
    is_loader_target = False
    if type(loader) != "string":
        is_loader_target = True
    elif loader.startswith("//") or loader.startswith(":") or loader.startswith("@"):
        is_loader_target = True

    if not is_loader_target:
        # Remote image reference (e.g. "postgres:16")
        _container_run_rule(
            name = name,
            image_ref = loader,
            **kwargs
        )
    else:
        # Loader target (Label or Label-like string)
        # Use provided tag or default convention
        image_ref = tag if tag else (name + ":latest")
        
        _container_run_rule(
            name = name,
            image_ref = image_ref,
            loader = loader,
            **kwargs
        )

def _container_stop_impl(ctx):
    toolchain = ctx.toolchains["@bazel_podman//:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file

    executable_content = """
#!/bin/bash
set -e

if [[ -z "${{RUNFILES_DIR:-}}" ]]; then
    if [[ -d "$0.runfiles" ]]; then
        export RUNFILES_DIR="$0.runfiles"
    else
        echo "ERROR: Cannot find runfiles directory"
        exit 1
    fi
fi

# Verify if we are in a Bzlmod structure with _main
if [[ -d "$RUNFILES_DIR/_main" ]]; then
    :
fi

PODMAN="${{RUNFILES_DIR}}/{podman_path}"

# Fix paths if they start with ../ (which short_path does for external deps)
if [[ "{podman_path}" == ../* ]]; then
    CLEAN_PODMAN_PATH="{podman_path}"
    CLEAN_PODMAN_PATH="${{CLEAN_PODMAN_PATH#../}}"
    PODMAN="${{RUNFILES_DIR}}/$CLEAN_PODMAN_PATH"
else
    if [[ -d "${{RUNFILES_DIR}}/_main" ]]; then
        PODMAN="${{RUNFILES_DIR}}/_main/{podman_path}"
    else
        PODMAN="${{RUNFILES_DIR}}/{podman_path}"
    fi
fi

if "$PODMAN" ps --filter=name={name} | grep -q {name}; then
    "$PODMAN" stop {name}
    echo "🛑 Container '{name}' stopped."
else
    echo "⚠️ Container '{name}' is not running."
fi
""".format(
        podman_path = podman.short_path,
        name = ctx.attr.container_name,
    )

    executable = ctx.actions.declare_file(ctx.attr.name + ".sh")
    ctx.actions.write(
        output = executable,
        content = executable_content,
        is_executable = True,
    )

    runfiles_files = [podman]
    runfiles = ctx.runfiles(files = runfiles_files)

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

container_stop = rule(
    implementation = _container_stop_impl,
    doc = "Stop a container.",
    attrs = {
        "container_name": attr.string(mandatory = True, doc = "Name of the container"),
    },
    toolchains = ["@bazel_podman//:podman_toolchain_type"],
    executable = True,
)

def _container_logs_impl(ctx):
    toolchain = ctx.toolchains["@bazel_podman//:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file

    executable_content = """
#!/bin/bash
set -e

if [[ -z "${{RUNFILES_DIR:-}}" ]]; then
    if [[ -d "$0.runfiles" ]]; then
        export RUNFILES_DIR="$0.runfiles"
    else
        echo "ERROR: Cannot find runfiles directory"
        exit 1
    fi
fi

# Verify if we are in a Bzlmod structure with _main
if [[ -d "$RUNFILES_DIR/_main" ]]; then
    :
fi

PODMAN="${{RUNFILES_DIR}}/{podman_path}"

# Fix paths if they start with ../ (which short_path does for external deps)
if [[ "{podman_path}" == ../* ]]; then
    CLEAN_PODMAN_PATH="{podman_path}"
    CLEAN_PODMAN_PATH="${{CLEAN_PODMAN_PATH#../}}"
    PODMAN="${{RUNFILES_DIR}}/$CLEAN_PODMAN_PATH"
else
    if [[ -d "${{RUNFILES_DIR}}/_main" ]]; then
        PODMAN="${{RUNFILES_DIR}}/_main/{podman_path}"
    else
        PODMAN="${{RUNFILES_DIR}}/{podman_path}"
    fi
fi

if "$PODMAN" ps --filter=name={name} | grep -q {name}; then
    "$PODMAN" logs {name}
else
    echo "Container '{name}' is not running."
fi
""".format(
        podman_path = podman.short_path,
        name = ctx.attr.container_name,
    )

    executable = ctx.actions.declare_file(ctx.attr.name + ".sh")
    ctx.actions.write(
        output = executable,
        content = executable_content,
        is_executable = True,
    )

    runfiles_files = [podman]
    runfiles = ctx.runfiles(files = runfiles_files)

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

container_logs = rule(
    implementation = _container_logs_impl,
    doc = "See logs of a running container.",
    attrs = {
        "container_name": attr.string(mandatory = True, doc = "Name of the container"),
    },
    toolchains = ["@bazel_podman//:podman_toolchain_type"],
    executable = True,
)

def _container_bash_impl(ctx):
    toolchain = ctx.toolchains["@bazel_podman//:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file

    executable_content = """
#!/bin/bash
set -e

if [[ -z "${{RUNFILES_DIR:-}}" ]]; then
    if [[ -d "$0.runfiles" ]]; then
        export RUNFILES_DIR="$0.runfiles"
    else
        echo "ERROR: Cannot find runfiles directory"
        exit 1
    fi
fi

# Verify if we are in a Bzlmod structure with _main
if [[ -d "$RUNFILES_DIR/_main" ]]; then
    :
fi

PODMAN="${{RUNFILES_DIR}}/{podman_path}"

# Fix paths if they start with ../ (which short_path does for external deps)
if [[ "{podman_path}" == ../* ]]; then
    CLEAN_PODMAN_PATH="{podman_path}"
    CLEAN_PODMAN_PATH="${{CLEAN_PODMAN_PATH#../}}"
    PODMAN="${{RUNFILES_DIR}}/$CLEAN_PODMAN_PATH"
else
    if [[ -d "${{RUNFILES_DIR}}/_main" ]]; then
        PODMAN="${{RUNFILES_DIR}}/_main/{podman_path}"
    else
        PODMAN="${{RUNFILES_DIR}}/{podman_path}"
    fi
fi

if "$PODMAN" ps --filter=name={name} | grep -q {name}; then
    "$PODMAN" exec -it {name} bash
else
    echo "Container '{name}' is not running."
fi
""".format(
        podman_path = podman.short_path,
        name = ctx.attr.container_name,
    )

    executable = ctx.actions.declare_file(ctx.attr.name + ".sh")
    ctx.actions.write(
        output = executable,
        content = executable_content,
        is_executable = True,
    )

    runfiles_files = [podman]
    runfiles = ctx.runfiles(files = runfiles_files)

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

container_bash = rule(
    implementation = _container_bash_impl,
    doc = "Start a bash inside a running container.",
    attrs = {
        "container_name": attr.string(mandatory = True, doc = "Name of the container"),
    },
    toolchains = ["@bazel_podman//:podman_toolchain_type"],
    executable = True,
)
