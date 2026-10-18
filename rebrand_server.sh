#!/bin/bash
# ==============================================================================
# HostPro Cloud - 1-Command Server Rebranding & Update Script
# 
# Rebrands an existing PegaProx server into HostPro Cloud in-place without
# touching your existing cluster configurations, databases, or API tokens.
#
# Usage (run as root on your server):
#   curl -sSL https://raw.githubusercontent.com/hostprolimited/HostProCloud/main/rebrand_server.sh | sudo bash
# ==============================================================================

set -e

# Styling
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          HostPro Cloud - In-Place Server Rebranding        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Error: This script must be run as root.${NC}"
    echo "  Please run with: sudo bash $0"
    exit 1
fi

# Locate existing installation
TARGET_DIR=""
for dir in "/opt/PegaProx" "/opt/pegaprox" "/opt/HostProCloud" "/var/lib/pegaprox" "$(pwd)"; do
    if [ -f "$dir/pegaprox_multi_cluster.py" ] || [ -d "$dir/pegaprox" ]; then
        TARGET_DIR="$dir"
        break
    fi
done

if [ -z "$TARGET_DIR" ]; then
    echo -e "${RED}✗ Error: Could not locate existing PegaProx installation directory.${NC}"
    echo "  Please cd into your installation directory and run this script."
    exit 1
fi

echo -e "Found installation directory: ${GREEN}${TARGET_DIR}${NC}"

# Detect ownership
OWNER=$(stat -c '%U:%G' "$TARGET_DIR" 2>/dev/null || echo "pegaprox:pegaprox")

# Temporary workspace
TMP_DIR=$(mktemp -d /tmp/hostpro-rebrand-XXXXXX)
ARCHIVE_URL="https://github.com/hostprolimited/HostProCloud/archive/refs/heads/main.tar.gz"

echo -e "Downloading HostPro Cloud assets from ${BLUE}${ARCHIVE_URL}${NC}..."
curl -sSL -o "$TMP_DIR/hostpro.tar.gz" "$ARCHIVE_URL"

echo "Extracting updated files..."
tar -xzf "$TMP_DIR/hostpro.tar.gz" -C "$TMP_DIR"
EXTRACTED_DIR=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}✗ Failed to extract archive.${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "Deploying HostPro Cloud UI, logos, and server updates..."
# Sync web, images, pegaprox python package, and launcher while preserving config/
cp -r "$EXTRACTED_DIR/web" "$TARGET_DIR/"
cp -r "$EXTRACTED_DIR/images" "$TARGET_DIR/"
cp -r "$EXTRACTED_DIR/pegaprox" "$TARGET_DIR/"
cp "$EXTRACTED_DIR/pegaprox_multi_cluster.py" "$TARGET_DIR/"
cp "$EXTRACTED_DIR/version.json" "$TARGET_DIR/" 2>/dev/null || true
cp "$EXTRACTED_DIR/systemd/hostpro.service" /etc/systemd/system/ 2>/dev/null || true

# Restore file permissions
chown -R "$OWNER" "$TARGET_DIR/web" "$TARGET_DIR/images" "$TARGET_DIR/pegaprox" "$TARGET_DIR/pegaprox_multi_cluster.py" 2>/dev/null || true

# Clean up temp
rm -rf "$TMP_DIR"

# Restart systemd service
echo "Reloading and restarting service..."
systemctl daemon-reload 2>/dev/null || true

if systemctl is-active --quiet pegaprox 2>/dev/null || systemctl is-enabled --quiet pegaprox 2>/dev/null; then
    systemctl restart pegaprox
    echo -e "${GREEN}✓ Successfully restarted pegaprox service!${NC}"
elif systemctl is-active --quiet hostpro 2>/dev/null || systemctl is-enabled --quiet hostpro 2>/dev/null; then
    systemctl restart hostpro
    echo -e "${GREEN}✓ Successfully restarted hostpro service!${NC}"
else
    echo -e "${YELLOW}Notice: No active systemd service found. Please restart your python process or docker container.${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Server Rebrand Complete! Enjoy HostPro Cloud!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
