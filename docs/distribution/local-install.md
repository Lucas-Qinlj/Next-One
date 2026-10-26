# 本机 DMG 试装

- 日期：2026-10-26
- 范围：本机 release 应用与 DMG 制作，供用户手动拖入 Applications 试装。不是签名公证或公开发布。
- 版本：0.1.0 本地试装版，build 1；文件名同时包含本机架构和源码提交标识。首次交付目标为 Apple Silicon（arm64），macOS 14+。

## 制作

```sh
./scripts/package-dmg.sh
```

需要既有 Swift 6+ 工具链、Python 3 与 macOS 原生 `hdiutil`、`ditto`、`PlistBuddy`。产物位于忽略的 `.local/releases/`，包含 `.dmg` 和 SHA-256 校验文件；同名产物已存在时拒绝覆盖。

脚本复用 `package-app.sh release <临时应用路径>`，不会覆盖 `.build/TodoAI.app` 中正在使用的开发版。DMG 包含完整 `TodoAI.app`、指向 `/Applications` 的快捷方式和中英安装说明。应用保留同一 bundle ID、默认数据目录、CLI、完整 Skill 与四语资源，不修改真实数据、全局 Skill 或系统设置。

`package-app.sh` 的第二个参数可省略；原有 debug/release 调用默认仍输出 `.build/TodoAI.app`。CLI/应用核心功能不变。

## 安装与启动

1. 通过悬浮球右键或应用菜单退出已运行的开发版。
2. 打开 DMG，将 `TodoAI.app` 拖到其中的 `Applications` 快捷方式。
3. 从“应用程序”打开 TodoAI；单击悬浮球显示清单。
4. 安装完成后推出磁盘映像。不要直接从只读映像长期运行应用。

安装版会读取本机既有的 `~/Library/Application Support/Todo-AI`，不会新建另一套正式清单；同一数据目录不要同时运行两个 UI 实例。安装前如需备份，退出 UI、停止 CLI 写入，再复制完整数据目录。仅移除 Applications 中的应用不会清除待办数据。

安装不自动安装全局 Skill。需要接入时在设置中复制当前生成的 Codex 指令，再发送给本机 Codex 会话。旧开发版可保留作为回退入口，但切换前先退出安装版。

## 验证边界

DMG 完整性、完整资源、从映像复制到独立目录后的启动与 CLI 接入检查属于本机试装前验证。实际拖入 Applications 并沿用真实数据由用户试装，不将隔离验证表述为用户已安装。

该包未进行 Developer ID 签名或 Apple 公证。不给出绕过系统安全设置的脚本；其他 Mac、网络下载后的 Gatekeeper 行为、Intel 架构以及此前未验收的窗口/桌面组合不属于本次通过范围。正式公开发行需单独完成签名、公证与分发验证。
