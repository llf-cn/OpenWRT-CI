#!/bin/bash
# Packages.sh - 自定义软件包拉取与版本更新脚本

# 严格模式：任何命令失败或使用未定义变量时立即退出
set -euo pipefail

# 安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=${4:-}
	local PKG_LIST=("$PKG_NAME" ${5:-})  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo ""

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"
		local FOUND_DIRS=()
		mapfile -t FOUND_DIRS < <(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		if [ ${#FOUND_DIRS[@]} -gt 0 ]; then
			for DIR in "${FOUND_DIRS[@]}"; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done
		else
			echo "Not found directory: $NAME"
		fi
	done

	# git clone 失败时跳过该包，不中断整个编译流程（如仓库变私有或被删除）
	echo "Cloning: https://github.com/$PKG_REPO.git (branch: $PKG_BRANCH)"
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git" || {
		echo "WARNING: Failed to clone $PKG_REPO, skipping."
		return
	}

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find "./$REPO_NAME/"*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf "./$REPO_NAME/"
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f "$REPO_NAME" "$PKG_NAME"
	fi
}

UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
# 修复 luci-app-tailscale 与 tailscale 本体的文件冲突
rm -f ./luci-app-tailscale/root/etc/config/tailscale
rm -f ./luci-app-tailscale/root/etc/init.d/tailscale

UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# 更新软件包版本至 GitHub 最新 Release
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES
	PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO
		PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" "$PKG_FILE")
		local PKG_TAG
		PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" \
			| jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER OLD_URL OLD_FILE OLD_HASH
		OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL
		PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER
		NEW_VER=$(echo "$PKG_TAG" | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')

		local NEW_URL
		NEW_URL=$(echo "$PKG_URL" | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")

		local DOWNLOAD_CONTENT
		DOWNLOAD_CONTENT=$(curl -sL --fail "$NEW_URL" 2>/dev/null) || {
			echo "WARNING: Failed to download $NEW_URL, skipping $PKG_NAME update."
			continue
		}
		if [ -z "$DOWNLOAD_CONTENT" ]; then
			echo "WARNING: Downloaded content is empty for $NEW_URL, skipping $PKG_NAME update."
			continue
		fi
		local NEW_HASH
		NEW_HASH=$(echo "$DOWNLOAD_CONTENT" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

# UPDATE_VERSION "软件包名" "是否包含预发布版本（true/false，可选，默认 false）"
#UPDATE_VERSION "sing-box"
#UPDATE_VERSION "tailscale"
