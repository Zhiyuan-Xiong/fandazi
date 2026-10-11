# 克隆、运行与验证 / Clone, run and verify

## 最简本地运行

安装 Godot 4.7.2（Compatibility）。克隆后导入 `godot-demo/project.godot` 并按 **F5（运行项目）**。

```powershell
git clone https://github.com/Zhiyuan-Xiong/fandazi.git
cd fandazi
git lfs pull
godot --path godot-demo --editor
```

本地源码运行不依赖 Web 构建；仓库中的大体积 Web 包如由 LFS 管理，需 Git LFS 获取实际文件。不要把 pointer 当作游戏包。未配置 AI 也可运行页面、照片记录与家具编辑。

English: import `godot-demo/project.godot` with Godot 4.7.2, Compatibility renderer, then press F5. Python is optional; the basic prototype runs without an API key. Original app UI is Chinese.

## 可选本机服务

```powershell
cd godot-demo/ai_service
python -m pip install -r requirements.txt
python server.py
```

另开终端从根目录 `godot --path godot-demo`。需要真实识别时才在桌面原型 AI 设置中配置自己的密钥；操作会产生相应外部服务用量。不要把密钥写进脚本或提交到 Git。当前单元测试不证明真实模型可用；没有配置时选择照片保存或明确标注的免费示例。

## 重跑检查

建议使用临时 Windows 配置目录隔离真实个人数据。以下路径均在当前仓库下：

```powershell
$testRoot = Join-Path (Get-Location) '.local-test'
New-Item -ItemType Directory -Force "$testRoot/roaming","$testRoot/local" | Out-Null
$env:APPDATA = "$testRoot/roaming"
$env:LOCALAPPDATA = "$testRoot/local"
Remove-Item Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
godot --headless --path godot-demo --editor --import --quit
godot --headless --path godot-demo -- --smoke
godot --headless --path godot-demo --script res://tests/core_flow_check.gd
Push-Location godot-demo/ai_service
python -m unittest -v test_service.py
Pop-Location
```

核心报告写入隔离 `user://publication-qa/archive_pack_result.json`。测试使用合成餐食和不可用回环端点，不调用付费 AI。进程退出不会把上述环境变量写入系统设置。不要在原始项目目录运行会写 QA/构建输出的旧工具。

## Web 导出

安装匹配 Godot 4.7.2 的官方 Web 模板，再执行：

```powershell
godot --headless --path godot-demo --export-release 'Web Demo' ../demo/web/play.html
python -m http.server 8765 --bind 127.0.0.1 --directory demo/web
```

打开 `http://127.0.0.1:8765/`。不要双击 file:// HTML。使用单线程 WebAssembly / WebGL2、Compatibility，未启用 PWA 或第三方 AI 服务。公开部署由 `.github/workflows/pages.yml` 上传实际 `demo/web/` 文件（含 LFS 获取），不直接以 LFS pointer 提供网页资源。

依据：[Godot 官方 Web 导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)、[GitHub Pages 自定义工作流](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)。
