-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2024 OpenWrt.org

local m, s, o
local pcdata = luci.xml and luci.xml.pcdata or luci.util.pcdata


m = Map("socat", translate("Socat 端口转发"),
	translate("Socat（SOcket CAT）是一个多功能的网络工具，可在两个数据流之间建立双向通道，支持 TCP、UDP、Unix Socket 等多种协议的转发与代理。"))

-- 保存后自动重载服务，新规则立即生效，无需手动点重启
m.on_after_commit = function()
	luci.sys.call("/etc/init.d/socat-luci reload 2>/dev/null")
end

-- 状态卡 + 统计卡（顶部）
m:section(SimpleSection).template = "socat/socat_status"

-- ==============================
-- 全局设置
-- ==============================
s = m:section(TypedSection, "global", translate("全局设置"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enable", translate("启用 Socat"), translate("开启或关闭所有 Socat 转发规则"))
o.rmempty = false
o.default = "1"

-- ==============================
-- 转发规则列表（支持拖拽排序）
-- ==============================
s = m:section(TypedSection, "socat", translate("转发规则"))
s.anonymous  = false
s.addremove  = true
s.sortable   = true   -- LuCI 内置排序（上下箭头）；拖拽由 JS 额外实现
s.template   = "cbi/tblsection"
s.extedit    = luci.dispatcher.build_url("admin/services/socat/edit/%s")
s.add_title    = translate("添加规则")
s.remove_title = translate("删除规则")

-- 拖拽排序句柄列
o = s:option(DummyValue, "_drag", "")
o.rawhtml = true
o.cfgvalue = function(self, section)
	return '<span class="socat-drag-handle" title="拖拽排序" data-section="' .. section .. '">⠿</span>'
end

-- 规则名称
o = s:option(DummyValue, "_name", translate("规则名称"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	local name    = self.map:get(section, "name") or section
	local comment = self.map:get(section, "comment") or ""
	local out = string.format('<strong>%s</strong>', pcdata(name))
	if comment ~= "" then
		out = out .. string.format('<br><small style="color:#888">%s</small>', pcdata(comment))
	end
	return out
end

-- 协议徽章
o = s:option(DummyValue, "_proto", translate("协议"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	local proto = self.map:get(section, "src_proto") or "tcp"
	local colors = {
		tcp="2563eb", tcp4="2563eb", tcp6="2563eb",
		udp="d97706", udp4="d97706", udp6="d97706",
		multicast="7c3aed",
		openssl="059669",
		unix="64748b",
	}
	local c = colors[proto] or "64748b"
	local label = proto == "multicast" and "MCAST" or proto:upper()
	return string.format(
		'<span style="background:#%s;color:#fff;padding:2px 7px;border-radius:3px;font-size:11px;font-weight:500">%s</span>',
		c, label)
end

-- 监听
o = s:option(DummyValue, "_src", translate("监听"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	local proto = self.map:get(section, "src_proto") or "tcp"
	local addr  = self.map:get(section, "src_addr") or ""
	local port  = self.map:get(section, "src_port") or ""
	if proto == "unix" then
		return '<code style="font-size:11px">' .. pcdata(self.map:get(section, "src_unix_path") or "") .. '</code>'
	end
	if proto == "multicast" then
		local mc_group = self.map:get(section, "mc_src_group") or "*"
		local mc_port  = self.map:get(section, "mc_port") or ""
		return '<code style="font-size:12px">' .. mc_group .. ":" .. mc_port .. '</code>'
	end
	local display = (addr ~= "" and addr or "0.0.0.0") .. ":" .. port
	return '<code style="font-size:12px">' .. display .. '</code>'
end

-- 目标
o = s:option(DummyValue, "_dst", translate("目标"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	local dst_proto = self.map:get(section, "dst_proto") or "tcp"
	if dst_proto == "unix" then
		return '<code style="font-size:11px">' .. pcdata(self.map:get(section, "dst_unix_path") or "") .. '</code>'
	end
	if dst_proto == "multicast" then
		local g = self.map:get(section, "mc_dst_group") or ""
		local p = self.map:get(section, "mc_dst_port")  or ""
		return '<code style="font-size:12px">' .. g .. ":" .. p .. '</code>'
	end
	local addr = self.map:get(section, "dst_addr") or ""
	local port = self.map:get(section, "dst_port") or ""
	return '<code style="font-size:12px">' .. addr .. ":" .. port .. '</code>'
end

-- 连接数（JS 动态填入）
o = s:option(DummyValue, "_conns", translate("连接数"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	return string.format('<span id="conns_%s" class="socat-conns">—</span>', section)
end

-- 状态（JS 动态填入）
o = s:option(DummyValue, "_status", translate("状态"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	return string.format('<span id="status_%s" class="socat-status-badge">…</span>', section)
end

-- 操作按钮（日志查看）
o = s:option(DummyValue, "_actions", translate("日志"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	-- 用单引号包裹 section 名，避免与 onclick="" 的双引号冲突
	-- section 名只含字母/数字/下划线，无需转义
	return string.format(
		'<button type="button" class="btn cbi-button" onclick="socatShowLog(\'%s\')" style="font-size:11px;padding:2px 8px">查看日志</button>',
		section)
end

-- 启用开关
o = s:option(Flag, "enable", translate("启用"))
o.rmempty = false
o.default = "1"

return m
