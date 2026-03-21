-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2024 OpenWrt.org

local m, s, o
local sys = require "luci.sys"
local sid = arg[1]
if not sid or sid == "" then
	luci.http.redirect(luci.dispatcher.build_url("admin/services/socat"))
	return
end

m = Map("socat", translate("编辑转发规则"))
m.redirect = luci.dispatcher.build_url("admin/services/socat")

m.on_after_commit = function()
	sys.call("/etc/init.d/socat-luci reload 2>/dev/null")
end

s = m:section(NamedSection, sid, "socat")
s.anonymous = false
s.addremove = false

-- ==============================
-- 基本信息
-- ==============================
o = s:option(Flag, "enable", translate("启用此规则"))
o.rmempty = false
o.default = "1"

o = s:option(Value, "name", translate("规则名称"), translate("用于标识此转发规则的名称，支持中文"))
o.rmempty = false
o.placeholder = "例如：内网穿透-SSH"

o = s:option(Value, "comment", translate("备注说明"), translate("可选，填写此规则的用途说明"))
o.rmempty = true
o.placeholder = "可选备注"

-- ==============================
-- 监听端（源）
-- ==============================
s:tab("source", translate("监听端配置"))

o = s:taboption("source", ListValue, "src_proto", translate("监听协议"))
o.default = "tcp"
o:value("tcp",       "TCP")
o:value("tcp4",      "TCP（仅 IPv4）")
o:value("tcp6",      "TCP（仅 IPv6）")
o:value("udp",       "UDP")
o:value("udp4",      "UDP（仅 IPv4）")
o:value("udp6",      "UDP（仅 IPv6）")
o:value("multicast", "UDP 组播接收（Multicast）")
o:value("unix",      "Unix Socket")
o:value("openssl",   "TLS/SSL")

o = s:taboption("source", Value, "src_addr", translate("监听地址"),
	translate("留空表示监听所有接口（0.0.0.0），也可指定 IP，如 192.168.1.1"))
o.placeholder = "留空 = 所有接口"
o.rmempty = true
o:depends({src_proto = "tcp"})
o:depends({src_proto = "tcp4"})
o:depends({src_proto = "tcp6"})
o:depends({src_proto = "udp"})
o:depends({src_proto = "udp4"})
o:depends({src_proto = "udp6"})
o:depends({src_proto = "openssl"})

o = s:taboption("source", Value, "src_unix_path", translate("Unix Socket 路径"),
	translate("Unix Socket 文件路径，如 /var/run/socat.sock"))
o.placeholder = "/var/run/socat.sock"
o.rmempty = true
o:depends("src_proto", "unix")

o = s:taboption("source", Value, "src_port", translate("监听端口"),
	translate("填写 1-65535 范围内的端口号"))
o.datatype = "port"
o.placeholder = "例如：8080"
o.rmempty = true
o:depends({src_proto = "tcp"})
o:depends({src_proto = "tcp4"})
o:depends({src_proto = "tcp6"})
o:depends({src_proto = "udp"})
o:depends({src_proto = "udp4"})
o:depends({src_proto = "udp6"})
o:depends({src_proto = "openssl"})

o = s:taboption("source", Value, "mc_port", translate("组播端口"),
	translate("发送端向本机该端口发送组播包，通常与发送端的目标端口一致，如 5000"))
o.datatype = "port"
o.placeholder = "例如：5000"
o.rmempty = true
o:depends("src_proto", "multicast")

o = s:taboption("source", Value, "backlog", translate("连接队列长度"),
	translate("TCP 连接队列最大长度，默认 5"))
o.datatype = "uinteger"
o.placeholder = "5"
o.default = "5"
o.rmempty = true
o:depends({src_proto = "tcp"})
o:depends({src_proto = "tcp4"})
o:depends({src_proto = "tcp6"})
o:depends({src_proto = "openssl"})

-- ==============================
-- 目标端（目的地）
-- ==============================
s:tab("dest", translate("目标端配置"))

o = s:taboption("dest", ListValue, "dst_proto", translate("目标协议"))
o.default = "tcp"
o:value("tcp",       "TCP（单播）")
o:value("tcp4",      "TCP（仅 IPv4）")
o:value("tcp6",      "TCP（仅 IPv6）")
o:value("udp",       "UDP（单播）")
o:value("udp4",      "UDP（仅 IPv4，单播）")
o:value("udp6",      "UDP（仅 IPv6，单播）")
o:value("multicast", "UDP 组播发送（Multicast）")
o:value("unix",      "Unix Socket")
o:value("openssl",   "TLS/SSL")
-- 组播转单播时也需要选择目标协议
o:depends({src_proto = "multicast"})
o:depends({src_proto = "tcp"})
o:depends({src_proto = "tcp4"})
o:depends({src_proto = "tcp6"})
o:depends({src_proto = "udp"})
o:depends({src_proto = "udp4"})
o:depends({src_proto = "udp6"})
o:depends({src_proto = "openssl"})
o:depends({src_proto = "unix"})

o = s:taboption("dest", Value, "dst_addr", translate("目标地址"),
	translate("转发目标的 IP 地址或域名"))
o.placeholder = "例如：192.168.1.100 或 example.com"
o.rmempty = true
o:depends({dst_proto = "tcp"})
o:depends({dst_proto = "tcp4"})
o:depends({dst_proto = "tcp6"})
o:depends({dst_proto = "udp"})
o:depends({dst_proto = "udp4"})
o:depends({dst_proto = "udp6"})
o:depends({dst_proto = "openssl"})
-- 组播转单播：src=multicast 且 dst=udp/tcp 时显示目标地址
o:depends({src_proto = "multicast", dst_proto = "udp"})
o:depends({src_proto = "multicast", dst_proto = "udp4"})
o:depends({src_proto = "multicast", dst_proto = "tcp"})
o:depends({src_proto = "multicast", dst_proto = "tcp4"})

o = s:taboption("dest", Value, "dst_unix_path", translate("目标 Unix Socket 路径"))
o.placeholder = "/var/run/target.sock"
o.rmempty = true
o:depends("dst_proto", "unix")

o = s:taboption("dest", Value, "dst_port", translate("目标端口"))
o.datatype = "port"
o.placeholder = "例如：22"
o.rmempty = true
o:depends({dst_proto = "tcp"})
o:depends({dst_proto = "tcp4"})
o:depends({dst_proto = "tcp6"})
o:depends({dst_proto = "udp"})
o:depends({dst_proto = "udp4"})
o:depends({dst_proto = "udp6"})
o:depends({dst_proto = "openssl"})
-- 组播转单播
o:depends({src_proto = "multicast", dst_proto = "udp"})
o:depends({src_proto = "multicast", dst_proto = "udp4"})
o:depends({src_proto = "multicast", dst_proto = "tcp"})
o:depends({src_proto = "multicast", dst_proto = "tcp4"})

o = s:taboption("dest", Value, "mc_dst_group", translate("目标组播组地址"),
	translate("目标组播组 IP 地址，D 类地址范围 224.0.0.0 ~ 239.255.255.255，如 239.1.1.1"))
o.placeholder = "例如：239.1.1.1"
o.datatype = "ip4addr"
o.rmempty = true
o:depends("dst_proto", "multicast")

o = s:taboption("dest", Value, "mc_dst_port", translate("目标组播端口"))
o.datatype = "port"
o.placeholder = "例如：5000"
o.rmempty = true
o:depends("dst_proto", "multicast")

-- ==============================
-- 组播配置（专用标签页）
-- ==============================
s:tab("multicast", translate("组播配置"))

o = s:taboption("multicast", DummyValue, "_mc_info")
o.rawhtml = true
o.cfgvalue = function(self, section)
	return [[<div style="background:#f0f7ff;border:1px solid #c5d8f0;border-radius:4px;
padding:10px 14px;font-size:13px;line-height:1.8;color:#333;margin-bottom:12px;">
<strong>组播转发原理</strong><br>
&bull; <b>接收端</b>：使用 UDP4-RECV + ip-add-membership 加入组播组（而非 UDP-LISTEN，后者会尝试双向通信）<br>
&bull; <b>目标单播</b>：使用 UDP4-SENDTO 转发给单个 IP:端口<br>
&bull; <b>目标组播中继</b>：使用 UDP4-DATAGRAM 转发到另一个组播组（跨网段）<br>
&bull; 接收和发送接口<b>必须分开指定</b>，否则包会从错误的网卡进出
</div>]]
end

-- 接收接口
o = s:taboption("multicast", Value, "mc_src_iface", translate("接收接口（入方向网卡）"),
	translate("本机接收组播流的网卡名称，socat 使用 so-bindtodevice 将 socket 绑定到此接口，如 eth0、eth1、br-lan"))
o.placeholder = "例如：eth0 或 br-lan"
o.rmempty = true

-- 接收本机 IP（加入组播组用）
o = s:taboption("multicast", Value, "mc_src_localip", translate("接收接口本机 IP"),
	translate("接收组播流的网卡 IP 地址（非组播地址），用于 ip-add-membership 向系统注册加入组播组，如 192.168.1.1"))
o.placeholder = "例如：192.168.1.1"
o.datatype = "ip4addr"
o.rmempty = true

-- 要接收的组播组（上游用的目标组播地址）
o = s:taboption("multicast", Value, "mc_src_group", translate("接收组播组地址"),
	translate("本机要加入并接收的组播组 IP（D 类地址），即上游发送端的目标组播地址，如 239.1.1.1"))
o.placeholder = "例如：239.1.1.1"
o.datatype = "ip4addr"
o.rmempty = true

-- 发送接口 IP（出方向）
o = s:taboption("multicast", Value, "mc_dst_iface", translate("发送接口 IP（出方向，可选）"),
	translate("组播中继时指定出口网卡 IP（ip-multicast-if 参数）。转发到单播目标时通常不需要填写，留空由系统路由决定"))
o.placeholder = "例如：192.168.2.1（留空=自动）"
o.datatype = "ip4addr"
o.rmempty = true

-- TTL
o = s:taboption("multicast", Value, "mc_ttl", translate("组播 TTL"),
	translate("组播包最多经过几个路由器。局域网内转发填 1；需要跨路由器传输时填更大值，如 16 或 64"))
o.datatype = "range(1,255)"
o.placeholder = "1"
o.default = "1"
o.rmempty = true

-- 回环
o = s:taboption("multicast", Flag, "mc_loop", translate("启用组播回环（ip-multicast-loop）"),
	translate("开启后，本机发出的组播包也会被本机其他监听进程收到。调试时可开启，生产环境通常关闭"))
o.default = "0"
o.rmempty = true

-- REUSEADDR（组播必需）
o = s:taboption("multicast", Flag, "mc_reuseaddr", translate("重用地址（SO_REUSEADDR）"),
	translate("组播接收几乎总是需要此选项，允许多个进程绑定同一组播端口。建议保持开启"))
o.default = "1"
o.rmempty = false

-- ==============================
-- 高级选项
-- ==============================
s:tab("advanced", translate("高级选项"))

o = s:taboption("advanced", Value, "fork_count", translate("最大并发连接数"),
	translate("0 表示不限制并发连接数"))
o.datatype = "uinteger"
o.placeholder = "0（不限制）"
o.default = "0"
o.rmempty = true

o = s:taboption("advanced", Value, "timeout", translate("连接超时（秒）"),
	translate("连接无活动超时时间，0 表示禁用"))
o.datatype = "uinteger"
o.placeholder = "0（禁用）"
o.rmempty = true

o = s:taboption("advanced", Value, "retry", translate("重连次数"),
	translate("连接失败后的重试次数"))
o.datatype = "uinteger"
o.placeholder = "0"
o.rmempty = true

o = s:taboption("advanced", Flag, "reuseaddr", translate("重用地址（SO_REUSEADDR）"),
	translate("允许立即复用处于 TIME_WAIT 状态的端口"))
o.default = "1"
o.rmempty = false

o = s:taboption("advanced", Flag, "nodelay", translate("禁用 Nagle 算法（TCP_NODELAY）"),
	translate("减少延迟，适合交互式流量如 SSH"))
o.default = "0"
o.rmempty = true

o = s:taboption("advanced", Flag, "keepalive", translate("启用 TCP Keepalive"),
	translate("定期发送探测包以检测连接存活"))
o.default = "1"
o.rmempty = true

o = s:taboption("advanced", Value, "user", translate("运行用户"),
	translate("以指定用户身份运行，留空则使用 root"))
o.placeholder = "root"
o.rmempty = true

o = s:taboption("advanced", Value, "custom_opts", translate("自定义参数"),
	translate("直接追加到 socat 命令行的额外参数，供高级用户使用"))
o.placeholder = "例如：-d -d"
o.rmempty = true

-- ==============================
-- 防火墙配置
-- ==============================
s:tab("firewall", translate("防火墙"))

o = s:taboption("firewall", Flag, "fw_enable", translate("自动放行入站端口"),
	translate("启动时自动在防火墙（firewall3/iptables 或 firewall4/nftables）中添加放行规则，停止时自动清除。若端口已在防火墙规则中手动放行，可关闭此选项。"))
o.default = "1"
o.rmempty = false

o = s:taboption("firewall", DummyValue, "_fw_hint", translate("防火墙后端说明"))
o.rawhtml = true
o.cfgvalue = function(self, section)
	return [[<div style="background:#f0f4ff;border:1px solid #c5d3f0;border-radius:4px;
padding:10px 14px;font-size:13px;line-height:1.7;color:#444;">
<strong>自动检测逻辑</strong><br>
&bull; 检测到 <code>nft</code> 且存在 <code>inet fw4</code> 表 → 使用 <strong>firewall4（nftables）</strong><br>
&bull; 否则检测到 <code>iptables</code> → 使用 <strong>firewall3（iptables）</strong><br>
&bull; 规则写入独立 chain（<code>socat_input</code> / <code>SOCAT_INPUT</code>），不影响其他规则<br>
&bull; 组播模式会额外放行 IGMP 协议（用于加入组播组）<br>
&bull; 服务停止时自动清除所有 Socat 相关防火墙规则
</div>]]
end

-- ==============================
-- TLS 配置
-- ==============================
s:tab("tls", translate("TLS 配置"))

o = s:taboption("tls", Value, "ssl_cert", translate("TLS 证书路径"),
	translate("PEM 格式的证书文件路径"))
o.placeholder = "/etc/socat/cert.pem"
o.rmempty = true
o:depends("src_proto", "openssl")
o:depends("dst_proto", "openssl")

o = s:taboption("tls", Value, "ssl_key", translate("TLS 私钥路径"),
	translate("PEM 格式的私钥文件路径"))
o.placeholder = "/etc/socat/key.pem"
o.rmempty = true
o:depends("src_proto", "openssl")
o:depends("dst_proto", "openssl")

o = s:taboption("tls", Flag, "ssl_verify", translate("验证对端证书"),
	translate("开启时将验证对端 TLS 证书的有效性"))
o.default = "0"
o.rmempty = true

o = s:taboption("tls", Value, "ssl_cafile", translate("CA 证书路径"),
	translate("验证对端证书时使用的 CA 证书文件"))
o.placeholder = "/etc/socat/ca.pem"
o.rmempty = true
o:depends("ssl_verify", "1")

return m
