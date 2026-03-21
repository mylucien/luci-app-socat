# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2024 OpenWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-socat
PKG_VERSION:=1.0.4
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

LUCI_TITLE:=LuCI support for Socat
LUCI_DESCRIPTION:=Provides a web interface for configuring Socat (SOcket CAT) relay rules.
LUCI_DEPENDS:=+socat +rpcd +rpcd-mod-rpcsys

include $(TOPDIR)/feeds/luci/luci.mk

# ── 说明 ─────────────────────────────────────────────────────────────
# luci.mk 的 default_postinst/prerm 根据 PKG_NAME="luci-app-socat" 推导
# 服务名 "socat"，执行 chmod/enable/disable /etc/init.d/socat（官方 socat
# 包的文件，权限 644），导致 Permission denied。该行为无法通过 Makefile
# 的 define 覆盖，因为 luci.mk 在 BuildPackage 展开阶段固化了 postinst。
#
# 应对策略：
# 1. postinst/prerm 的报错是非致命的，文件已正确安装。
# 2. /etc/config/socat 不放在 root/ 目录下，luci.mk 的 install 自然不会
#    打包它，彻底消除 conffile 冲突警告。首次安装由 uci-defaults 创建配置。
# 3. 所有初始化（chmod、enable、rpcd restart、清缓存）在 uci-defaults 里
#    完成，由 postinst 触发或开机时由 procd 自动执行。
# ─────────────────────────────────────────────────────────────────────

# call BuildPackage - OpenWrt buildroot signature
$(eval $(call BuildPackage,luci-app-socat))
