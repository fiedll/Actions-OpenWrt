#!/bin/bash

# 1. 修改后台默认登录 IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 强制设置默认密码为 password（使用单引号防转义，并使用匹配整行的稳健正则）
sed -i 's|^root:.*|root:$1$V4UetPzk$CY6rgitp3R5hkppTra52TW3:0:0:99999:7:::|' package/base-files/files/etc/shadow

# 3. 注入 MT7981 平台内核 BTF 与 eBPF 配置
echo "CONFIG_DEBUG_INFO=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_DEBUG_INFO_BTF=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_BPF=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_BPF_SYSCALL=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_NET_CLS_ACT=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_NET_SCH_INGRESS=y" >> target/linux/mediatek/filogic/config-default

# 4. 彻底清理后拉取 daed 源码仓库
rm -rf package/daed
git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/daed
