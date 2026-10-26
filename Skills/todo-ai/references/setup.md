# 本机 Codex 接入生命周期

应用设置中的准确 CLI/数据目录是事实来源。始终显式设置 TODO_AI_HOME，并正确引用所有路径。

- `todo integration status`：只读检查是否安装、受管理文件/规则是否保持一致、实际规则文件是否仍生效、上游资源是否可读。不会打开待办数据库。
- `todo integration install`：仅用户已授权时执行。安装稳定入口到 ~/.agents/skills/todo-ai，在 CODEX_HOME（默认 ~/.codex）生效的 AGENTS.override.md 或 AGENTS.md 添加一段 Todo-AI 专属规则，保留其他内容。自动备份与幂等检查；已有非托管 Skill 或人工修改冲突时失败，不强行覆盖。先与用户确认迁移安排，将旧目录备份后再安装；不能把旧数据库路径带入新入口。
- `todo integration uninstall`：仅用户要求解除接入时执行。只移除未被修改的管理文件与规则，保留 USER.md、其他文件及待办数据；修改冲突先说明并保留。
- 隔离测试可以指定 `--skill-root DIR --codex-home DIR`，不要给普通用户猜测替代目录。

## 升级

入口 SKILL.md 指向当前数据目录 integration/current/skills/todo-ai/SKILL.md；run 固定调用 integration/current/bin/todo 并设置 TODO_AI_HOME。应用升级后启动一次，已有资源准备机制原子切换 current，后续新任务/新会话读取新版正文与 CLI。应用不会因此再写全局配置，无后台常驻更新器。

不要手工改应用维护的 integration/current。个人偏好保存在安装入口旁的 USER.md；应用资源更新不覆盖它。入口/规则自身的升级或改连另一份数据仍需显式安装操作；旧入口若被修改，先协调保留用户内容，不强制重装。

## 验证

安装/更新后先 status、--help、project list、context 做只读检查，不写真实任务来“测试”。启动新 Codex 会话，用用户真实授权的普通项目请求观察是否先读取上下文并维护任务。未匹配项目时请用户明确归属，不自动绑定；无法访问/权限不足报告未同步。不把脚本成功当作 Agent 行为验证，不承诺捕获所有聊天。其他 Agent 尚未自动配置。
