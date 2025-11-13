#!/bin/bash
set -euo pipefail

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
Darwin)
  if [ "$ARCH" = "arm64" ]; then
    PLATFORM="macos_arm"
  else
    PLATFORM="macos"
  fi
  ;;
Linux)
  if [ "$ARCH" = "aarch64" ]; then
    PLATFORM="linux_arm"
  else
    PLATFORM="linux"
  fi
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

# Create ~/.local/bin if it doesn't exist
mkdir -p ~/.local/bin

# Download and extract the latest release
echo "Downloading latest release for $PLATFORM..."
DOWNLOAD_URL=$(curl -sS https://api.github.com/repos/neodejack/rr/releases/latest |
  grep "browser_download_url.*rr_${PLATFORM}.*tar.gz" |
  cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: Could not find release for platform $PLATFORM"
  exit 1
fi

TAR_FILE="rr_${PLATFORM}.tar.gz"
curl -sSL -o "$TAR_FILE" "$DOWNLOAD_URL"

# Extract and install the binary
echo "Extracting and installing to ~/.local/bin..."
tar -xzf "$TAR_FILE" -C ~/.local/bin
chmod +x ~/.local/bin/rr

# Clean up
echo "Cleaning up..."
rm "$TAR_FILE"

echo "✓ Installation complete! Binary installed to ~/.local/bin/rr"
echo "  Make sure ~/.local/bin is in your PATH"
