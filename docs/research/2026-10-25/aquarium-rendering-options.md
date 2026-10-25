# 鱼缸场景渲染与开源方案比较

- 日期：2026-10-25
- 状态：**建议方案，未采纳为实现依赖，未实施**
- 决策人：用户；接受人/日期：待定
- 范围：Todo-AI 本地 macOS 常驻像素鱼缸的渲染、游动和遮挡
- 关联：[产品 Spec](../../spec/2026-10-25/pixel-aquarium.md)、[详细设计](../../design/2026-10-25/pixel-aquarium-scene-design.md)
- 可信度：原生框架能力和来源许可证较高；本项目实际效果、能耗与输入兼容性待小样验证

## 1. 问题与约束

要解决的是固定视角小鱼缸中可信的前后遮挡、鱼体运动、水草摆动和水面变化。用户已再次确认保留像素风；照片用于结构和动态参考，不要求照片级材质。

硬约束：兼容当前 macOS 14+、SwiftUI/AppKit 与本地存储；真实待办通过共享核心发奖；不新增账号、云服务或联网运行要求；保留悬浮组件点击、拖动、锁定退出入口。目标使用期为长期桌面常驻，视觉实现可替换，奖励记录不可因替换渲染器丢失。本轮没有开发截止日期，也没有安装或运行第三方项目的授权需求。

偏好：系统能力优先，低常驻开销，使用原创或授权明确素材，不为小组件引入完整游戏外壳。

## 2. 已检查的本地基线

- Package.swift：macOS 14，SwiftUI/AppKit + 系统 SQLite，无第三方运行库。
- Windows.swift：独立球窗口与任务面板，当前球 44×44 pt。
- 现有 HTML 原型：只有 x/y 位置，鱼按屏幕 y 排序，整张背景先绘制，再绘鱼，最后绘两簇前景植物；不能表达木头与鱼的动态前后关系。
- 当前可复用：尺寸/背景预览控件、入缸与寿命演示、已确认业务规则。旧背景和单平面鱼运动不能作为新遮挡方案已通过的证据。

## 3. 候选与取舍

| 候选 | 类型 / 精确观察对象 | 对本项目的适配 | 决策 |
| --- | --- | --- | --- |
| 继续现有 Canvas 原型 | 自绘基线；当前项目文件 | 快速看图，但需要自己维护场景排序、运动、变形和桌面宿主；目前没有障碍体积与深度 | 保留为旧版对照；不继续叠加补丁作为正式内核 |
| SpriteKit + GameplayKit | macOS 系统框架；2026-10-25 官方文档 | SKView 是 NSView；节点深度、网格形变、暂停/帧率；GKGoal 提供路径跟随、避让、分离和群游；符合现有原生窗口结构 | **建议采用系统框架，结合少量项目专用场景规则** |
| WebGL Samples Aquarium | BSD 三条款样例；提交 4c87dfea3cff6bf9f351c5ed4a191f86ceed8bbc | 鱼身弯曲、水草 shader 是直接可读的参考；完整应用引入 WebGL/JS 宿主，视觉是三维水族箱 | 参考着色与变形方法；不整套引入 |
| RippleAquarium | Three.js / TypeScript；提交 86e3f219a9687fc602938dfcc28dd5fad2c6a222；package 标称 1.0.0 | 现有鱼群、障碍回避、水面高度场、珊瑚等模块；需要网页宿主和运行资源，多个上游素材 | 行为结构参考；不作为本轮依赖 |
| Koi Farm | 公开源码游戏；提交 f6f66662a279d5580e500c33d76a1d224b8863f4 | 鱼脊柱、鱼鳍和尾部联动有参考价值；俯视池塘与正视草缸差异大，包含繁育和完整游戏外壳 | 只研究运动观感；不拷贝项目代码/素材 |

本轮未安装这些仓库、未运行构建脚本、未执行 benchmark。这里的“参考”不等于性能或视觉质量已在 Todo-AI 验证。

## 4. 来源与实际证据

### WebGL Samples Aquarium

- [仓库](https://github.com/WebGLSamples/WebGLSamples.github.io)、[Aquarium 源码](https://github.com/WebGLSamples/WebGLSamples.github.io/tree/4c87dfea3cff6bf9f351c5ed4a191f86ceed8bbc/aquarium)。
- 实读 aquarium.html：fishVertexShader 使用鱼长、波长和弯曲量驱动身体偏移；另有独立 seaweedVertexShader。可参考“尾部幅度大于头部”和植物按自身局部坐标摆动的方式。
- [根 LICENSE](https://github.com/WebGLSamples/WebGLSamples.github.io/blob/4c87dfea3cff6bf9f351c5ed4a191f86ceed8bbc/LICENSE.md) 写明默认 BSD 三条款，但文件自身声明优先。若以后复用某文件或素材，仍需查看该对象声明。
- 根仓库最新观察提交为 2026-10-13 的 server 依赖更新；**不能据此声称 aquarium 模块近期重写或持续活跃维护**。

### RippleAquarium

- [仓库](https://github.com/SeanWong17/RippleAquarium)、[README](https://github.com/SeanWong17/RippleAquarium/blob/86e3f219a9687fc602938dfcc28dd5fad2c6a222/README.md)、[模拟逻辑](https://github.com/SeanWong17/RippleAquarium/blob/86e3f219a9687fc602938dfcc28dd5fad2c6a222/src/fish-school-simulation.ts)。
- 已读源文件：存在鱼状态、障碍集合、邻居感知、分离与障碍回避计算，适合参考“鱼群行为与渲染分离”。
- README 声明高度场水波、实例化主鱼群及网格邻居查询；这些是项目实现/作者说明，不转述为本机实测性能。
- package.json 标称 1.0.0，Three.js 范围 ^0.185.0，TypeScript 范围 ^6.0.3；同时 vendored Three.js。**未逐项核对锁文件和 vendor 与声明的一致性**。
- [LICENSE](https://github.com/SeanWong17/RippleAquarium/blob/86e3f219a9687fc602938dfcc28dd5fad2c6a222/LICENSE) 为 AGPL-3.0；README 另列多项模型来源。直接整合前需逐项核对代码与模型条件，本轮不引入。
- 观察 HEAD 日期 2026-06-28，仓库为 fork；未形成长期维护和兼容性保证。

### Koi Farm

- [仓库](https://github.com/jobtalle/Koi)、[鱼身体结构](https://github.com/jobtalle/Koi/blob/f6f66662a279d5580e500c33d76a1d224b8863f4/js/koi/fish/fishBody.js)、[鱼运动](https://github.com/jobtalle/Koi/blob/f6f66662a279d5580e500c33d76a1d224b8863f4/js/koi/fish/fish.js)。
- 实读鱼身体源码：脊柱数组、前一帧脊柱、弹簧、鱼鳍分组和独立尾部共同组成运动。可借鉴头部引导、身体随后弯曲、尾鳍滞后的设计思想。
- [README](https://github.com/jobtalle/Koi/blob/f6f66662a279d5580e500c33d76a1d224b8863f4/README.md) 是繁育游戏，构建包含 Electron；不是可直接嵌入 AppKit 的轻量组件。
- [许可证](https://github.com/jobtalle/Koi/blob/f6f66662a279d5580e500c33d76a1d224b8863f4/LICENSE.md) 是 **Apache 2.0 加 Commons Clause**，不是无附加限制的 Apache 2.0；本文将其标为公开源码参考，不当作普通宽松开源依赖。
- HEAD 日期 2026-02-02，提交为翻译更新；不能由此证明运动模块维护频率。

### Apple 原生能力

- [SKView](https://developer.apple.com/documentation/spritekit/skview)：在 NSView 呈现场景，可暂停并设 preferredFramesPerSecond，提供绘制统计和透明设置。
- [zPosition](https://developer.apple.com/documentation/spritekit/sknode/zposition)：控制绘制和命中顺序。**不自动提供三维碰撞、透视、雾化**。Crop/Effect 节点会独立合成子树，不能把整批鱼包进一棵合成子树后期望与外部树干逐条交错。
- [SKWarpGeometryGrid](https://developer.apple.com/documentation/spritekit/skwarpgeometrygrid)：支持对二维节点网格分区变形；官方可用性包含 macOS 10.12+，覆盖工程目标版本。
- [GKGoal](https://developer.apple.com/documentation/gameplaykit/gkgoal)：包括 wander、目标速度、避让 agent/obstacle、分离/对齐/聚集、路径跟随。
- [GKObstacleGraph](https://developer.apple.com/documentation/gameplaykit/gkobstaclegraph)：二维多边形障碍导航，bufferRadius 提供障碍缓冲。官方明确生成路线高效但**不平滑**，不能把寻路节点原样作为鱼的逐点直角运动。
- [Reynolds 原始行为说明](https://www.red3d.com/cwr/boids/)：鱼群分离、对齐和聚合是行为基础；结合[转向行为](https://www.red3d.com/cwr/steer/gdc99/)中障碍优先、速度/转向限制的思路。

## 5. 为什么建议原生分层场景

| 维度 | 原生分层方案 | 整合网页水族箱 | 完全手写渲染/运动 |
| --- | --- | --- | --- |
| 集成 | 嵌入已有独立 NSPanel，业务沿用 Store | 新增网页宿主、资源和状态桥接 | 同样可原生，但维护内容最多 |
| 视觉控制 | 固定视角像素资产和遮挡易于逐项验收 | 现有完整三维场景较快，但需重做像素资产与画面风格 | 全部可控，同时风险由项目承担 |
| 能耗 | 帧率、暂停有系统入口；实际收益待测 | 浏览器运行与 GPU 负担待测，不能按框架名断言慢 | 可以优化，但需自行维护渲染调度 |
| 素材与许可 | 原创分层素材，系统框架随系统 | 多源代码/模型条件需逐项确认 | 原创素材，但研发成本更高 |
| 测试 | 业务不依赖渲染；纯场景规则可隔离测试 | 需额外测试桥接、网页生命周期和 GPU 状态 | 每个通用机制都由本项目测试 |
| 长期成本 | 系统 SDK 兼容 + 小型场景/行为模块 | 前端依赖、vendor、WebView 与上游变化 | 最大的自有代码和验证责任 |
| 退出 | 保留鱼记录和场景资产，替换渲染实现 | 需拆除网页桥接 | 代码自有但替换涉及更多自建机制 |

**建议分类：Combine。**组合系统渲染/运动能力，自己维护场景深度、通行区、鱼种参数与奖励展示；不从零写图形引擎、寻路算法或完整群游引擎。

最大反对理由：二维分层依然需要精心制作素材与通道；它不能自动解决任意三维木头交叉、自由旋转镜头和鱼身体跨越多个深度面的情况。若用户以后要求转动鱼缸或连续任意深度穿行，应重评真三维路线。

## 6. 最小适配验证与止损

后续开发时先做一个可丢弃的原生小样：一根不透明树干、一簇有孔隙的摆动水草、两条不同尺寸的鱼、前中后三个水层。只连接隔离演示数据。

要回答：SKView 嵌入现有非激活面板后，能否保持窗口输入约定，并在 240×160 pt、30 fps 下稳定表现部分遮挡、转向和水草变化。记录实际 OS、屏幕比例、硬件和 CPU/GPU/内存；不得拿浏览器帧率代替。

通过标准：固定路线中鱼的头、身体、尾依次被树干挡住并从另一侧出现；叶片摆动时遮挡边缘同步；没有层级跳变或穿木；拖动不误触清单；暂停后寿命继续按自然时间计算。

失败时先限定路径/拆分资产，不能为遮挡问题默默换成鱼整体淡出。若仍需要大量手写机制才能达标，再比较原生三维或经授权的网页方案。当前未运行此验证，未安装任何候选依赖。

## 7. 维护与重新评估

后续实施维护者负责 SpriteKit/GameplayKit 的 SDK 兼容、场景资源、动画参数和性能回归；不为仅作研究的仓库建立运行时更新关系。正式实施沿用项目 Spec、ponytail、原生 UI 验收约定。

重新评估触发：用户放弃固定视角、两层以上复杂交叉无法稳定排序、目标鱼量导致性能预算连续不达标、系统 API 兼容变化，或计划直接复用第三方代码/素材。重新评估前不扩大依赖。
