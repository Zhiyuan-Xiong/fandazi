$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$bundledPython = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pythonPath = if (Test-Path -LiteralPath $bundledPython) { $bundledPython } elseif ($pythonCommand) { $pythonCommand.Source } else { $null }
if (-not $pythonPath) { throw '请安装 Python 3.10 或更新版本，然后安装 ai_service/requirements.txt。' }
$serverScript = Join-Path $PSScriptRoot 'server.py'
Start-Process -FilePath $pythonPath -ArgumentList ('"' + $serverScript + '"') -WindowStyle Hidden
