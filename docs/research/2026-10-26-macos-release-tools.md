# macOS 发布 Skill 与 DMG 工具比较

日期：2026-10-26。需求：将普通磁盘映像改为有正式图标、固定布局和拖拽引导的安装窗口，并查找发布流程参考。用户已授权本轮本地安装盘优化；正式签名、公证、自动更新与对外发布不在本轮执行范围。

## Skill 检索与适用范围

通过 `npx skills find 'macos release'` 检索，并阅读以下仓库的 SKILL.md；只参考，不安装全局 Skill，不执行其发布命令。

| Skill | 适用内容 | 本项目取舍 |
| --- | --- | --- |
| [fayazara/macos-app-skills — macos-release](https://github.com/fayazara/macos-app-skills/blob/main/release/SKILL.md) | 原生应用版本、构建、公证、DMG 图标布局和 GitHub/Sparkle 发布流程 | 作为流程参考较贴近；跳过其默认 Sparkle、Xcode Archive、Go 发布器与自动推送，本项目是 Swift Package |
| [steipete/agent-scripts — release-mac-app](https://github.com/steipete/agent-scripts/blob/main/skills/release-mac-app/SKILL.md) | 可恢复发布、密钥保护、签名和更新包校验 | 适合未来自动更新流水线；依赖专用 manifest、Sparkle 与作者环境，不直接引入其密钥链/1Password 管理机制 |
| [jamesrochabrun/skills — releasing-macos-apps](https://skills.sh/jamesrochabrun/skills/releasing-macos-apps) | DMG、公证、票据、GitHub Release 和 Sparkle 的完整清单 | 仅比较；不采用示例中的命令行明文密码、跳过 Git hooks 或自动推送，不能原样套用 |

Skill 不是 Apple 官方标准，也不构成发布授权。正式分发以 Apple 官方文档为依据。

## DMG 工具选择

需求是原生 Finder 安装窗口，不新建一个安装器应用。要求固定两图标、箭头背景、隐藏多余文件、完整四语资源、重复构建可验证。原有应用构建继续复用。

| 方案 | 优点 | 代价 / 结论 |
| --- | --- | --- |
| 仅 `hdiutil`（现有基线） | 系统自带、已验证可复制安装 | 不负责 Finder 布局；单独使用仍会出现用户截图中的普通文件夹，不能满足本次目标 |
| 自写 `.DS_Store` 或保存手工 Finder 布局 | 可以控制显示 | 需要维护二进制格式、背景 alias、坐标和卷引用；不值得自建通用机制 |
| [create-dmg](https://github.com/create-dmg/create-dmg) | 成熟的固定图标/背景工具，Skill 也有示例 | 通过 Finder/AppleScript 排版，有自动化与交互环境依赖；本轮不采用 |
| [dmgbuild 1.6.7](https://github.com/dmgbuild/dmgbuild) | 配置化写入窗口和图标布局、背景与 Applications 链接，无需操控 Finder | 增加仅开发侧 Python 工具环境；本轮采用，应用本身不增加运行依赖 |

选择：用 dmgbuild 管理镜像/Finder 元数据，继续复用 `package-app.sh`。最主要代价是打包需要 Python 3.10+ 和三个包，普通应用使用及原有源码启动不受影响。维护范围仅 `scripts/distribution/` 和打包入口；需要更换时可保留同一 app bundle，替换镜像生成器。

- 实际锁定：dmgbuild 1.6.7、ds-store 1.3.3、mac-alias 2.2.3，均 MIT；元数据来自 PyPI，许可证从下载的 wheel 检查。下载内容与 PyPI SHA-256 核对，锁文件保存 wheel hashes。
- 依赖仅安装在忽略的 `.local/dmg-tools/venv`，不安装全局包，不启用 badge-icons/PyObjC 可选依赖；仅采用纯 Python wheels，不执行源码构建钩子。
- 已阅读 dmgbuild 核心实现：通过 `hdiutil`、`ditto`、`SetFile` 和 DSStore/Alias 写磁盘映像，不使用 Finder AppleScript。真实构建与 Finder 视觉结果记录在项目状态。
- 本轮是已授权的实际本机打包，不是访问生产数据的工具试验；打包只读取源码构建产物与自建图形资源，写临时镜像和 `.local/releases`。不提供凭据，不调用发布服务。
- 更新策略：固定版本，工具更新或 macOS 大版本变化后先验证背景、图标位置、挂载/复制/启动和完整性；不自动升级。
- 未进行完整依赖安全审计或跨 macOS 版本测试；不以 MIT/流行度/无网络代码作为安全保证。

参考：[dmgbuild 设置](https://dmgbuild.readthedocs.io/en/latest/settings.html)、[PyPI dmgbuild](https://pypi.org/project/dmgbuild/1.6.7/)、[ds-store](https://pypi.org/project/ds-store/1.3.3/)、[mac-alias](https://pypi.org/project/mac-alias/2.2.3/)。

## 正式对外发布流程

1. 确定稳定的 bundle ID、版本/build、架构、最低系统版本及许可证；打包完整 CLI、Skill、四语资源与应用图标。
2. 使用 Developer ID Application 签名应用及嵌套可执行文件，配置 Hardened Runtime 和真正需要的 entitlements；核对 bundle 资源布局是否满足签名规范。
3. 构建最终只读 UDZO DMG，使用相应 Developer ID Application 身份签名。
4. 用 `notarytool` 提交最终外层分发容器，检查 Accepted 及日志，使用 `stapler` 装订并验证票据。Sparkle 的更新签名不是 Developer ID 签名的替代品。
5. 在干净环境，最好另一台 Mac，验证从下载、挂载、拖入 Applications、首次启动到旧数据保留的完整路径；覆盖声明支持的架构和系统版本。
6. 取得发布授权后上传正式产物、校验值与版本说明。自动更新可后续单独设计，不是本次 DMG 必须引入的能力。

当前仍是无 Developer ID 签名/公证的本机试装，不因安装窗口美化而宣称可无警告公开分发。未检查或修改用户证书、账号、密钥链和全局设置。

官方依据：[Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)、[Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[Developer ID](https://developer.apple.com/developer-id/)。
