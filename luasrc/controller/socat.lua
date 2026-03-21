-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2024 OpenWrt.org

module("luci.controller.socat", package.seeall)

function index()
	-- 不检测配置文件是否存在：安装后菜单应始终可见
	-- 首次访问时若配置文件缺失，uciBind 会自动创建空配置

	local page = entry({"admin", "services", "socat"}, cbi("socat/socat"), _("Socat 端口转发"), 30)
	page.dependent = false
	page.acl_depends = { "luci-app-socat" }

	entry({"admin", "services", "socat", "edit"}, cbi("socat/socat_edit"), nil).leaf = true

	-- API 端点
	entry({"admin", "services", "socat", "status"},  call("action_status")).leaf  = true
	entry({"admin", "services", "socat", "restart"}, call("action_restart")).leaf = true
	entry({"admin", "services", "socat", "reorder"}, call("action_reorder")).leaf = true
	entry({"admin", "services", "socat", "log"},     call("action_log")).leaf     = true
	entry({"admin", "services", "socat", "conns"},   call("action_conns")).leaf   = true
end

-- ── 状态 API ──────────────────────────────────────────────────────────
-- 返回每个实例的 enabled/running/name/pid/conns
function action_status()
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	local instances = {}

	uci:foreach("socat", "socat", function(s)
		local sname = s[".name"]
		if not sname then return end

		local pid_file = "/var/run/socat/" .. sname .. ".pid"
		local pid, running = nil, false
		if nixio.fs.access(pid_file) then
			pid = tonumber((nixio.fs.readfile(pid_file) or ""):match("%d+"))
			if pid and sys.call("kill -0 " .. pid .. " 2>/dev/null") == 0 then
				running = true
			end
		end

		instances[sname] = {
			enabled = (s.enable == "1"),
			running = running,
			name    = s.name or sname,
			pid     = pid,
		}
	end)

	luci.http.prepare_content("application/json")
	luci.http.write_json(instances)
end

-- ── 全部重启 ──────────────────────────────────────────────────────────
function action_restart()
	luci.sys.call("/etc/init.d/socat-luci restart 2>/dev/null")
	luci.http.prepare_content("application/json")
	luci.http.write_json({ok = true})
end

-- ── 规则排序 API ──────────────────────────────────────────────────────
-- POST body: order=rule1,rule2,rule3,...
-- 按传入顺序重写 UCI section 的位置
function action_reorder()
	local uci   = require "luci.model.uci".cursor()
	local order = luci.http.formvalue("order") or ""
	local names = {}
	for n in order:gmatch("[^,]+") do
		if n:match("^[%w_%-]+$") then
			names[#names + 1] = n
		end
	end

	if #names == 0 then
		luci.http.status(400, "Bad Request")
		return
	end

	-- UCI reorder：先读出所有 section 的 index，再按新顺序写回
	local i = 0
	for _, sname in ipairs(names) do
		-- uci.reorder 把 section 移到指定位置（0-indexed）
		uci:reorder("socat", sname, i)
		i = i + 1
	end
	uci:save("socat")
	uci:commit("socat")

	luci.http.prepare_content("application/json")
	luci.http.write_json({ok = true, count = #names})
end

-- ── 运行日志 API ──────────────────────────────────────────────────────
-- GET ?name=<section>&lines=<n>
-- 从 logread 中过滤 socat 相关条目，并附带实例名称标记
function action_log()
	local name  = luci.http.formvalue("name")  or ""
	local lines = tonumber(luci.http.formvalue("lines")) or 200
	if lines > 500 then lines = 500 end
	if lines < 1   then lines = 1   end

	-- 安全校验
	if name ~= "" and not name:match("^[%w_%-]+$") then
		luci.http.status(400, "Bad Request")
		return
	end

	local log_lines = {}

	-- 优先读 procd 的日志文件（ImmortalWrt/OpenWrt 默认写 /var/log/messages 或 logread）
	local cmd
	if name ~= "" then
		-- 用两次 grep 分别匹配 socat 进程和实例名，-F 固定字符串避免正则解析
		cmd = string.format(
			"logread 2>/dev/null | grep -F 'socat' | grep -F '%s' | tail -n %d",
			name, lines
		)
	else
		cmd = string.format(
			"logread 2>/dev/null | grep -F 'socat' | tail -n %d",
			lines
		)
	end

	local f = io.popen(cmd)
	if f then
		for line in f:lines() do
			log_lines[#log_lines + 1] = line
		end
		f:close()
	end

	-- 如果 logread 无内容，尝试读 /var/log/socat/<name>.log（init.d 可选重定向）
	if #log_lines == 0 and name ~= "" then
		local logfile = "/var/log/socat/" .. name .. ".log"
		if nixio.fs.access(logfile) then
			local lf = io.open(logfile, "r")
			if lf then
				local all = lf:read("*a") or ""
				lf:close()
				local tail = {}
				for l in all:gmatch("[^\n]+") do tail[#tail+1] = l end
				local start = math.max(1, #tail - lines + 1)
				for i = start, #tail do log_lines[#log_lines+1] = tail[i] end
			end
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		name  = name,
		lines = log_lines,
		count = #log_lines,
	})
end

-- ── 连接数统计 API ────────────────────────────────────────────────────
-- 读取 /proc/net/tcp 和 /proc/net/tcp6，统计各实例监听端口的 ESTABLISHED 连接数
-- /proc/net/tcp 列格式（十六进制）:
--   sl  local_address  rem_address  st  ...
-- st=01 ESTABLISHED, st=0A LISTEN
function action_conns()
	local uci  = require "luci.model.uci".cursor()
	local result = {}

	-- 读取 /proc/net/tcp[6] 并建立 port -> conn_count 映射
	local function read_proc_tcp(path)
		local port_conns = {}  -- port(decimal) -> {listen:bool, established:int}
		local f = io.open(path, "r")
		if not f then return port_conns end
		f:read("*l")  -- 跳过标题行
		for line in f:lines() do
			local fields = {}
			for w in line:gmatch("%S+") do fields[#fields+1] = w end
			if #fields >= 4 then
				local loc  = fields[2]  -- "0100007F:1F90"
				local stat = fields[4]  -- "01" or "0A"
				local port_hex = loc:match(":(%x+)$")
				if port_hex and stat then
					local port = tonumber(port_hex, 16)
					local st   = tonumber(stat, 16)
					if port then
						if not port_conns[port] then
							port_conns[port] = {listen=false, established=0}
						end
						if st == 10 then  -- 0x0A = LISTEN
							port_conns[port].listen = true
						elseif st == 1 then  -- 0x01 = ESTABLISHED
							port_conns[port].established = port_conns[port].established + 1
						end
					end
				end
			end
		end
		f:close()
		return port_conns
	end

	local tcp4 = read_proc_tcp("/proc/net/tcp")
	local tcp6 = read_proc_tcp("/proc/net/tcp6")

	-- 合并 tcp4 + tcp6
	local all_ports = {}
	for p, v in pairs(tcp4) do
		all_ports[p] = v
	end
	for p, v in pairs(tcp6) do
		if all_ports[p] then
			all_ports[p].established = all_ports[p].established + v.established
			if v.listen then all_ports[p].listen = true end
		else
			all_ports[p] = v
		end
	end

	-- 读 UDP（/proc/net/udp）：统计监听 socket 是否存在（UDP 无连接概念）
	-- st=07 为 CLOSE（未使用），其他状态视为活跃 socket
	local udp_listening = {}  -- port -> bool，表示该端口有 UDP socket 在监听
	local function read_udp(path)
		local f = io.open(path, "r")
		if not f then return end
		f:read("*l")
		for line in f:lines() do
			local fields = {}
			for w in line:gmatch("%S+") do fields[#fields+1] = w end
			if #fields >= 4 then
				local loc      = fields[2]
				local stat_hex = fields[4]
				local port_hex = loc:match(":(%x+)$")
				if port_hex and stat_hex then
					local port = tonumber(port_hex, 16)
					local st   = tonumber(stat_hex, 16)
					-- st != 7 (CLOSE) 表示有活跃 socket
					if port and st ~= 7 then
						udp_listening[port] = true
					end
				end
			end
		end
		f:close()
	end
	read_udp("/proc/net/udp")
	read_udp("/proc/net/udp6")

	-- 遍历规则，匹配端口
	uci:foreach("socat", "socat", function(s)
		local sname = s[".name"]
		if not sname then return end

		local src_proto = s.src_proto or "tcp"
		local src_port  = tonumber(s.src_port or s.mc_port or "0") or 0
		local conns = 0

		if src_proto:match("^tcp") or src_proto == "openssl" then
			-- TCP：统计 ESTABLISHED 连接数
			local pd = all_ports[src_port]
			if pd then conns = pd.established end
		elseif src_proto:match("^udp") or src_proto == "multicast" then
			-- UDP/组播：只能判断是否有监听 socket（1=有, 0=无）
			conns = udp_listening[src_port] and 1 or 0
		end

		result[sname] = {
			port  = src_port,
			proto = src_proto,
			conns = conns,
		}
	end)

	luci.http.prepare_content("application/json")
	luci.http.write_json(result)
end
