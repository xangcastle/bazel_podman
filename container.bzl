def _container_run_impl(ctx):
    toolchain = ctx.toolchains["//tools/podman:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file
    label_name = "@" + ctx.label.repo_name + "//" + ctx.label.package + ":" + ctx.label.name

    env_flags = ""
    if ctx.attr.env:
        for key, value in ctx.attr.env.items():
            env_flags += "-e " + key + "=" + value + " "

    port_flags = ""
    if ctx.attr.ports:
        for host_port, container_port in ctx.attr.ports.items():
            port_flags += "-p " + host_port + ":" + container_port + " "

    volume_flags = ""
    volume_files = []
    if ctx.attr.volumes:
        for target, dest in ctx.attr.volumes.items():
            for src_file in target.files.to_list():
                volume_files.append(src_file)
                volume_flags += "-v \"${{RUNFILES_DIR}}/{src}:{dest}:Z\" ".format(
                    src = src_file.short_path,
                    dest = dest,
                )

    executable_content = """
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

PODMAN="${{RUNFILES_DIR}}/{podman_path}"

echo ""
echo "====== {name} ======"
echo ""
echo "🚀 Starting container with image: {image}"
if "$PODMAN" ps --filter=name={name} | grep -q {name}; then
    echo "✅ Container '{name}' is already running."
elif "$PODMAN" ps -a --filter=name={name} | grep -q {name}; then
    echo "🔄 Container '{name}' exists but is stopped. Starting it..."
    "$PODMAN" start {name}
    echo "✅ Container '{name}' started."
else
    "$PODMAN" run -d {env_flags}{port_flags}{volume_flags}--name {name} {image}
    echo "✨ Container '{name}' created and started."
fi

echo ""
echo "Usage:"
echo "  🛑 Stop:  bazel run {label_name}.stop"
echo "  📜 Logs:  bazel run {label_name}.logs"
echo "  🐚 Shell: bazel run {label_name}.bash"
echo "  🐳 Podman: bazel run @podman//:podman -- <command>"
echo ""
""".format(
        podman_path = podman.short_path,
        image = ctx.attr.image,
        name = ctx.attr.name,
        port_flags = port_flags,
        env_flags = env_flags,
        volume_flags = volume_flags,
        label_name = label_name,
    )

    executable = ctx.actions.declare_file(ctx.attr.name + ".sh")
    ctx.actions.write(
        output = executable,
        content = executable_content,
        is_executable = True,
    )

    runfiles_files = [podman] + volume_files
    runfiles = ctx.runfiles(files = runfiles_files)

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

container_run = rule(
    implementation = _container_run_impl,
    doc = "Run a container with the specified configuration.",
    attrs = {
        "image": attr.string(mandatory = True, doc = "Container image to run"),
        "ports": attr.string_dict(doc = "Port mappings, e.g., {'5432': '5432'}"),
        "env": attr.string_dict(doc = "Environment variables, e.g., {'POSTGRES_PASSWORD': 'secret'}"),
        "volumes": attr.label_keyed_string_dict(allow_files = True, doc = "Volume mappings, e.g., {':init.sql': '/docker-entrypoint-initdb.d/init.sql'}"),
    },
    toolchains = ["//tools/podman:podman_toolchain_type"],
    executable = True,
)

def _container_stop_impl(ctx):
    toolchain = ctx.toolchains["//tools/podman:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file

    executable_content = """
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

PODMAN="${{RUNFILES_DIR}}/{podman_path}"

if "$PODMAN" ps --filter=name={name} | grep -q {name}; then
    "$PODMAN" stop {name}
    echo "🛑 Container '{name}' stopped."
else
    echo "⚠️  Container '{name}' is not running."
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
    toolchains = ["//tools/podman:podman_toolchain_type"],
    executable = True,
)

def _container_logs_impl(ctx):
    toolchain = ctx.toolchains["//tools/podman:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file

    executable_content = """
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

PODMAN="${{RUNFILES_DIR}}/{podman_path}"

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
    toolchains = ["//tools/podman:podman_toolchain_type"],
    executable = True,
)

def _container_bash_impl(ctx):
    toolchain = ctx.toolchains["//tools/podman:podman_toolchain_type"]
    podman = toolchain.podman_info.executable_file

    executable_content = """
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

PODMAN="${{RUNFILES_DIR}}/{podman_path}"

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
    toolchains = ["//tools/podman:podman_toolchain_type"],
    executable = True,
)
