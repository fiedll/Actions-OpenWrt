#!/bin/bash

# 1. 修改后台默认登录 IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 注入首开机自执行向导：强制固化密码为 password，并开启 Dropbear SSH 访问
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-custom-settings
#!/bin/sh
# 强制设定 root 密码为 password
echo "root:password" | chpasswd

# 确保 SSH 和 Web 守护进程允许正常登录
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci commit dropbear

/etc/init.d/dropbear enable
/etc/init.d/dropbear restart
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd restart
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-settings

# 3. 注入 MT7981 平台内核 BTF 与 eBPF 配置
echo "CONFIG_DEBUG_INFO=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_DEBUG_INFO_BTF=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_BPF=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_BPF_SYSCALL=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_NET_CLS_ACT=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_NET_SCH_INGRESS=y" >> target/linux/mediatek/filogic/config-default

# 4. 拉取 daed 源码仓库
rm -rf package/daed
git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/daed
