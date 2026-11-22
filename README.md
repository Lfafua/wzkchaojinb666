# 机核工坊 · PC Forge

Godot 4.7.2 的中文 3D 装机游戏，包含 PCForge 0.11 Windows 原版、触屏网页版和浏览器适配代码。

- `windows/PCForge-0.11-Windows-x64.zip` 为原始发行包。解压后运行 PCForge.exe。
- `dist/` 为静态网站，入口为 index.html。使用现代浏览器打开部署后的网址。
- `port/` 包含浏览器控制与原游戏之间的适配层。原始包提供的是编译好的逻辑与资源。
- `tools/build.py` 从原始 Windows 压缩包和官方 Godot 4.7.2 Web 单线程 release 模板重新组装浏览器引擎与游戏资源。

## 在电脑上运行网页版

在仓库根目录运行 `python -m http.server 8000 --directory dist`，浏览器打开 `http://localhost:8000`。正式部署使用 HTTPS。

## 操作

手机在「装配台」「配件架」「工作单」之间切换。轻点选取，单指拖动旋转，双指捏合缩放，双指同向移动平移。桌面可拖动旋转，中键或 Shift 拖动平移，滚轮缩放。保存与读档使用当前浏览器中的游戏存储。

## 重新构建

从 Godot 4.7.2 stable 官方导出模板包中取出 `templates/web_nothreads_release.zip`。运行：

```sh
python tools/build.py windows/PCForge-0.11-Windows-x64.zip web_nothreads_release.zip
```

Godot 的许可证和第三方版权说明随游戏分发，位于 dist 目录。