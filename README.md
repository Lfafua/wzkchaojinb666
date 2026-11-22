# 机核工坊 PC Forge 0.11

[直接游玩网页版](https://lfafua.github.io/wzkchaojinb666/)

保留原游戏硬件目录、装机、维修及跑分逻辑。手机上单指旋转、双指缩放和平移，配件架、装配台和工作单分别显示。支持 WebGL 2 的现代浏览器可运行。

## Windows 原版

从本仓库的 Code → Download ZIP 下载并解压，进入 windows 目录，双击 assemble.cmd。脚本会合并五个分卷并校验 SHA-256，生成原始 PCForge-0.11-Windows-x64.zip。再次解压，双击 PCForge.exe 游玩。

原包 SHA-256 为 `7683ec2cdbf47a81ac0a6288155a07aa3ee25e7cffc4369f87373835ab16158a`。

## 浏览器版本

`dist/` 是可独立部署的静态网站。运行 `python -m http.server 8000 --directory dist` 后，在本机打开 http://localhost:8000 。`port/` 包含浏览器适配代码。使用原始 Windows 压缩包和官方 Godot 4.7.2 的 web_nothreads_release.zip，可用 tools/build.py 重新构建游戏包和引擎。
