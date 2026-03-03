#!/bin/bash
# Handles.sh - 编译前资源预置与补丁脚本

# 严格模式：任何命令失败或使用未定义变量时立即退出
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# 修改 qca-nss-drv 启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo ""
	sed -i 's/START=.*/START=85/g' "$NSS_DRV"
	cd "$PKG_PATH"
	echo "qca-nss-drv start order has been fixed!"
fi

# 修改 qca-nss-pbuf 启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo ""
	sed -i 's/START=.*/START=86/g' "$NSS_PBUF"
	cd "$PKG_PATH"
	echo "qca-nss-pbuf start order has been fixed!"
fi
