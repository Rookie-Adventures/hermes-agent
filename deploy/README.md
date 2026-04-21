# Hermes Agent + Workspace UI 部署指南

## 快速部署 (全新服务器)

### 方案一：仅部署后端

```bash
# 1. 克隆仓库
git clone https://github.com/outsourc-e/hermes-agent.git
cd hermes-agent

# 2. 运行部署脚本 (跳过 .env，稍后手动配置)
bash deploy/deploy.sh --skip-env

# 3. 配置 API 密钥
nano ~/.hermes/.env

# 4. 验证安装
source ~/.bashrc
hermes doctor

# 5. 启动 Gateway
hermes gateway
```

### 方案二：同时部署后端 + UI

```bash
# 1. 克隆仓库
git clone https://github.com/outsourc-e/hermes-agent.git
cd hermes-agent

# 2. 运行部署脚本 (包含 UI)
bash deploy/deploy.sh --skip-env --with-ui

# 3. 配置 API 密钥
nano ~/.hermes/.env

# 4. 配置 UI (如果 gateway 启用了认证)
nano ~/hermes-workspace/.env

# 5. 验证安装
source ~/.bashrc
hermes doctor

# 6. 启动服务
hermes gateway                    # 终端 1
cd ~/hermes-workspace && pnpm dev # 终端 2
```

## 访问地址

| 服务 | 地址 |
|------|------|
| Gateway API | http://localhost:8642 |
| Workspace UI | http://localhost:3000 |

## 配置文件说明

### 后端配置 (~/.hermes/)

| 文件 | 说明 | 必须 |
|------|------|------|
| `.env` | API 密钥配置 | ✅ |
| `config.yaml` | 主配置文件 | ✅ |
| `honcho.json` | Honcho 记忆服务配置 | 可选 |
| `SOUL.md` | Agent 人格配置 | 可选 |

### UI 配置 (~/hermes-workspace/.env)

```bash
# Hermes Gateway API URL
HERMES_API_URL=http://127.0.0.1:8642

# 如果 gateway 启用了 API_SERVER_KEY，设置相同的值
# HERMES_API_TOKEN=your-key-here
```

## .env 必填项

```bash
# 至少配置一个 LLM 提供商
OPENROUTER_API_KEY=your_key_here      # 推荐，支持 200+ 模型
# 或
ANTHROPIC_API_KEY=your_key_here       # Claude 直连
# 或
OPENAI_API_KEY=your_key_here          # GPT 直连

# 启用 API Server (UI 需要)
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
```

## systemd 服务 (后台运行)

```bash
# Gateway 服务
sudo mv /tmp/hermes-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now hermes-gateway

# UI 服务 (如果部署了)
sudo mv /tmp/hermes-ui.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now hermes-ui

# 查看状态
sudo systemctl status hermes-gateway
sudo systemctl status hermes-ui
```

## 常用命令

```bash
# 交互式对话
hermes chat

# 启动 Gateway
hermes gateway

# 查看配置
hermes config show

# 健康检查
hermes doctor

# 查看日志
journalctl -u hermes-gateway -f
```

## 项目链接

- **Hermes Agent**: https://github.com/outsourc-e/hermes-agent
- **Hermes Workspace UI**: https://github.com/Rookie-Adventures/hermes-workspace
