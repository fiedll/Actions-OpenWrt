#!/bin/bash

# 修改默认IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 首次启动脚本
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-settings <<'EOF'
#!/bin/sh
echo "root:password" | chpasswd
uci set dropbear.@dropbear[0].RootPasswordAuth='1'
uci set dropbear.@dropbear[0].PasswordAuth='1'
uci commit dropbear

[ -f /etc/init.d/dropbear ] && {
    /etc/init.d/dropbear enable
    /etc/init.d/dropbear restart
}

[ -f /etc/init.d/uhttpd ] && {
    /etc/init.d/uhttpd enable
    /etc/init.d/uhttpd restart
}

exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-settings

# eBPF
cat >> target/linux/mediatek/filogic/config-default <<EOF
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
EOF

# daed
rm -rf package/daed
git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/daed
