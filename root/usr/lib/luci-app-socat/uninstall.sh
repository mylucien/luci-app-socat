#!/bin/sh
# 卸载清理脚本，由 opkg remove 后手动调用，或集成到系统卸载流程

# 1. 停止服务
/etc/init.d/socat-luci stop 2>/dev/null

# 2. 禁用开机自启
/etc/init.d/socat-luci disable 2>/dev/null

# 3. 清除防火墙规则（stop_service 已做，这里双保险）
FW_BACKEND=""
if command -v nft >/dev/null 2>&1 && nft list tables 2>/dev/null | grep -q "inet fw4"; then
    nft flush chain inet fw4 socat_input 2>/dev/null
    nft delete chain inet fw4 socat_input 2>/dev/null
elif command -v iptables >/dev/null 2>&1; then
    iptables  -t filter -F SOCAT_INPUT 2>/dev/null
    iptables  -t filter -D INPUT -j SOCAT_INPUT 2>/dev/null
    iptables  -t filter -X SOCAT_INPUT 2>/dev/null
    ip6tables -t filter -F SOCAT_INPUT 2>/dev/null
    ip6tables -t filter -D INPUT -j SOCAT_INPUT 2>/dev/null
    ip6tables -t filter -X SOCAT_INPUT 2>/dev/null
fi

# 4. 清除 LuCI 缓存
rm -f /tmp/luci-indexcache 2>/dev/null
rm -f /tmp/luci-modulecache.* 2>/dev/null

echo "luci-app-socat 清理完成"
