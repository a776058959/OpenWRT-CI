#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#===================================================================
# 预置北京大学 ImmortalWrt APK 镜像源
#===================================================================
mkdir -p ./files/etc/apk
cat > ./files/etc/apk/repositories <<'EOF'
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/%A/base
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/%A/luci
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/%A/packages
https://mirrors.pku.edu.cn/immortalwrt/snapshots/packages/%A/routing
https://mirrors.pku.edu.cn/immortalwrt/snapshots/targets/%T/%t/packages
EOF
#===================================================================

#预置HomeProxy数据（若不再使用 homeproxy 则自动跳过）
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

#修改argon主题字体和颜色（若未使用则自动跳过）
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样（若未使用则自动跳过）
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#===================================================================
# 自定义 alpha 主题：视频背景 + 大字体
#===================================================================
if [ -d *"luci-theme-alpha"* ]; then
	echo " " && cd ./luci-theme-alpha/

	# 1. 复制视频文件到固件
	if [ -d "$GITHUB_WORKSPACE/custom/alpha/video" ]; then
		mkdir -p ./files/www/luci-static/alpha/background/video
		cp $GITHUB_WORKSPACE/custom/alpha/video/*.mp4 ./files/www/luci-static/alpha/background/video/
		echo "Custom videos copied!"
	fi

	# 2. 修改登录页模板 sysauth.htm
	SYSAUTH_HTM="./templates/alpha/sysauth.htm"
	if [ -f "$SYSAUTH_HTM" ]; then
		# 去掉 body 上的内联背景图
		sed -i 's/style="background-image:url.*)"/style=""/g' "$SYSAUTH_HTM"
		# 在 <body> 标签后插入登录视频（播放一次后定格）
		sed -i '/<body.*>/a\
<video id="bg-video" autoplay muted playsinline onended="this.pause()">\
  <source src="/luci-static/alpha/background/video/bg_login.mp4" type="video/mp4">\
</video>' "$SYSAUTH_HTM"
		echo "Login video injected into sysauth.htm!"
	fi

	# 3. 修改后台头部模板 header.htm
	HEADER_HTM="./templates/alpha/header.htm"
	if [ -f "$HEADER_HTM" ]; then
		# 在 <body> 标签后插入后台视频（循环播放）
		sed -i '/<body.*>/a\
<video id="bg-video" autoplay muted loop playsinline>\
  <source src="/luci-static/alpha/background/video/bg_main.mp4" type="video/mp4">\
</video>' "$HEADER_HTM"
		echo "Main video injected into header.htm!"
	fi

	# 4. 追加 CSS：视频全屏背景 + 大字体
	cat >> ./htdocs/luci-static/alpha/style/style.css <<'EOF'

/* 视频背景通用设置 */
#bg-video {
    position: fixed;
    right: 0;
    bottom: 0;
    min-width: 100%;
    min-height: 100%;
    width: auto;
    height: auto;
    z-index: -1;
    object-fit: cover;
}

/* 强制清除 body 背景图，确保视频可见 */
body {
    background-image: none !important;
    background-color: transparent !important;
}

/* 增大内容区域字体 */
#maincontent .container {
    font-size: 15px;
}
EOF
	echo "Alpha theme styles applied!"

	cd $PKG_PATH && echo "theme-alpha fully customized!"
fi
#===================================================================

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

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