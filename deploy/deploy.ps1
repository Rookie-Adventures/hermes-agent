# Hermes Agent 一键部署脚本 (Windows PowerShell)
# 用法: .\deploy.ps1 [-SkipEnv]
#   -SkipEnv  跳过 .env 复制，稍后手动配置

param(
    [switch]$SkipEnv = $false
)

$HermesDir = "$env:USERPROFILE\.hermes"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          Hermes Agent 一键部署脚本 v0.10.0                 " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# 1. 检查系统依赖
# =============================================================================
Write-Host "[1/7] 检查系统依赖..." -ForegroundColor Yellow

# 检查 Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "    错误: 未找到 Python，请先安装 Python 3.10+" -ForegroundColor Red
    Write-Host "    下载: https://www.python.org/downloads/" -ForegroundColor Red
    exit 1
}

$PythonVersion = (python --version 2>&1).Split()[1]
Write-Host "    Python 版本: $PythonVersion" -ForegroundColor Green

# 检查 Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "    警告: 未找到 Git，部分功能可能受限" -ForegroundColor Yellow
} else {
    $GitVersion = (git --version).Split()[2]
    Write-Host "    Git 版本: $GitVersion" -ForegroundColor Green
}

# =============================================================================
# 2. 安装 Hermes Agent
# =============================================================================
Write-Host "[2/7] 安装 Hermes Agent..." -ForegroundColor Yellow

# 创建虚拟环境
if (-not (Test-Path "$ProjectDir\venv")) {
    python -m venv "$ProjectDir\venv"
    Write-Host "    创建虚拟环境: $ProjectDir\venv" -ForegroundColor Green
}

# 激活虚拟环境
& "$ProjectDir\venv\Scripts\Activate.ps1"

# 升级 pip
pip install --upgrade pip --quiet 2>$null

# 安装 Hermes Agent
pip install -e "$ProjectDir" --quiet 2>$null

# 验证安装
$HermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if ($HermesCmd) {
    Write-Host "    Hermes Agent 安装成功" -ForegroundColor Green
} else {
    Write-Host "    警告: hermes 命令未找到，可能需要重启终端" -ForegroundColor Yellow
}

# =============================================================================
# 3. 创建配置目录
# =============================================================================
Write-Host "[3/7] 创建配置目录: $HermesDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "$HermesDir\memories" | Out-Null
New-Item -ItemType Directory -Force -Path "$HermesDir\sessions" | Out-Null
New-Item -ItemType Directory -Force -Path "$HermesDir\skins" | Out-Null
New-Item -ItemType Directory -Force -Path "$HermesDir\skills" | Out-Null

# =============================================================================
# 4. 备份已有配置
# =============================================================================
$needBackup = (Test-Path "$HermesDir\.env") -or (Test-Path "$HermesDir\config.yaml")
if ($needBackup) {
    $BackupDir = "$HermesDir\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "[4/7] 备份现有配置到: $BackupDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    if (Test-Path "$HermesDir\.env") { Copy-Item "$HermesDir\.env" $BackupDir }
    if (Test-Path "$HermesDir\config.yaml") { Copy-Item "$HermesDir\config.yaml" $BackupDir }
    if (Test-Path "$HermesDir\honcho.json") { Copy-Item "$HermesDir\honcho.json" $BackupDir }
    if (Test-Path "$HermesDir\SOUL.md") { Copy-Item "$HermesDir\SOUL.md" $BackupDir }
} else {
    Write-Host "[4/7] 无现有配置，跳过备份" -ForegroundColor Yellow
}

# =============================================================================
# 5. 部署配置文件
# =============================================================================
Write-Host "[5/7] 部署配置文件..." -ForegroundColor Yellow

# config.yaml
if (Test-Path "$ScriptDir\config.yaml") {
    Copy-Item "$ScriptDir\config.yaml" "$HermesDir\config.yaml" -Force
    Write-Host "    [OK] config.yaml" -ForegroundColor Green
} else {
    Write-Host "    [SKIP] config.yaml 不存在，使用默认配置" -ForegroundColor Yellow
}

# honcho.json
if (Test-Path "$ScriptDir\honcho.json") {
    Copy-Item "$ScriptDir\honcho.json" "$HermesDir\honcho.json" -Force
    Write-Host "    [OK] honcho.json" -ForegroundColor Green
}

# SOUL.md
if (Test-Path "$ScriptDir\SOUL.md") {
    Copy-Item "$ScriptDir\SOUL.md" "$HermesDir\SOUL.md" -Force
    Write-Host "    [OK] SOUL.md" -ForegroundColor Green
}

# .env 文件处理
if ($SkipEnv) {
    Write-Host "    [SKIP] .env 已跳过 (-SkipEnv)，请手动配置" -ForegroundColor Yellow
    if (-not (Test-Path "$HermesDir\.env")) {
        New-Item -ItemType File -Path "$HermesDir\.env" -Force | Out-Null
        Write-Host "    [OK] 创建空的 .env 文件" -ForegroundColor Green
    }
} elseif (Test-Path "$ScriptDir\.env") {
    Copy-Item "$ScriptDir\.env" "$HermesDir\.env" -Force
    Write-Host "    [OK] .env" -ForegroundColor Green
} else {
    Write-Host "    [SKIP] .env 不存在，请手动配置: $HermesDir\.env" -ForegroundColor Yellow
    New-Item -ItemType File -Path "$HermesDir\.env" -Force | Out-Null
}

# 设置权限 (仅用户可读)
Write-Host "    设置文件权限..." -ForegroundColor Gray
$envFiles = @("$HermesDir\.env", "$HermesDir\honcho.json")
foreach ($f in $envFiles) {
    if (Test-Path $f) {
        try {
            $acl = Get-Acl $f
            $acl.SetAccessRuleProtection($true, $false)
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
            $acl.AddAccessRule($rule)
            Set-Acl $f $acl
        } catch {
            # Windows 权限设置可能失败，忽略
        }
    }
}

# =============================================================================
# 6. 创建启动脚本
# =============================================================================
Write-Host "[6/7] 创建启动脚本..." -ForegroundColor Yellow

# 创建 hermes.cmd wrapper
$HermesCmdContent = "@echo off`ncall `"$ProjectDir\venv\Scripts\activate.bat`"`npython -m hermes_cli %*"
$HermesCmdPath = "$env:USERPROFILE\.local\bin\hermes.cmd"
New-Item -ItemType Directory -Force -Path (Split-Path $HermesCmdPath) | Out-Null
Set-Content -Path $HermesCmdPath -Value $HermesCmdContent -Encoding ASCII
Write-Host "    [OK] 创建 hermes.cmd: $HermesCmdPath" -ForegroundColor Green

# 创建 gateway 启动脚本
$GatewayCmdContent = "@echo off`ncall `"$ProjectDir\venv\Scripts\activate.bat`"`npython -m hermes_cli gateway %*"
$GatewayCmdPath = "$env:USERPROFILE\.local\bin\hermes-gateway.cmd"
Set-Content -Path $GatewayCmdPath -Value $GatewayCmdContent -Encoding ASCII
Write-Host "    [OK] 创建 hermes-gateway.cmd: $GatewayCmdPath" -ForegroundColor Green

# 添加到 PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$env:USERPROFILE\.local\bin*") {
    [Environment]::SetEnvironmentVariable("PATH", "$env:USERPROFILE\.local\bin;$userPath", "User")
    Write-Host "    [OK] 已添加 ~/.local/bin 到 PATH" -ForegroundColor Green
}

# =============================================================================
# 7. 验证部署
# =============================================================================
Write-Host "[7/7] 验证部署..." -ForegroundColor Yellow
Write-Host ""

Write-Host "已部署文件:" -ForegroundColor Green
Get-ChildItem "$HermesDir" -Filter "*.yaml" -ErrorAction SilentlyContinue | Format-Table Name, Length, LastWriteTime
Get-ChildItem "$HermesDir" -Filter "*.json" -ErrorAction SilentlyContinue | Format-Table Name, Length, LastWriteTime
Get-ChildItem "$HermesDir" -Filter ".env" -ErrorAction SilentlyContinue | Format-Table Name, Length, LastWriteTime

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "                      部署完成!                             " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "配置概览:" -ForegroundColor White
Write-Host "  主模型:     z-ai/glm-5 (via OpenRouter, 745B MoE)"
Write-Host "  辅助模型:   全部免费 (Nemotron/Gemma via OpenRouter)"
Write-Host "  记忆提供商: Honcho (跨会话 AI 原生记忆)"
Write-Host "  记忆模式:   hybrid (自动注入 + 工具可见)"
Write-Host "  会话策略:   per-directory (每个项目独立)"
Write-Host "  审批模式:   smart (低风险自动通过)"
Write-Host "  时区:       Asia/Shanghai"
Write-Host ""

Write-Host "下一步:" -ForegroundColor White
Write-Host ""
Write-Host "  1. 配置 API 密钥:" -ForegroundColor Cyan
Write-Host "     notepad $HermesDir\.env"
Write-Host ""
Write-Host "  2. 重启终端后验证安装:" -ForegroundColor Cyan
Write-Host "     hermes doctor"
Write-Host ""
Write-Host "  3. 启动交互式对话:" -ForegroundColor Cyan
Write-Host "     hermes chat"
Write-Host ""
Write-Host "  4. 启动 Gateway (API Server):" -ForegroundColor Cyan
Write-Host "     hermes-gateway"
Write-Host ""
Write-Host "  5. Hermes Workspace UI:" -ForegroundColor Cyan
Write-Host "     访问 http://localhost:8000 (如果配置了 UI)"
Write-Host ""
