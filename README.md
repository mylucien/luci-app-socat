# luci-app-socat

[![Build luci-app-socat](https://github.com/YOUR_USERNAME/luci-app-socat/actions/workflows/build.yml/badge.svg)](https://github.com/YOUR_USERNAME/luci-app-socat/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/license-GPL--2.0-blue.svg)](LICENSE)

OpenWrt LuCI 界面的 Socat 端口转发管理插件，支持多实例、全中文界面、TCP/UDP/TLS 多协议转发。

## ✨ 功能特性

- 🔀 **多协议支持**：TCP、TCP4、TCP6、UDP、UDP4、UDP6、Unix Socket、TLS/SSL
- 🧩 **多实例管理**：可同时运行多个转发规则，每个规则独立开关
- 🌐 **全中文界面**：基于 OpenWrt 主流 LuCI 风格，配置直观清晰
- 🔄 **进程守护**：使用 procd 管理进程，崩溃后自动重启
- 📊 **实时状态**：界面自动刷新各实例运行状态
- ⚙️ **高级选项**：支持 SO_REUSEADDR、TCP_NODELAY、Keepalive、超时、重连等
- 🔒 **TLS 支持**：可配置证书、私钥、CA 验证

## 📦 安装

### 方式一：从 Release 下载预编译包

前往 [Releases](../../releases) 页面，下载对应架构的 `.ipk` 文件，然后：

```bash
opkg install luci-app-socat_*.ipk
```

### 方式二：添加到 OpenWrt SDK 编译

```bash
# 将本仓库克隆到 SDK package 目录
cd openwrt-sdk/package
git clone https://github.com/YOUR_USERNAME/luci-app-socat.git

# 编译
cd ../
make package/luci-app-socat/compile V=s
```

### 方式三：作为外部 feed

在 `feeds.conf` 中添加：

```
src-git socat https://github.com/YOUR_USERNAME/luci-app-socat.git
```

然后：

```bash
./scripts/feeds update socat
./scripts/feeds install luci-app-socat
make package/luci-app-socat/compile
```

## 🗂️ 目录结构

```
luci-app-socat/
├── .github/workflows/
│   └── build.yml              # GitHub Actions 自动编译
├── luasrc/
│   ├── controller/
│   │   └── socat.lua          # 路由控制器 + 状态/启停 API
│   ├── model/cbi/socat/
│   │   ├── socat.lua          # 规则列表页面
│   │   └── socat_edit.lua     # 规则编辑页面（标签页布局）
│   └── view/socat/
│       └── socat_status.htm   # 服务状态卡片模板
├── po/zh_Hans/
│   └── luci-app-socat.po      # 中文翻译文件
├── root/
│   ├── etc/
│   │   ├── config/socat       # 默认 UCI 配置
│   │   └── init.d/socat       # procd init 脚本
│   └── usr/share/rpcd/acl.d/
│       └── luci-app-socat.json # 权限控制
└── Makefile                   # OpenWrt 包描述文件
```

## ⚙️ 配置说明

配置文件位于 `/etc/config/socat`，UCI 格式：

```uci
config global
    option enable '1'          # 全局开关

config socat 'my_rule'
    option enable '1'          # 此规则开关
    option name '内网SSH穿透'   # 规则名称（支持中文）
    option src_proto 'tcp'     # 监听协议
    option src_port '2222'     # 监听端口
    option dst_proto 'tcp'     # 目标协议
    option dst_addr '10.0.0.1' # 目标地址
    option dst_port '22'       # 目标端口
    option reuseaddr '1'       # SO_REUSEADDR
    option keepalive '1'       # TCP Keepalive
```

## 🛠️ 常见用例

### TCP 端口转发

将本机 8080 转发到内网主机 80 端口：

```
监听：TCP :8080  →  目标：TCP 192.168.1.100:80
```

### SSH 内网穿透

```
监听：TCP :2222  →  目标：TCP 10.0.0.5:22
```

### UDP 流量转发

```
监听：UDP :5353  →  目标：UDP 8.8.8.8:53
```

### TLS 终止代理

```
监听：TLS :443（配置证书）  →  目标：TCP 127.0.0.1:8080
```

## 📋 支持的 OpenWrt 版本

- OpenWrt 21.02+
- OpenWrt 22.03+
- OpenWrt 23.05+（推荐）
- OpenWrt SNAPSHOT

## 📄 License

GPL-2.0-only
