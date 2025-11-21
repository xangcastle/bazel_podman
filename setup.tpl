#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "======================"
echo "====== 🐳 Podman ======"
echo "======================"
echo ""

OS="$(uname -s)"
case "$OS" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="macos";;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows";;
    *)          PLATFORM="unknown";;
esac

mkdir -p ~/.config/containers
echo "1️⃣  Config directory created ~/.config/containers"

cat > ~/.config/containers/containers.conf << 'CONF_EOF'
[engine]
helper_binaries_dir=["{helper_dir}"]
CONF_EOF
echo "2️⃣  Helper binaries location configs written to ~/.config/containers/containers.conf"

cat > ~/.config/containers/registries.conf << 'REG_EOF'
# Docker Hub configuration
unqualified-search-registries = ["docker.io"]

[[registry]]
location = "docker.io"
REG_EOF
echo "3️⃣  Container registries configs written to ~/.config/containers/registries.conf"

echo ""
echo "✨ Configuration complete!"
echo ""

if [ "$PLATFORM" = "linux" ]; then
    echo "🐧 Platform: Linux"
    echo ""
    echo "✅ On Linux, Podman runs natively (no machine setup needed)!"
    echo ""
    echo "🚀 Next steps:"
    echo ""
    echo "  1️⃣  Use Podman directly:"
    echo "      bazel run @podman//:podman -- <command>"
    echo ""
    echo "  💡 Or with bazel_env:"
    echo "      bazel run //:bazel_env"
    echo "      podman <command>"
else
    echo "🍎 Platform: $PLATFORM"
    echo ""
    echo "🚀 Next steps:"
    echo ""
    echo "  1️⃣  Initialize the machine (first time only):"
    echo "      bazel run @podman//:podman -- machine init"
    echo ""
    echo "  2️⃣  Start the machine:"
    echo "      bazel run @podman//:podman -- machine start"
    echo ""
    echo "  3️⃣  Use Podman with bazel:"
    echo "      bazel run @podman//:podman -- <command>"
    echo ""
    echo "  💡 Or finish setup by running:"
    echo "      bazel run //:bazel_env"
    echo ""
    echo "      Then you can use podman directly"
    echo "      podman <command>"
fi
echo ""
