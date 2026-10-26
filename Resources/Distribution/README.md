# 分发视觉资源

- `paperclip-logo.png`：用户选择的图片生成模型原图，白色竖向回形针、炭黑背景；保留原始比例，不重新绘制符号。
- `TodoAI.icns`：从原图缩放并裁成 macOS 圆角方形，生成 16–1024 px 图标；应用和后续磁盘映像打包复用。
- `installer-background.png` / `installer-background@2x.png`：720 × 480 pt 安装窗口背景，提供 1x/2x；应用与 Applications 图标由 Finder 显示，不烘焙到背景中。
- `scripts/distribution/render-assets.swift` 使用 AppKit 转换 Logo、绘制安装背景与系统字体，无需第三方图像依赖。悬浮球从应用包加载同一 PNG，以圆形裁切；锁定仍显示锁。菜单栏使用系统单色 paperclip 符号。

从仓库根目录重生成：

```sh
mkdir -p .local/distribution-assets
xcrun swift scripts/distribution/render-assets.swift .local/distribution-assets
iconutil -c icns .local/distribution-assets/TodoAI.iconset -o .local/distribution-assets/TodoAI.icns
cp .local/distribution-assets/TodoAI.icns Resources/Distribution/
cp .local/distribution-assets/installer-background*.png Resources/Distribution/
```

仅提交 Logo 原图、最终 ICNS、背景和渲染源码，iconset 留在忽略的 `.local`。背景图的 point size 与像素倍率由 NSBitmapImageRep 管理，不再重复缩放 context，以免 Retina 图片放大裁切。

布局配置见 `scripts/distribution/dmg-settings.py`，安装窗口截图和验证见[安装说明](../../docs/distribution/local-install.md)。
