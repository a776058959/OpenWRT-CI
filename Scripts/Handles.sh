#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#===================================================================
# 预置北京大学 ImmortalWrt APK 镜像源（动态架构）
#===================================================================
CONFIG_FILE="$GITHUB_WORKSPACE/wrt/.config"
ARCH=$(sed -n 's/^CONFIG_TARGET_SUFFIX="\(.*\)"/\1/p' "$CONFIG_FILE")
[ -z "$ARCH" ] && ARCH=$(sed -n 's/^CONFIG_CPU_TYPE="\(.*\)"/\1/p' "$CONFIG_FILE")
BOARD=$(sed -n 's/^CONFIG_TARGET_BOARD="\(.*\)"/\1/p' "$CONFIG_FILE")
SUBTARGET=$(sed -n 's/^CONFIG_TARGET_SUBTARGET="\(.*\)"/\1/p' "$CONFIG_FILE")
TARGET="${BOARD}/${SUBTARGET}"
[ -z "$ARCH" ] && ARCH="aarch64_cortex-a53"
[ -z "$BOARD" ] || [ -z "$SUBTARGET" ] && TARGET="qualcommax/ipq60xx"

mkdir -p $GITHUB_WORKSPACE/wrt/files/etc/apk
cat > $GITHUB_WORKSPACE/wrt/files/etc/apk/repositories <<EOF
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/${ARCH}/base/packages.adb
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/${ARCH}/luci/packages.adb
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/${ARCH}/packages/packages.adb
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/${ARCH}/routing/packages.adb
https://mirrors.pku.edu.cn/immortalwrt/snapshots/targets/${TARGET}/packages/packages.adb
EOF

# 写入注释内容，避免空文件导致 LuCI 报错
mkdir -p $GITHUB_WORKSPACE/wrt/files/etc/apk/repositories.d
cat > $GITHUB_WORKSPACE/wrt/files/etc/apk/repositories.d/distfeeds.list <<'EOF'
# This file is auto-generated and build-specific, any changes will be intentionally lost in sysupgrade.
# Add your custom feeds to /etc/apk/repositories.d/customfeeds.list
EOF
#===================================================================

#预置HomeProxy数据（若不用则自动跳过）
if [ -d *"homeproxy"* ]; then
	echo " "
	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"
	rm -rf ./$HP_PATH/resources/*
	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")
	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/
	cd .. && rm -rf ./$HP_RULE/
	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改aurora菜单式样（保留）
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/
	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")
	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#===================================================================
# 自定义 Argon 主题：视频背景 + 移除循环
#===================================================================
ARGON_DIR=$(find $GITHUB_WORKSPACE/wrt -maxdepth 4 -type d -iname "luci-theme-argon" | head -1)
if [ -n "$ARGON_DIR" ]; then
	echo "Found argon theme at: $ARGON_DIR"

	# 1. 复制视频文件
	if [ -d "$GITHUB_WORKSPACE/custom/argon/video" ]; then
		mkdir -p $GITHUB_WORKSPACE/wrt/files/www/luci-static/argon/background
		cp $GITHUB_WORKSPACE/custom/argon/video/*.mp4 $GITHUB_WORKSPACE/wrt/files/www/luci-static/argon/background/
		echo "Argon videos copied!"
	fi

	# 2. 生成 argon 配置文件，设定视频背景（使用 video_url）
	mkdir -p $GITHUB_WORKSPACE/wrt/files/etc/config
	cat > $GITHUB_WORKSPACE/wrt/files/etc/config/argon <<'ARGONEOF'
config argon
	option primary '#31a1a1'
	option blur '0.5'
	option background 'video'
	option video_url '/luci-static/argon/background/bg_main.mp4'
	option dark_mode 'auto'
ARGONEOF
	echo "Argon video config generated!"

	# 3. 修改源码模板：移除视频 loop 属性，登录页播放一次后定格
	find "$ARGON_DIR" -type f \( -name "*.htm" -o -name "*.uc" \) -exec sed -i 's/autoplay loop muted/autoplay muted onended="this.pause()"/g' {} \;
	echo "Argon video loop removed in source templates!"
else
	echo "Warning: luci-theme-argon directory not found!"
fi
#===================================================================

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "
	sed -i '/\/files/d' $TS_FILE
	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "
	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE
	cd $PKG_PATH && echo "rust has been fixed!"
fi