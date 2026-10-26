# 锁定面板悬停淡化

- 日期：2026-10-27
- 状态：本地实现与自动／原生属性验证完成；物理交互待补验
- 需求来源：用户要求锁定时鼠标移到窗口，背景不透明度变为 0%，其他文字和组件变为 50%。

## 目标、范围与规则

锁定且展开的面板在鼠标进入窗口范围时立即淡化：设置页控制的面板背景为 0%，面板其余整体显示为正常状态的 50%，包含文字、控件、边框和提示。隐藏面板阴影以避免透明背景留下遮挡。悬浮球独立，不淡化、不改变解锁入口。

采用已向用户说明的默认：移出、解锁、取消置顶恢复正常；收起时清除临时状态，再展开按当前位置重算；移动窗口也按新位置重算。不修改保存的 opacity，重启不恢复锁定／悬停状态。普通模式原有“提高对比度／减少透明”规则保持；锁定悬停时本次明确的 0% 背景规则优先。

非目标：新增设置项、改变穿透或焦点规则、修改任务数据、安装或推送。

## 接口与实现计划

- `Sources/TodoApp/Windows.swift`：沿用 `ignoresMouseEvents`；仅锁定展开时以 50 ms Timer 读取 `NSEvent.mouseLocation`，同屏幕坐标比较 panel.frame；不安装事件拦截、不请求新权限。使用 common run loop modes 保证其他操作中仍能更新。解锁／收起停止计时。状态变化时设置面板 alphaValue 为 0.5／1，关闭／恢复阴影。
- `Sources/TodoApp/Model.swift`：增加不落盘的悬停状态；根视图读取该状态清除背景，其他组件交由原生窗口统一淡化，避免遗漏原生控件或重复叠加透明度。
- `Sources/TodoApp/Views.swift`：保持视图身份、内容布局和草稿，只调整背景表现。
- 风格复用现有 `@MainActor` 控制器、`@Observable` Model，例如 `if model.lockHover != hovering { model.lockHover = hovering }`。
- 采用现有 SwiftUI／AppKit，无新依赖。Apple [mouseLocation 文档](https://developer.apple.com/documentation/appkit/nsevent/mouselocation)确认该 API 独立于事件流并返回屏幕坐标。

## 验收与命令

1. 锁定移入背景 0%、其余 50%，移出恢复；未锁定不触发。
2. 默认／0%／自定义透明度不被覆盖，保存、重启不写入悬停状态。
3. 解锁、取消置顶、收起／展开、移动位置正确恢复或重算；重复 applySettings 不产生多个计时器。
4. 面板保持 ignoresMouseEvents、不获得焦点，悬浮球不淡化且解锁可达。
5. 定向 XCTest 检查状态、原生窗口属性及偏好；真实隔离应用检查视觉和背后输入，未测环境如实列出。

命令：`swift build --product TodoAI`、`swift test --filter LockedHoverTests`、`git diff --check`。本机隔离应用通过 `NEXT_ONE_HOME` 指定临时目录运行，不用真实清单测试。

## 边界与未决事项

始终：保留真实数据、无关改动、原生输入机制；仅合并本任务并记录验证。需要另行授权：安装、推送、系统设置。禁止：捕获重放鼠标、直接修改真实数据库。无必须由用户决定的未决事项。

## 变更记录

- 2026-10-27：按用户直接实施请求制定 Spec，恢复规则采用已说明默认值；开始实施。

## 实施与验证结果

- `swift test --filter 'LockedHoverTests|HeaderDragTests|DraggingTests|AutosaveTests'` 首轮7项通过；补充真实 `NSEvent.mouseLocation` 与50 ms计时器测试后，LockedHoverTests两项通过。覆盖实际面板移到鼠标下方／移开、临时透明度、恢复、收起、取消置顶、不重复创建timer、原生穿透属性及偏好不落盘。
- debug 应用打包通过；隔离数据实际打开清单／设置并锁定。原生宿主内容渲染 `.local/locked-hover-fade/evidence/hover-content.png` 的空白背景 RGBA=(0,0,0,0)，窗口 alphaValue=0.5 由原生测试确认；内容图本身不包含窗口合成阶段的0.5系数，不将其当作最终屏幕合成截图。
- CUA 在锁定面板坐标点击报 `windowNotFoundAtPosition`，不能用于物理鼠标持续悬停和背后输入验收；不把自动设置窗口位置或属性断言冒充人工鼠标测试。多显示器、Spaces、Stage Manager 与辅助功能组合未实测。测试实例已退出，现用应用未替换。
- 无代码实现阻塞；按项目默认安全合并 main，不推送、不安装。
