# README 四语截图

- 更新日期：2026-10-27（Asia/Singapore）。12 张均已替换为当前 Next One 原生应用实拍。
- 来源：功能提交 `60d0b82` 的 release 安装产物（当前 `ee1eff7` 仅追加文档）；复制到独立展示应用，只改 bundle 标识／名称以隔离现用实例，未改功能代码。macOS 深色界面，480 × 740 pt 面板，原始 JPEG 960 × 1480 px。
- 每种语言使用独立 `NEXT_ONE_HOME` 和支持的 CLI 创建同语言虚构任务。没有读取或修改真实待办；未申请提醒事项权限、开启同步、安装全局 Skill 或发送安装指令。

| 目录 | 语言 | 图片 |
| --- | --- | --- |
| `en/` | English | `task-list.jpg`、`task-detail.jpg`、`settings.jpg` |
| `zh-CN/` | 简体中文 | `task-list.jpg`、`task-detail.jpg`、`settings.jpg` |
| `ja/` | 日本語 | `task-list.jpg`、`task-detail.jpg`、`settings.jpg` |
| `ko/` | 한국어 | `task-list.jpg`、`task-detail.jpg`、`settings.jpg` |

- 清单：短编号、项目计数、分层任务、截止日期、优先级和底部统一完成区。
- 详情：短编号、描述、状态、优先级、截止日期和子任务；演示文字由人工准备，不是应用自动翻译。
- 设置：语言、100%背景不透明度、项目、日历同步开关与问号、当前Codex接入指令。同步保持默认关闭；图片证明入口显示，不作为系统同步已启用或送达的证据。
- CUA 原生窗口截图直接保存，未生成、重绘或编辑图片；逐张目视检查，并核对文件格式和尺寸。部分页底部内容在滚动区域内，不代表被删除。
- 设置路径属于 `/tmp` 下的隔离演示实例，不含真实项目或个人账户；读者应复制自己应用里的路径。
- 展示实例已退出，现用安装和真实数据未替换；脚本与隔离目录指针留在本机 `.local/readme-refresh/`。
- 四语 `neo` 输入示意图仍在 [neo-examples](../neo-examples/README.md)，属于明确标注的生成示意图，本轮未改动。截图不替代完整交互／跨环境验收。
