#!/bin/bash

set -e

echo "============================================================"
echo "Starting diy-part2.sh"
echo "============================================================"

# ============================================================
# 1. Basic system settings
# ============================================================

echo "[1/8] Configure default LAN IP"

if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192\.168\.1\.1/192.168.6.1/g' \
        package/base-files/files/bin/config_generate
fi


# ============================================================
# 2. First boot custom settings
# ============================================================

echo "[2/8] Create first-boot custom settings"

mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/99-custom-settings <<'EOF'
#!/bin/sh

# ============================================================
# Default root password
# ============================================================

echo "root:password" | chpasswd

# ============================================================
# Enable SSH password authentication
# ============================================================

if uci show dropbear.@dropbear[0] >/dev/null 2>&1; then
    uci set dropbear.@dropbear[0].RootPasswordAuth='1'
    uci set dropbear.@dropbear[0].PasswordAuth='1'
    uci commit dropbear
fi

# ============================================================
# Enable Dropbear
# ============================================================

if [ -f /etc/init.d/dropbear ]; then
    /etc/init.d/dropbear enable
fi

# ============================================================
# Disable forced HTTPS redirect
# ============================================================

if uci show uhttpd.main >/dev/null 2>&1; then
    uci set uhttpd.main.redirect_https='0'
    uci commit uhttpd
fi

if [ -f /etc/init.d/uhttpd ]; then
    /etc/init.d/uhttpd enable
fi

# ============================================================
# ttyd
# ============================================================

if uci show ttyd.@ttyd[0] >/dev/null 2>&1; then
    uci set ttyd.@ttyd[0].command='/bin/login'
    uci commit ttyd
fi

# ============================================================
# Remove this script after first boot
# ============================================================

rm -f /etc/uci-defaults/99-custom-settings

exit 0
EOF

chmod +x \
    package/base-files/files/etc/uci-defaults/99-custom-settings


# ============================================================
# 3. eBPF / BTF kernel support
# ============================================================

echo "[3/8] Configure eBPF / BTF"

FILOGIC_CONFIG="target/linux/mediatek/filogic/config-default"

if [ ! -f "$FILOGIC_CONFIG" ]; then
    echo "ERROR: $FILOGIC_CONFIG does not exist."
    exit 1
fi

# Remove possible duplicate entries first.
sed -i \
    -e '/^CONFIG_DEBUG_INFO=y$/d' \
    -e '/^CONFIG_DEBUG_INFO_BTF=y$/d' \
    -e '/^CONFIG_DEBUG_INFO_DWARF4=y$/d' \
    -e '/^CONFIG_BPF=y$/d' \
    -e '/^CONFIG_BPF_SYSCALL=y$/d' \
    -e '/^CONFIG_NET_CLS_ACT=y$/d' \
    -e '/^CONFIG_NET_SCH_INGRESS=y$/d' \
    "$FILOGIC_CONFIG"

cat >> "$FILOGIC_CONFIG" <<'EOF'

# ============================================================
# Custom eBPF / BTF support for Daed
# ============================================================

CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
EOF


# ============================================================
# 4. Remove conflicting packages from official feeds
# ============================================================

echo "[4/8] Remove conflicting packages"

# sing-box
rm -rf \
    feeds/packages/net/sing-box \
    package/feeds/packages/sing-box

# xray
rm -rf \
    feeds/packages/net/xray-core \
    package/feeds/packages/xray-core

# v2ray geodata
rm -rf \
    feeds/packages/net/v2ray-geodata \
    package/feeds/packages/v2ray-geodata

# mosdns
rm -rf \
    feeds/packages/net/mosdns \
    package/feeds/packages/mosdns

# v2dat
rm -rf \
    feeds/packages/net/v2dat \
    package/feeds/packages/v2dat

# Remove possible feed package links.
rm -rf \
    package/feeds/packages/sing-box \
    package/feeds/packages/xray-core \
    package/feeds/packages/mosdns \
    package/feeds/packages/v2dat \
    package/feeds/packages/v2ray-geodata


# ============================================================
# 5. MosDNS v5
# ============================================================

echo "[5/8] Install MosDNS v5"

rm -rf package/mosdns

git clone \
    --depth 1 \
    --single-branch \
    --branch v5 \
    https://github.com/sbwml/luci-app-mosdns \
    package/mosdns

if [ ! -d package/mosdns ]; then
    echo "ERROR: Failed to clone luci-app-mosdns."
    exit 1
fi

if [ ! -f package/mosdns/Makefile ]; then
    echo "ERROR: package/mosdns/Makefile not found."
    exit 1
fi


# ============================================================
# 6. Daed
# ============================================================

echo "[6/8] Install Daed"

rm -rf package/daed

git clone \
    --depth 1 \
    --single-branch \
    https://github.com/QiuSimons/luci-app-daed \
    package/daed

if [ ! -d package/daed ]; then
    echo "ERROR: Failed to clone luci-app-daed."
    exit 1
fi


# ============================================================
# 7. PassWall + PassWall Packages
# ============================================================

echo "[7/8] Install PassWall"

rm -rf \
    package/passwall \
    package/passwall-packages

git clone \
    --depth 1 \
    --single-branch \
    https://github.com/xiaorouji/openwrt-passwall \
    package/passwall

git clone \
    --depth 1 \
    --single-branch \
    https://github.com/xiaorouji/openwrt-passwall-packages \
    package/passwall-packages

if [ ! -d package/passwall ]; then
    echo "ERROR: Failed to clone openwrt-passwall."
    exit 1
fi

if [ ! -d package/passwall-packages ]; then
    echo "ERROR: Failed to clone openwrt-passwall-packages."
    exit 1
fi

# PassWall packages may contain their own copies of packages
# which conflict with the dedicated MosDNS package.
rm -rf \
    package/passwall-packages/mosdns \
    package/passwall-packages/v2dat \
    package/passwall-packages/v2ray-geodata

# Make sure an old sing-box/xray package from another source
# cannot remain in the build tree.
rm -rf \
    package/passwall/sing-box \
    package/passwall/xray-core \
    package/passwall-packages/xray-core

# Keep PassWall's own sing-box package if it exists.
# It is intentionally NOT removed here.


# ============================================================
# 8. Final validation
# ============================================================

echo "[8/8] Validate package tree"

echo
echo "============================================================"
echo "Target:"
echo "============================================================"

grep '^CONFIG_TARGET_' .config 2>/dev/null || true

echo
echo "============================================================"
echo "PassWall:"
echo "============================================================"

find package/passwall \
    -maxdepth 2 \
    -type f \
    -name Makefile \
    -print 2>/dev/null || true

echo
echo "============================================================"
echo "PassWall Packages:"
echo "============================================================"

find package/passwall-packages \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print 2>/dev/null \
    | head -100 || true

echo
echo "============================================================"
echo "Daed:"
echo "============================================================"

find package/daed \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print 2>/dev/null || true

echo
echo "============================================================"
echo "MosDNS:"
echo "============================================================"

find package/mosdns \
    -maxdepth 3 \
    -type f \
    -name Makefile \
    -print 2>/dev/null || true

echo
echo "============================================================"
echo "eBPF / BTF:"
echo "============================================================"

grep -E \
    '^(CONFIG_DEBUG_INFO|CONFIG_DEBUG_INFO_BTF|CONFIG_DEBUG_INFO_DWARF4|CONFIG_BPF|CONFIG_BPF_SYSCALL|CONFIG_NET_CLS_ACT|CONFIG_NET_SCH_INGRESS)' \
    "$FILOGIC_CONFIG" \
    || true

echo
echo "============================================================"
echo "diy-part2.sh completed successfully."
echo "============================================================"
