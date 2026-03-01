#!/bin/bash
# Handles.sh - 编译前资源预置与补丁脚本

# 严格模式：任何命令失败或使用未定义变量时立即退出
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# 预置 HomeProxy 规则数据
# 修复：原写法 [ -d *"homeproxy"* ] 中 glob 不在 [ ] 内展开，条件永远为假
# 改用 find 命令查找目录是否存在
if find . -maxdepth 1 -type d -iname "*homeproxy*" | grep -q .; then
	echo ""

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf "./$HP_PATH/resources/"*

	git clone -q --depth=1 --single-branch --branch "release" \
		"https://github.com/Loyalsoldier/surge-rules.git" "./$HP_RULE/" || {
		echo "ERROR: Failed to clone surge-rules, homeproxy resources will not be updated."
		exit 1
	}

	cd "./$HP_RULE/"
	RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo "$RES_VER" | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver

	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt
	sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} "../$HP_PATH/resources/"

	cd ..
	rm -rf "./$HP_RULE/"

	cd "$PKG_PATH"
	echo "homeproxy resources have been updated! (version: $RES_VER)"
fi

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
