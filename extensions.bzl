load("//tools/podman:repo.bzl", "podman_repo")

def _podman_ext_impl(module_ctx):
    registrations = {}

    for mod in module_ctx.modules:
        for engine in mod.tags.toolchain:
            if engine.name in registrations:
                fail("Duplicate: a podman with name = '{}' already exists".format(engine.name))

            registrations[engine.name] = {
                "version": engine.version,
                "gvproxy_version": engine.gvproxy_version,
                "vfkit_version": engine.vfkit_version,
                "urls_override": engine.urls_override,
                "gvproxy_urls_override": engine.gvproxy_urls_override,
                "vfkit_urls_override": engine.vfkit_urls_override,
                "sha256_override": engine.sha256_override,
                "gvproxy_sha256_override": engine.gvproxy_sha256_override,
                "vfkit_sha256_override": engine.vfkit_sha256_override,
            }

    for name, config in registrations.items():
        podman_repo(
            name = name,
            version = config["version"],
            gvproxy_version = config["gvproxy_version"],
            vfkit_version = config["vfkit_version"],
            urls_override = config["urls_override"],
            gvproxy_urls_override = config["gvproxy_urls_override"],
            vfkit_urls_override = config["vfkit_urls_override"],
            sha256_override = config["sha256_override"],
            gvproxy_sha256_override = config["gvproxy_sha256_override"],
            vfkit_sha256_override = config["vfkit_sha256_override"],
        )

_podman_toolchain_tag = tag_class(
    attrs = {
        "name": attr.string(
            doc = "Name of the repository that will contain the Podman binary",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "Podman version for official URLs (macOS/Windows remote)",
            default = "v5.5.2",
        ),
        "gvproxy_version": attr.string(
            doc = "gvproxy version for official URLs (macOS/Windows remote)",
            default = "v0.7.3",
        ),
        "vfkit_version": attr.string(
            doc = "vfkit version for official URLs (macOS remote)",
            default = "v0.6.1",
        ),
        "urls_override": attr.string_dict(
            doc = "URL override per platform. Key: '<os>_<arch>' (e.g., 'linux_amd64')",
            default = {},
        ),
        "gvproxy_urls_override": attr.string_dict(
            doc = "URL override per platform for gvproxy. Key: '<os>_<arch>' (e.g., 'linux_amd64')",
            default = {},
        ),
        "vfkit_urls_override": attr.string_dict(
            doc = "URL override per platform for vfkit. Key: '<os>_<arch>' (e.g., 'darwin_amd64')",
            default = {},
        ),
        "sha256_override": attr.string_dict(
            doc = "SHA256 per platform for verification. Key: '<os>_<arch>'",
            default = {},
        ),
        "gvproxy_sha256_override": attr.string_dict(
            doc = "SHA256 per platform for verification of gvproxy. Key: '<os>_<arch>'",
            default = {},
        ),
        "vfkit_sha256_override": attr.string_dict(
            doc = "SHA256 per platform for verification of vfkit. Key: '<os>_<arch>'",
            default = {},
        ),
    },
)

podman = module_extension(
    implementation = _podman_ext_impl,
    tag_classes = {
        "toolchain": _podman_toolchain_tag,
    },
)