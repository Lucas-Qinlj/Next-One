# 分发视觉资源

- `TodoAI.icns`：应用及磁盘映像图标，沿用现有悬浮球的绿色清单主题，原生路径绘制，不使用外部素材。
- `installer-background.png` / `installer-background@2x.png`：720 × 480 pt 安装窗口背景，提供 1x/2x；应用与 Applications 图标由 Finder 显示，不烘焙到背景中。
- `scripts/distribution/render-assets.swift` 使用 AppKit 绘制可编辑的几何图形与系统字体；无需第三方图像依赖。未修改应用内悬浮球本身。

从仓库根目录重生成：

```sh
mkdir -p .local/distribution-assets
xcrun swift scripts/distribution/render-assets.swift .local/distribution-assets
iconutil -c icns .local/distribution-assets/TodoAI.iconset -o .local/distribution-assets/TodoAI.icns
cp .local/distribution-assets/TodoAI.icns Resources/Distribution/
cp .local/distribution-assets/installer-background*.png Resources/Distribution/
```

仅提交最终 ICNS、背景和渲染源码，iconset 留在忽略的 `.local`。背景图的 point size 与像素倍率由 NSBitmapImageRep 管理，不再重复缩放 context，以免 Retina 图片放大裁切。

布局配置见 `scripts/distribution/dmg-settings.py`，安装窗口截图和验证见[安装说明](../../docs/distribution/local-install.md)。
