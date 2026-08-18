# finder-guard

> 阻止访达「打字即搜索」弹窗（黑框/白框）的 macOS 后台守护程序。

macOS 26 起，在访达中**未选中任何文件**时打字，会弹出访达的快速搜索面板；配合中文输入法时渲染成黑框，非常碍事，而且系统**没有提供任何开关**来关闭它。

本程序在系统键盘层拦截：当**访达在前台 + 焦点不在文本框 + 未选中文件**时，直接吞掉字母/数字按键，让访达永远收不到打字，黑框就不会出现。

## 特性

- 只拦截访达「打字即搜索」的确切触发条件
- 其他一切场景全部放行：文本框/搜索框打字、选中文件后直接打字重命名、所有快捷键（Cmd/Ctrl/Option）、其他应用
- 自管理旋转日志（`~/finder-guard/guard.log`，超过 1MB 自动轮转）
- 崩溃自动重启 + 权限缺失时自动重试自愈（launchd `KeepAlive`）

## 工作原理

- 使用 `CGEventTap`（会话级全局键盘拦截）
- 判定结果每 ~80ms 缓存一次，开销极小
- 辅助功能查询带 0.15 秒超时，访达卡死也不会卡住你的输入
- 内置看门狗：若系统禁用拦截器会自动重新启用

## 环境要求

- macOS 26+（macOS 15 上也有效，只是黑框不那么明显）
- Xcode 命令行工具（`swiftc`，用于编译）
- 需要手动在系统设置里授予两项权限（程序本身不会主动弹窗申请）

## 安装

```bash
git clone https://github.com/ryanlonn555-lab/finder-guard.git
cd finder-guard
./build.sh          # 编译 main.swift 并 ad-hoc 签名
./install.sh        # 安装 launchd 开机自启配置
```

然后到**系统设置**里授予权限：

1. **隐私与安全性 → 输入监控** → 添加 `finder-guard` 二进制
2. **隐私与安全性 → 辅助功能** → 添加同一个 `finder-guard`

守护程序开机自启、随系统常驻、崩溃自动重启。

## 验证是否生效

```bash
tail -f ~/finder-guard/guard.log    # 应看到 "finder-guard running (tap OK)."
```

点一下桌面空白处（不选中任何文件）再打字——以前会弹出黑框，现在什么都不发生；在文本框里打字则完全不受影响。

## 常用命令

```bash
# 查看运行状态与拦截日志
cat ~/finder-guard/guard.log

# 停止（黑框会恢复出现）
launchctl bootout gui/$(id -u)/com.local.finder-guard

# 启动
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.finder-guard.plist

# 重启（改了程序后用它重载）
launchctl kickstart -k gui/$(id -u)/com.local.finder-guard
```

## 卸载

```bash
./uninstall.sh
rm -rf ~/finder-guard
```

## 故障排查

- **黑框又出现了** → `cat ~/finder-guard/guard.log`；如果看到
  `cannot create event tap`，说明权限失效 → 到系统设置把 `finder-guard` 的两项授权各「关闭→再打开」一次。
- **macOS 大版本升级后失效** → 重新授权；若仍无效，说明系统 API 可能变了，日志里会有提示。
- **重新编译过程序？** → 代码签名会变，而 TCC 授权绑定签名 → 需要重新授权（这是系统安全机制，属正常现象）。

## 已知限制

- 访达的「打字即搜索/打首字母跳转文件」功能被禁用，需要搜索请用 `Command+空格`（聚焦搜索）。
- 选中文件后直接打字重命名**不受影响**（会放行）；按回车进入重命名也正常。
- 程序**不保存任何字符**（日志只记按键码），**不联网**，不干预其他应用。

## 协议

MIT
