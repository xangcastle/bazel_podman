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

echo "1️⃣  Creating config directory..."
mkdir -p ~/.config/containers

echo "2️⃣  Configuring helper binaries location..."
cat > ~/.config/containers/containers.conf << 'CONF_EOF'
[engine]
helper_binaries_dir=["{helper_dir}"]
CONF_EOF

echo "   Config written to ~/.config/containers/containers.conf"
echo ""

echo "3️⃣  Configuring container registries..."
cat > ~/.config/containers/registries.conf << 'REG_EOF'
# GitHub Container Registry configuration
unqualified-search-registries = ["ghcr.io"]

[[registry]]
location = "ghcr.io"
REG_EOF

echo "   Config written to ~/.config/containers/registries.conf"
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
    echo "  2️⃣  Login to GitHub Container Registry:"
    echo "      echo \$GITHUB_TOKEN | bazel run @podman//:podman -- login ghcr.io -u username --password-stdin"
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
    echo "  3️⃣  Use Podman directly:"
    echo "      bazel run @podman//:podman -- <command>"
    echo ""
    echo "  4️⃣  Login to GitHub Container Registry:"
    echo "      echo \$GITHUB_TOKEN | bazel run @podman//:podman -- login ghcr.io -u username --password-stdin"
    echo ""
    echo "  💡 Or use bazel_env for easier access:"
    echo "      bazel run //:bazel_env"
    echo "      podman <command>"
fi
echo ""
