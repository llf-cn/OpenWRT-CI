#!/bin/bash
# Settings.sh - 编译前自定义配置注入脚本

# 严格模式：任何命令失败或使用未定义变量时立即退出
set -euo pipefail

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

#预置UCI默认配置（固件首次启动时自动执行一次）
UCI_DEFAULTS="./package/base-files/files/etc/uci-defaults/99-luci-defaults"
mkdir -p "$(dirname "$UCI_DEFAULTS")"
cat > "$UCI_DEFAULTS" << 'EOF'
#!/bin/sh
# 预置 LuCI 默认语言为简体中文
uci set luci.main.lang='zh_cn'
# 删除 Aurora 主题条目（未安装，避免用户误选）
uci delete luci.themes.Aurora 2>/dev/null
uci commit luci
exit 0
EOF
echo "uci-defaults script has been created!"

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config

#手动调整的插件
if [ -n "${WRT_PACKAGE:-}" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#开启sqm-nss插件
	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
	else
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	fi
	#AX18无WiFi，直接启用nowifi DTS以优化Q6内存分配
	if [ -d "$DTS_PATH" ]; then
		find "$DTS_PATH" -type f ! -iname '*nowifi*' \
			-exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	else
		echo "WARNING: DTS path not found: $DTS_PATH"
	fi
	# 已删除：kmod-usb-serial-qualcomm（不需要 USB 4G 模块）
fi
