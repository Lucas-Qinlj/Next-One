---
name: next-one-release
description: 处理 Next One 项目的 macOS App 与 DMG 打包、Developer ID 签名、Apple 公证和分发验证。用户要求制作安装包、签名公证、更新发布流程或发布 Next One 时使用；不用于管理待办，不自动发布或替换现用应用。
---

# Next One 打包与签名

## 范围与入口

以包含本文件、`AGENTS.md` 和 `Package.swift` 的仓库根目录为工作目录。先读根目录规则、相关状态、[现有安装说明](../../../docs/distribution/local-install.md)，检查 Git 差异和当前脚本。

按用户授权选择阶段：本地开发包、正式签名包、公证包、安装替换、GitHub 发布。沿用本会话已有明确授权，不重复询问；仅要求编写流程不执行签名、公证或发布。没有公证凭据时可完成已授权的本地签名与校验，不能称已公证。

本 Skill 属于仓库开发流程，放在 `.agents/skills/`；不要复制进产品自带的 `Skills/next-one`，不要安装成全局 Skill。

## 签名资料

本项目现用安装版已切换到正式 Developer ID 签名；后续替换现用应用沿用相同 Team 与 bundle ID，不得用未签名／ad-hoc 包覆盖。证书或签名失败时保留现用版并报告，不静默降级。隔离开发包不受此限制。

- 私钥保留在 macOS 登录钥匙串，不导出到项目。`.cer` 仅含公开证书，复制它到另一台机器并不能恢复签名能力。
- 项目本地资料目录为 `.local/signing/`，受 `.gitignore` 保护。可保存 `developer-id-application.cer`、CSR 和 `signing.json`；配置只含签名身份、Team ID、证书指纹、公证钥匙串 profile 名，不存密码、私钥或 API key。
- 用 `security find-identity -v -p codesigning` 实时确认 Developer ID Application 身份与私钥配对；再核对证书到期时间。不能用 Apple Distribution、Apple Development 或 ad-hoc 代替站外分发身份。
- `signing.json` 是本地参考元数据，不是现有脚本会自动读取的配置；指纹续证后会变，不能以历史指纹替代实时检查。
- 公证凭据使用用户已配置的 `notarytool` keychain profile；如需新增，由用户在终端／系统界面完成秘密输入，不在聊天或命令日志中暴露密码。不要枚举或读取无关钥匙串秘密。
- 切换临时签名到正式签名可能需要再次授权一次；之后保持正式 bundle ID `local.todo-ai.release`、开发者 Team 和兼容的 designated requirement。证书续期不等于必须保留旧指纹。

## 现有脚本边界

- `scripts/package-app.sh release <输出.app>` 构建 Swift Package 与应用资源，不做正式签名、公证、安装。
- `scripts/package-dmg.sh` 目前是本地试装流程：重新构建 App、写入固定版本号，再生成 DMG。**不能用它封装预先签好的 App**；它会重建内容。正式流程应复用 `scripts/distribution/dmg-settings.py`，直接封装已经完成签名／票据处理的 App。用户授权改造自动化时再修改脚本，不提前宣称已有正式一键流水线。
- SwiftPM 的 `TodoAI_TodoCore.bundle` 与 `TodoAI_TodoApp.bundle` 放在 `Contents/Resources/`，应用优先从该位置加载，SwiftPM 开发／测试回退 `Bundle.module`。不要在 App 根目录放资源或使用 `--deep` 签名掩盖布局问题；签名前后检查四语资源、图标、CLI 与产品 Skill。

## 执行流程

1. 核对目标提交、版本／build、架构及已有修改；输出到新的 `.local/releases/` 子目录，不覆盖已发布资产。先完成版本号、Info.plist、资源与产品 Skill 内容，再签名。检查安装包不含真实待办、附件、`.local/signing/` 或个人配置。
2. 运行相关测试并构建 release App。读取 `.local/signing/signing.json`（存在时），核对钥匙串身份、Team ID、有效期以及 `codesign`、`xcrun notarytool`、`xcrun stapler` 可用性。使用现有 dmgbuild 环境，版本要求见现有脚本；不要默认安装全局依赖。
3. 由内到外签名：内置 `Contents/Helpers/next-one`、其他实际存在的嵌套代码，最后整个 App。使用已验证的 Developer ID Application 身份、`--options runtime --timestamp`；只添加实际需要的 entitlements，不带 `get-task-allow`，不为方便关闭安全保护。签后运行 `codesign --verify --deep --strict --verbose=2`，查看 `codesign -dv --verbose=4` 和 `codesign -dr -`，核对 Team、标识、runtime、时间戳。签名后不得再编辑包内文件。
4. 若授权公证：先用 `ditto -c -k --keepParent` 将签名 App 制成 ZIP，使用 `xcrun notarytool submit <ZIP> --keychain-profile <已有profile>` 提交，保存 submission ID。查询同一 ID 的 `info`／`log`，不要因等待超时重复提交。状态为 Accepted 后对 App 执行 `xcrun stapler staple` 和 `validate`；Rejected 时检查日志，修复后重新构建签名。ZIP 本身不能装订票据。
5. 使用已有 DMG 布局直接封装上述 App，生成只读 UDZO DMG；使用 Developer ID Application 为 DMG 签名（DMG 不使用 runtime 参数）。若授权公证，提交最终 DMG 并等到 Accepted，再装订、验证 DMG 票据。此路径让拖出的 App 和外层 DMG 都可携带票据。
6. 对最终产物执行 `hdiutil verify`、签名校验、公证票据校验；以 `spctl --assess --type execute --verbose=4 <App>` 及 `spctl --assess --type open --context context:primary-signature --verbose=4 <DMG>` 检查 Gatekeeper。最后生成 SHA-256，票据装订后不要沿用旧哈希。失败即停止交付为正式包，不关闭 Gatekeeper 或删除 quarantine 绕过。
7. 在隔离数据下验证挂载／复制、App 启动、内置 CLI、语言资源和产品 Skill。避免运行两个写入真实数据的实例。真实系统提醒事项授权及“重启／下一版更新保留授权”需单独实测；命令行签名校验不能代替这项。网络下载隔离标记、离线启动、另一台 Mac／Intel 结果分别记录，未测不得声称通过。
8. 安装替换需要相应授权，先备份现用 App 与数据；GitHub 发布需要相应授权，核对仓库、tag、发布说明、最终资产和校验和，不覆盖既有发布资产。公证成功不等于已发布，也不自动修改产品授权条款或加入自动更新。

## 交付证据

按根目录模板更新 `PROJECT_STATUS.md`，给出提交／版本、产物路径、最终 SHA-256、签名身份、有效期、公证 submission ID／状态、验证结果与未验证边界。日志与生成物留在 `.local/`，不要提交证书、凭据或用户数据。

## 官方依据

- [Developer ID 站外分发](https://developer.apple.com/developer-id/)
- [Apple 公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [自定义公证流程与钥匙串凭据](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [签名身份与权限延续](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)

执行时以当前官方文档和本机工具帮助为准；本文件定义流程，不代表已完成正式签名／公证验收。
