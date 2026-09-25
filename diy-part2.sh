#!/bin/bash

# 1. 修改后台默认登录 IP 为 192.168.6.1
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate

# 2. 强制指定 mediatek/filogic 平台内核版本为 6.12
sed -i 's/KERNEL_PATCHVER:=.*/KERNEL_PATCHVER:=6.12/g' target/linux/mediatek/Makefile

# 3. 注入 360T7 (filogic) 内核 BTF 与 eBPF 配置
echo "CONFIG_DEBUG_INFO=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_DEBUG_INFO_BTF=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_BPF=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_BPF_SYSCALL=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_NET_CLS_ACT=y" >> target/linux/mediatek/filogic/config-default
echo "CONFIG_NET_SCH_INGRESS=y" >> target/linux/mediatek/filogic/config-default

# 4. 仅拉取必须的 daed 源码（PassWall / MosDNS 官方自带，无需在此克隆）
git clone --depth=1 https://github.com/QiuSimons/luci-app-daed package/daed
