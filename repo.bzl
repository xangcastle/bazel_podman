def _normalize_os(os_name):
    n = os_name.lower()
    if n == "mac os x" or n == "darwin":
        return "darwin"
    if n.startswith("windows"):
        return "windows"
    return "linux"

def _normalize_arch(arch_name):
    a = arch_name.lower()
    if a in ["x86_64", "amd64"]:
        return "amd64"
    if a in ["aarch64", "arm64"]:
        return "arm64"
    return a

def _default_urls(version):
    return {
        "linux_amd64": "https://github.com/mgoltzsche/podman-static/releases/download/v5.2.2/podman-linux-amd64.tar.gz",
        "linux_arm64": "https://github.com/mgoltzsche/podman-static/releases/download/v5.2.2/podman-linux-arm64.tar.gz",
        "darwin_amd64": "https://github.com/containers/podman/releases/download/%s/podman-remote-release-darwin_amd64.zip" % version,
        "darwin_arm64": "https://github.com/containers/podman/releases/download/%s/podman-remote-release-darwin_arm64.zip" % version,
        "windows_amd64": "https://github.com/containers/podman/releases/download/%s/podman-remote-release-windows_amd64.zip" % version,
        "windows_arm64": "https://github.com/containers/podman/releases/download/%s/podman-remote-release-windows_arm64.zip" % version,
    }

def _gvproxy_urls(gvproxy_version):
    return {
        "darwin_amd64": "https://github.com/containers/gvisor-tap-vsock/releases/download/%s/gvproxy-darwin" % gvproxy_version,
        "darwin_arm64": "https://github.com/containers/gvisor-tap-vsock/releases/download/%s/gvproxy-darwin" % gvproxy_version,
        "windows_amd64": "https://github.com/containers/gvisor-tap-vsock/releases/download/%s/gvproxy-windows.exe" % gvproxy_version,
        "windows_arm64": "https://github.com/containers/gvisor-tap-vsock/releases/download/%s/gvproxy-windows.exe" % gvproxy_version,
        "linux_amd64": "https://github.com/containers/gvisor-tap-vsock/releases/download/%s/gvproxy-linux-amd64" % gvproxy_version,
        "linux_arm64": "https://github.com/containers/gvisor-tap-vsock/releases/download/%s/gvproxy-linux-arm64" % gvproxy_version,
    }

def _vfkit_urls(vfkit_version):
    # vfkit is macOS-only, universal binary
    return {
        "darwin_amd64": "https://github.com/crc-org/vfkit/releases/download/%s/vfkit" % vfkit_version,
        "darwin_arm64": "https://github.com/crc-org/vfkit/releases/download/%s/vfkit" % vfkit_version,
    }

def _detect_platform_key(repo_ctx):
    os_norm = _normalize_os(repo_ctx.os.name)
    arch_norm = _normalize_arch(repo_ctx.os.arch)
    return "{}_{}".format(os_norm, arch_norm)

def _podman_repo_impl(repo_ctx):
    version = repo_ctx.attr.version
    gvproxy_version = repo_ctx.attr.gvproxy_version
    vfkit_version = repo_ctx.attr.vfkit_version
    urls = _default_urls(version)
    gvproxy_urls_map = _gvproxy_urls(gvproxy_version)
    vfkit_urls_map = _vfkit_urls(vfkit_version)

    for k, v in repo_ctx.attr.urls_override.items():
        urls[k] = v

    for k, v in repo_ctx.attr.gvproxy_urls_override.items():
        gvproxy_urls_map[k] = v

    for k, v in repo_ctx.attr.vfkit_urls_override.items():
        vfkit_urls_map[k] = v

    platform_key = _detect_platform_key(repo_ctx)
    if platform_key not in urls:
        fail("Unsupported platform or no URL configured: " + platform_key)

    url = urls[platform_key]
    gvproxy_url = gvproxy_urls_map[platform_key]
    vfkit_url = vfkit_urls_map.get(platform_key)

    sha256_map = repo_ctx.attr.sha256_override
    gvproxy_sha256_map = repo_ctx.attr.gvproxy_sha256_override
    vfkit_sha256_map = repo_ctx.attr.vfkit_sha256_override
    sha256 = sha256_map.get(platform_key) if sha256_map else None
    gvproxy_sha256 = gvproxy_sha256_map.get(platform_key) if gvproxy_sha256_map else None
    vfkit_sha256 = vfkit_sha256_map.get(platform_key) if vfkit_sha256_map else None

    if sha256:
        repo_ctx.download_and_extract(url = url, sha256 = sha256)
    else:
        repo_ctx.download_and_extract(url = url)

    gvproxy_filename = "gvproxy.bin.exe" if platform_key.startswith("windows") else "gvproxy.bin"
    if gvproxy_sha256:
        repo_ctx.download(url = gvproxy_url, output = gvproxy_filename, sha256 = gvproxy_sha256, executable = True)
    else:
        repo_ctx.download(url = gvproxy_url, output = gvproxy_filename, executable = True)

    if vfkit_url:
        vfkit_filename = "vfkit.bin"
        if vfkit_sha256:
            repo_ctx.download(url = vfkit_url, output = vfkit_filename, sha256 = vfkit_sha256, executable = True)
        else:
            repo_ctx.download(url = vfkit_url, output = vfkit_filename, executable = True)

    if repo_ctx.path("gvproxy.bin").exists:
        repo_ctx.symlink("gvproxy.bin", "gvproxy")
    if vfkit_url and repo_ctx.path("vfkit.bin").exists:
        repo_ctx.symlink("vfkit.bin", "vfkit")

    repo_ctx.template(
        "podman_setup.sh",
        Label("@//tools/podman:setup.tpl"),
        substitutions = {
            "{helper_dir}": str(repo_ctx.path(".")),
        },
        executable = True,
    )

    vfkit_wrapper = """
podman_wrapper(
    name = "vfkit",
    binary = "vfkit.bin",
)
""" if vfkit_url else ""
    vfkit_data = """
        ":vfkit",""" if vfkit_url else ""
    
    repo_ctx.template(
        "BUILD.bazel",
        Label("@//tools/podman:BUILD.bazel.tpl"),
        substitutions = {
            "{vfkit_wrapper}": vfkit_wrapper,
            "{vfkit_data}": vfkit_data,
        },
    )

podman_repo = repository_rule(
    implementation = _podman_repo_impl,
    attrs = {
        "version": attr.string(default = "v5.5.2"),
        "gvproxy_version": attr.string(default = "v0.7.3"),
        "vfkit_version": attr.string(default = "v0.6.1"),
        "urls_override": attr.string_dict(default = {}),
        "gvproxy_urls_override": attr.string_dict(default = {}),
        "vfkit_urls_override": attr.string_dict(default = {}),
        "sha256_override": attr.string_dict(default = {}),
        "gvproxy_sha256_override": attr.string_dict(default = {}),
        "vfkit_sha256_override": attr.string_dict(default = {}),
    },
)
