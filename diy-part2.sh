#!/bin/bash

set -euo pipefail

echo "============================================================"
echo "Starting diy-part2.sh"
echo "============================================================"

# ============================================================
# 0. Upgrade Golang toolchain to 23.x (Fix mosdns / tailscale)
# ============================================================

echo "[0/8] Upgrading Golang toolchain to 23.x"
rm -rf feeds/packages/lang/golang
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 23.x feeds/packages/lang/golang


# ============================================================
# 1. Basic system settings
# ============================================================

echo "[1/8] Configure default LAN IP"

if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192\.168\.1\.1/192.168.6.1/g' package/base-files/files/bin/config_generate
fi


# ============================================================
# 2. First boot custom settings
# ============================================================

echo "[2/8] Create first-boot custom settings"

mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/99-custom-settings <<'EOF'
#!/bin/sh

true

if uci show dropbear.@dropbear[0] >/dev/null 2>&1; then
    uci set dropbear.@dropbear[0].RootPasswordAuth='1'
    uci set dropbear.@dropbear[0].PasswordAuth='1'
    uci commit dropbear
fi

if [ -f /etc/init.d/dropbear ]; then
    /etc/init.d/dropbear enable
fi

if uci show uhttpd.main >/dev/null 2>&1; then
    uci set uhttpd.main.redirect_https='0'
    uci commit uhttpd
fi

if [ -f /etc/apk/repositories.d/distfeeds.list ]; then
    sed -i '\#/video/packages\.adb#d' /etc/apk/repositories.d/distfeeds.list
fi

if [ -f /etc/init.d/uhttpd ]; then
    /etc/init.d/uhttpd enable
fi

if uci show ttyd.@ttyd[0] >/dev/null 2>&1; then
    uci set ttyd.@ttyd[0].command='/bin/login'
    uci commit ttyd
fi

rm -f /etc/uci-defaults/99-custom-settings

exit 0
EOF

chmod +x package/base-files/files/etc/uci-defaults/99-custom-settings


# ============================================================
# 3. eBPF / BTF kernel support & Host Toolchain
# ============================================================

echo "[3/8] Configure eBPF / BTF"

FILOGIC_CONFIG="$(find target/linux/mediatek/filogic -maxdepth 1 -type f -name 'config-*' | sort -V | tail -n 1 || true)"

if [ -n "$FILOGIC_CONFIG" ] && [ -f "$FILOGIC_CONFIG" ]; then
    echo "Using Filogic kernel config: $FILOGIC_CONFIG"
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
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
EOF
fi

# Authorize host clang toolchain to eliminate /invalid/clang error
if [ -f ".config" ]; then
    sed -i '/CONFIG_BPF_TOOLCHAIN_/d' .config || true
    echo "CONFIG_DEVEL=y" >> .config
    echo "CONFIG_BPF_TOOLCHAIN_HOST=y" >> .config
    echo 'CONFIG_BPF_TOOLCHAIN_HOST_PATH="/usr/bin"' >> .config
fi


# ============================================================
# 4. Remove conflicting packages from official feeds
# ============================================================

echo "[4/8] Remove conflicting packages"

rm -rf \
    feeds/packages/net/sing-box \
    package/feeds/packages/sing-box \
    feeds/packages/net/mosdns \
    package/feeds/packages/mosdns \
    feeds/packages/net/v2dat \
    package/feeds/packages/v2dat \
    feeds/packages/net/daed \
    package/feeds/packages/daed \
    feeds/packages/net/geoview \
    package/feeds/packages/geoview \
    package/feeds/packages/v2ray-geodata \
    feeds/packages/net/dae \
    package/feeds/base/dae \
    package/feeds/packages/dae


# ============================================================
# 5. MosDNS v5
# ============================================================

echo "[5/8] Install MosDNS v5"

rm -rf package/mosdns package/luci-app-mosdns /tmp/luci-app-mosdns

git clone \
    --depth 1 \
    --single-branch \
    --branch v5 \
    https://github.com/sbwml/luci-app-mosdns \
    /tmp/luci-app-mosdns

mkdir -p package/mosdns package/luci-app-mosdns package/geo2txt
cp -a /tmp/luci-app-mosdns/mosdns/. package/mosdns/
cp -a /tmp/luci-app-mosdns/luci-app-mosdns/. package/luci-app-mosdns/
if [ -d /tmp/luci-app-mosdns/geo2txt ]; then
    cp -a /tmp/luci-app-mosdns/geo2txt/. package/geo2txt/
fi
rm -rf /tmp/luci-app-mosdns

rm -rf package/v2ray-geodata
git clone --depth 1 --single-branch https://github.com/sbwml/v2ray-geodata package/v2ray-geodata


# ============================================================
# 6. Daed
# ============================================================

echo "[6/8] Install Daed"

rm -rf package/daed
git clone --depth 1 https://github.com/QiuSimons/luci-app-daed package/daed

DAED_MAKEFILE="package/daed/daed/Makefile"
if [ -f "$DAED_MAKEFILE" ]; then
    # 完全剔除过时的独立 vmlinux-btf 依赖，使用内核集成 BTF
    sed -i 's/+DAED_USE_VMLINUX_BTF:vmlinux-btf//g' "$DAED_MAKEFILE"
    sed -i 's/+PACKAGE_daed_DAED_USE_VMLINUX_BTF:vmlinux-btf//g' "$DAED_MAKEFILE"
fi


# ============================================================
# 7. PassWall + PassWall Packages
# ============================================================

echo "[7/8] Install PassWall"

rm -rf package/passwall package/passwall-packages

git clone --depth 1 --single-branch https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall
git clone --depth 1 --single-branch https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

# Remove duplicates conflicting with MosDNS
rm -rf \
    package/passwall-packages/mosdns \
    package/passwall-packages/v2dat \
    package/passwall/sing-box \
    package/passwall/xray-core


# ============================================================
# 8. Final validation
# ============================================================

echo "[8/8] Validate package tree"

echo "============================================================"
echo "Target:"
grep '^CONFIG_TARGET_' .config 2>/dev/null || true

echo "============================================================"
echo "Daed BTF verification:"
if [ -f "$DAED_MAKEFILE" ] && grep -Eq '\\+DAED_USE_VMLINUX_BTF:vmlinux-btf|\\+PACKAGE_daed_DAED_USE_VMLINUX_BTF:vmlinux-btf' "$DAED_MAKEFILE"; then
    echo "ERROR: Daed still has the unavailable vmlinux-btf package dependency."
    exit 1
fi
echo "OK: Daed BTF Kconfig choice is preserved and the unavailable vmlinux-btf package dependency is removed."

echo "============================================================"
echo "Package dependency validation:"
echo "  v2ray-geodata: $(test -f package/v2ray-geodata/Makefile && echo OK || echo MISSING)"
echo "  xray-core:     $(test -f package/passwall-packages/xray-core/Makefile && echo OK || echo MISSING)"
echo "  geo2txt:       $(test -f package/geo2txt/Makefile && echo OK || echo MISSING)"

echo "============================================================"
echo "diy-part2.sh completed successfully."
echo "============================================================"
