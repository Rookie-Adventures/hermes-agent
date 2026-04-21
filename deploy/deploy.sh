#!/usr/bin/env bash
# =============================================================================
# Hermes Agent + Workspace UI 一键部署脚本 (全新服务器)
# 用法: bash deploy.sh [--skip-env] [--with-ui]
#   --skip-env  跳过 .env 复制，稍后手动配置
#   --with-ui   同时部署 Hermes Workspace UI
# =============================================================================

set -e

HERMES_DIR="$HOME/.hermes"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKIP_ENV=false
WITH_UI=false

# 解析参数
for arg in "$@"; do
    case $arg in
        --skip-env) SKIP_ENV=true ;;
        --with-ui) WITH_UI=true ;;
    esac
done

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Hermes Agent + Workspace UI 一键部署脚本 v0.10.0         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# 1. 系统依赖检查与安装
# =============================================================================
echo "[1/8] 检查系统依赖..."

if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3 python3-pip python3-venv git curl > /dev/null
    if [ "$WITH_UI" = true ]; then
        sudo apt-get install -y -qq nodejs npm > /dev/null 2>&1 || {
            # 如果系统 npm 版本太旧，安装 Node.js 22
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - > /dev/null 2>&1
            sudo apt-get install -y -qq nodejs > /dev/null
        }
    fi
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    sudo yum install -y -q python3 python3-pip git curl > /dev/null
    if [ "$WITH_UI" = true ]; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - > /dev/null 2>&1
        sudo yum install -y -q nodejs > /dev/null
    fi
elif command -v dnf &> /dev/null; then
    # Fedora
    sudo dnf install -y -q python3 python3-pip git curl > /dev/null
    if [ "$WITH_UI" = true ]; then
        sudo dnf install -y -q nodejs > /dev/null
    fi
else
    echo "警告: 未识别的包管理器，请确保已安装 Python 3.10+、pip、git"
fi

# 检查 Python 版本
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
echo "    Python 版本: $PYTHON_VERSION"

if [ "$WITH_UI" = true ]; then
    NODE_VERSION=$(node --version 2>&1 | cut -d'v' -f2 | cut -d. -f1)
    echo "    Node.js 版本: $(node --version 2>/dev/null || echo '未安装')"
    
    # 安装 pnpm
    if ! command -v pnpm &> /dev/null; then
        echo "    安装 pnpm..."
        npm install -g pnpm > /dev/null 2>&1
    fi
fi

# =============================================================================
# 2. 安装 Hermes Agent
# =============================================================================
echo "[2/8] 安装 Hermes Agent..."

# 创建虚拟环境
if [ ! -d "$PROJECT_DIR/venv" ]; then
    python3 -m venv "$PROJECT_DIR/venv"
fi

source "$PROJECT_DIR/venv/bin/activate"

# 升级 pip
pip install --upgrade pip -q

# 安装 Hermes Agent
pip install -e "$PROJECT_DIR" -q

# 验证安装
if command -v hermes &> /dev/null; then
    HERMES_VERSION=$(hermes --version 2>/dev/null || echo "unknown")
    echo "    Hermes Agent 安装成功: $HERMES_VERSION"
else
    echo "    警告: hermes 命令未找到，可能需要重新登录 shell"
fi

# =============================================================================
# 3. 创建配置目录
# =============================================================================
echo "[3/8] 创建配置目录: $HERMES_DIR"
mkdir -p "$HERMES_DIR/memories"
mkdir -p "$HERMES_DIR/sessions"
mkdir -p "$HERMES_DIR/skins"
mkdir -p "$HERMES_DIR/skills"

# =============================================================================
# 4. 备份已有配置
# =============================================================================
if [ -f "$HERMES_DIR/.env" ] || [ -f "$HERMES_DIR/config.yaml" ]; then
    BACKUP_DIR="$HERMES_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    echo "[4/8] 备份现有配置到: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    [ -f "$HERMES_DIR/.env" ] && cp "$HERMES_DIR/.env" "$BACKUP_DIR/"
    [ -f "$HERMES_DIR/config.yaml" ] && cp "$HERMES_DIR/config.yaml" "$BACKUP_DIR/"
    [ -f "$HERMES_DIR/honcho.json" ] && cp "$HERMES_DIR/honcho.json" "$BACKUP_DIR/"
    [ -f "$HERMES_DIR/SOUL.md" ] && cp "$HERMES_DIR/SOUL.md" "$BACKUP_DIR/"
else
    echo "[4/8] 无现有配置，跳过备份"
fi

# =============================================================================
# 5. 部署配置文件
# =============================================================================
echo "[5/8] 部署配置文件..."

# 复制配置文件 (如果存在)
if [ -f "$SCRIPT_DIR/config.yaml" ]; then
    cp "$SCRIPT_DIR/config.yaml" "$HERMES_DIR/config.yaml"
    echo "    ✓ config.yaml"
else
    echo "    ✗ config.yaml 不存在，使用默认配置"
fi

if [ -f "$SCRIPT_DIR/honcho.json" ]; then
    cp "$SCRIPT_DIR/honcho.json" "$HERMES_DIR/honcho.json"
    echo "    ✓ honcho.json"
fi

if [ -f "$SCRIPT_DIR/SOUL.md" ]; then
    cp "$SCRIPT_DIR/SOUL.md" "$HERMES_DIR/SOUL.md"
    echo "    ✓ SOUL.md"
fi

# .env 文件处理
if [ "$SKIP_ENV" = true ]; then
    echo "    ⚠ .env 已跳过 (--skip-env)，请手动配置"
    # 创建空的 .env 模板
    if [ ! -f "$HERMES_DIR/.env" ]; then
        touch "$HERMES_DIR/.env"
        echo "    ✓ 创建空的 .env 文件"
    fi
elif [ -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env" "$HERMES_DIR/.env"
    echo "    ✓ .env"
else
    echo "    ⚠ .env 不存在，请手动配置: $HERMES_DIR/.env"
    touch "$HERMES_DIR/.env"
fi

# 设置权限
chmod 600 "$HERMES_DIR/.env" 2>/dev/null || true
chmod 600 "$HERMES_DIR/honcho.json" 2>/dev/null || true
chmod 644 "$HERMES_DIR/config.yaml" 2>/dev/null || true
chmod 644 "$HERMES_DIR/SOUL.md" 2>/dev/null || true

# =============================================================================
# 6. 部署 Hermes Workspace UI (可选)
# =============================================================================
if [ "$WITH_UI" = true ]; then
    echo "[6/8] 部署 Hermes Workspace UI..."
    
    UI_DIR="$HOME/hermes-workspace"
    
    if [ -d "$UI_DIR" ]; then
        echo "    UI 目录已存在，跳过克隆"
    else
        git clone https://github.com/Rookie-Adventures/hermes-workspace.git "$UI_DIR"
        echo "    ✓ 克隆 Hermes Workspace UI"
    fi
    
    cd "$UI_DIR"
    pnpm install --silent 2>/dev/null || npm install --silent 2>/dev/null
    
    # 创建 .env 文件
    if [ ! -f "$UI_DIR/.env" ]; then
        cat > "$UI_DIR/.env" << 'UIENV'
# Hermes Gateway API URL
HERMES_API_URL=http://127.0.0.1:8642

# 如果 gateway 启用了 API_SERVER_KEY，在这里设置相同的值
# HERMES_API_TOKEN=your-key-here
UIENV
        echo "    ✓ 创建 UI .env 文件"
    fi
    
    cd "$PROJECT_DIR"
    echo "    ✓ Hermes Workspace UI 安装完成"
else
    echo "[6/8] 跳过 UI 部署 (使用 --with-ui 启用)"
fi

# =============================================================================
# 7. 配置 systemd 服务
# =============================================================================
echo "[7/8] 配置系统服务..."

# 创建 hermes shell wrapper
HERMES_BIN="$HOME/.local/bin/hermes"
mkdir -p "$(dirname "$HERMES_BIN")"
cat > "$HERMES_BIN" << 'WRAPPER'
#!/bin/bash
source "$HOME/hermes-agent/venv/bin/activate"
exec python -m hermes_cli "$@"
WRAPPER
chmod +x "$HERMES_BIN"

# 确保 .local/bin 在 PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "    已添加 ~/.local/bin 到 PATH"
fi

# 创建 systemd 服务文件 (Gateway)
SERVICE_FILE="/tmp/hermes-gateway.service"
cat > "$SERVICE_FILE" << SERVICE
[Unit]
Description=Hermes Agent Gateway
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="HERMES_HOME=$HERMES_DIR"
ExecStart=$PROJECT_DIR/venv/bin/python -m hermes_cli gateway
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

echo "    ✓ systemd 服务文件已生成"

# 创建 UI systemd 服务文件 (如果部署了 UI)
if [ "$WITH_UI" = true ]; then
    UI_SERVICE_FILE="/tmp/hermes-ui.service"
    cat > "$UI_SERVICE_FILE" << UISERVICE
[Unit]
Description=Hermes Workspace UI
After=network.target hermes-gateway.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/hermes-workspace
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=$(which pnpm 2>/dev/null || echo "pnpm") dev
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UISERVICE
    echo "    ✓ UI systemd 服务文件已生成"
fi

# =============================================================================
# 8. 验证部署
# =============================================================================
echo "[8/8] 验证部署..."
echo ""

echo "已部署文件:"
ls -la "$HERMES_DIR/" 2>/dev/null | grep -E "\.env|config\.yaml|honcho\.json|SOUL\.md" || echo "    (配置文件待手动添加)"

if [ "$WITH_UI" = true ]; then
    echo ""
    echo "UI 目录: $HOME/hermes-workspace"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      部署完成!                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "配置概览:"
echo "  主模型:     z-ai/glm-5 (via OpenRouter, 745B MoE)"
echo "  辅助模型:   全部免费 (Nemotron/Gemma via OpenRouter)"
echo "  记忆提供商: Honcho (跨会话 AI 原生记忆)"
echo "  记忆模式:   hybrid (自动注入 + 工具可见)"
echo "  会话策略:   per-directory (每个项目独立)"
echo "  审批模式:   smart (低风险自动通过)"
echo "  时区:       Asia/Shanghai"
echo ""
echo "下一步:"
echo ""
echo "  1. 配置 API 密钥:"
echo "     nano ~/.hermes/.env"
echo ""
echo "  2. 验证安装:"
echo "     source ~/.bashrc"
echo "     hermes doctor"
echo ""
echo "  3. 启动 Gateway (API Server):"
echo "     hermes gateway"
echo ""
echo "  4. 后台运行 Gateway:"
echo "     sudo mv /tmp/hermes-gateway.service /etc/systemd/system/"
echo "     sudo systemctl daemon-reload"
echo "     sudo systemctl enable --now hermes-gateway"
echo ""

if [ "$WITH_UI" = true ]; then
    echo "  5. 启动 Hermes Workspace UI:"
    echo "     cd ~/hermes-workspace && pnpm dev"
    echo ""
    echo "  6. 后台运行 UI:"
    echo "     sudo mv /tmp/hermes-ui.service /etc/systemd/system/"
    echo "     sudo systemctl daemon-reload"
    echo "     sudo systemctl enable --now hermes-ui"
    echo ""
    echo "  7. 访问:"
    echo "     Gateway API:  http://localhost:8642"
    echo "     Workspace UI: http://localhost:3000"
else
    echo "  5. 部署 Hermes Workspace UI:"
    echo "     bash deploy/deploy.sh --with-ui"
    echo ""
    echo "  6. 访问 Gateway API:"
    echo "     http://localhost:8642"
fi

echo ""
