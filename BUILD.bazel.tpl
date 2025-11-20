load("@//tools/podman:wrapper.bzl", "podman_wrapper")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "runtime",
    srcs = glob(
        include = [
            "**/bin/podman*",
            "**/usr/bin/podman*",
            "**/usr/local/bin/podman*",
            "**/bin/*",
            "**/usr/bin/*",
            "**/usr/local/bin/*",
            "**/libexec/**/*",
        ],
        exclude = [
            "**/*.md",
            "**/*.txt",
            "**/*.1",
        ],
        allow_empty = True,
    ),
)

podman_wrapper(
    name = "podman",
    binary = ":runtime",
)

podman_wrapper(
    name = "gvproxy",
    binary = "gvproxy.bin",
)
{vfkit_wrapper}
sh_binary(
    name = "setup",
    srcs = ["podman_setup.sh"],
    data = [
        ":podman",
        ":gvproxy",{vfkit_data}
    ],
)
