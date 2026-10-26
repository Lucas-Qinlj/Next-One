# Codex 持续工作规则与更新

设置中的“复制 Codex 安装/更新指令”现在包含用户级 Skill 和专属持续规则的安装授权。用户把指令发送给本机 Codex 后，由内置 CLI `integration install` 完成；应用自身启动不会修改全局配置。

## 自动维护的入口

- 用户级 `~/.agents/skills/todo-ai/SKILL.md` 是稳定入口；`run` 固定正确的 CLI 和 TODO_AI_HOME。
- 在 CODEX_HOME（默认 `~/.codex`）非空 AGENTS.override.md 优先，否则 AGENTS.md 中加入 `TODO-AI:BEGIN/END` 管理区块。区块外内容原样保留；不创建覆盖文件来隐藏原规则。
- 管理区块要求本机项目工作开始时读入口及当前上游 Skill，先查已有任务，明确工作才记录，实际开始/完成时更新；讨论不转任务，未知项目不写，失败不冒充成功。
- 详细工作规则来自应用数据目录的 `integration/current/skills/todo-ai/SKILL.md`。首次授权建立连接后，更新应用并启动一次会原子切换 current；新任务/新会话读取新版规则和 CLI，通常不必重复安装。
- USER.md 是用户自定义文件，安装/卸载和应用更新均保留。不要编辑应用维护的 current 文件；现有会话可能已经缓存旧指令，应新开会话验证。

## 安装保护与解除

`integration status` 只读检查；`integration install` 幂等安装且备份，已有未知 Skill、人工修改过的管理文件/区块、不同数据绑定都拒绝静默覆盖。先说明冲突并协调迁移，再安装；不要直接删除旧配置。

`integration uninstall` 仅在用户要求时移除未被修改的管理文件/区块，保留其他全局内容、USER.md 和待办数据。备份位于目标数据目录 `integration/setup-backups`。若全局 override 变化导致原规则不再生效，status 的 active_rules 为 false；先解除旧连接再安装到当前生效文件。

## 边界

安装成功不是行为验证。需要在已绑定目录的新 Codex 会话中，用普通开发请求验证实际 context/add/update/complete 调用和数据结果；项目指令、权限、Skill 被禁用或模型选择仍可能影响触发。不承诺所有聊天监听或绝不遗漏。其他 Agent 尚未自动配置，不修改用户其他工具的规则。

安装器接口详见[Skill 接入说明](../Skills/todo-ai/references/setup.md)，本轮验证见[生命周期 Spec](spec/2026-10-26/codex-skill-lifecycle.md)。
