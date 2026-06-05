# Dev-Infra Agent 手册

> 本文档面向在 `10.241.30.244` 服务器上工作的 AI Agent（Kiro / Claude Code / Cursor），帮助你了解团队基础设施的配置和使用方式。

## 环境概览

这台机器运行了团队共享的开发基础设施，包含以下服务：

| 服务 | 端口 | 地址 | 用途 |
|------|------|------|------|
| GitLab CE | 9080 | http://10.241.30.244:9080 | 私有 Git 仓库 + CI/CD |
| GitLab SSH | 9022 | ssh://git@10.241.30.244:9022 | Git SSH 访问 |
| GitLab Runner | — | 自动连接 GitLab | CI/CD 执行器 |
| Verdaccio | 9040 | http://10.241.30.244:9040 | 私有 npm 包注册中心 |
| Bit Server | 9030 | http://10.241.30.244:9030 | 组件共享平台 |
| Harness-FE | 9050 | http://10.241.30.244:9050 | AI Agent MCP Gateway |
| Harness WS | 9051 | ws://10.241.30.244:9051 | Harness WebSocket |

## 目录结构

```
/path/to/dev-infra/
├── .env                    # 环境配置（已配置好，勿修改密码）
├── docker-compose.yml      # 服务编排
├── data/                   # 运行时数据（持久化）
│   ├── gitlab/
│   ├── gitlab-runner/
│   ├── verdaccio/
│   ├── bit/
│   └── harness/
├── verdaccio/config.yaml   # Verdaccio 包管理配置
├── caddy/Caddyfile         # 反向代理（未启用）
└── scripts/
    ├── healthcheck.sh      # 健康检查
    ├── backup.sh           # 备份
    └── register-runner.sh  # GitLab Runner 注册
```

## 常用操作

### 服务管理

```bash
# 查看服务状态
docker compose ps

# 启动所有服务
docker compose up -d

# 只启动核心服务（verdaccio + harness）
docker compose up -d  # 不带 --profile 即可

# 重启某个服务
docker compose restart verdaccio
docker compose restart harness

# 查看日志
docker compose logs -f gitlab
docker compose logs -f verdaccio
docker compose logs -f harness
docker compose logs -f bit

# 停止所有服务
docker compose down

# 健康检查
./scripts/healthcheck.sh
```

### 选择性启动

服务通过 profiles 分组：

```bash
# 核心（verdaccio + harness）始终启动
docker compose up -d

# 加 GitLab
docker compose --profile gitlab up -d

# 加 Bit
docker compose --profile bit up -d

# 全部
docker compose --profile all up -d
```

当前 `.env` 配置为 `COMPOSE_PROFILES=all`（全部启动）。

---

## GitLab 使用

### 认证信息

- URL: http://10.241.30.244:9080
- 用户名: `root`
- 密码: `tanka@2026`

### Git 操作

```bash
# HTTP 克隆
git clone http://10.241.30.244:9080/<group>/<project>.git

# SSH 克隆（需先在 GitLab 添加 SSH Key）
git clone ssh://git@10.241.30.244:9022/<group>/<project>.git

# 设置远程仓库
git remote add origin http://10.241.30.244:9080/<group>/<project>.git
git push -u origin main
```

### 创建项目

1. 登录 http://10.241.30.244:9080
2. New Project → Create blank project
3. 设置 Visibility 为 Private

### 注册 Runner（一次性）

```bash
# 1. 在 GitLab Admin → CI/CD → Runners → New instance runner 获取 token
# 2. 执行注册
./scripts/register-runner.sh <TOKEN>
```

---

## Verdaccio (npm Registry) 使用

### 认证信息

- URL: http://10.241.30.244:9040
- 只允许 1 个管理员用户注册

### 首次设置管理员

```bash
npm adduser --registry http://10.241.30.244:9040
# 输入用户名、密码、邮箱
# 注册后不再允许新用户自注册
```

### 发布包

```bash
# 登录
npm login --registry http://10.241.30.244:9040

# 发布
npm publish --registry http://10.241.30.244:9040
```

### 项目 .npmrc 配置

在前端项目根目录创建 `.npmrc`：

```ini
@dev-infra:registry=http://10.241.30.244:9040
@harness-fe:registry=http://10.241.30.244:9040
//10.241.30.244:9040/:_authToken=${NPM_TOKEN}
```

### 包访问策略

| Scope | 读取 | 发布 | 说明 |
|-------|------|------|------|
| `@dev-infra/*` | 需认证 | 需认证 | 团队私有包 |
| `@harness-fe/*` | 所有人 | 需认证 | 缓存自 npmjs |
| 其他 | 所有人 | 需认证 | 代理 npmjs |

### 添加新用户（管理员操作）

```bash
# 生成密码哈希
docker run --rm -it httpd:alpine htpasswd -nB <username>

# 追加到 htpasswd
echo '<username>:<hash>' >> ./data/verdaccio/storage/htpasswd
```

---

## Harness-FE (MCP Gateway) 使用

### 作用

Harness-FE 让 AI Agent 能实时连接到正在运行的前端应用，提供：
- 浏览器 DOM/console/network 监控
- Source-aware 定位（精确到文件:行:列）
- 远程命令执行（点击、输入、查询）
- 用户反馈截图

### Agent MCP 配置

在你的 IDE 中配置 `.mcp.json`，指向这台机器的 gateway：

```json
{
  "mcpServers": {
    "harness-fe": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@harness-fe/cli", "mcp", "--gateway", "http://10.241.30.244:9050"]
    }
  }
}
```

### 前端项目接入

```bash
# 安装（Vite + React）
pnpm add -D @harness-fe/vite @harness-fe/runtime

# 安装（Next.js）
pnpm add -D @harness-fe/next @harness-fe/react-jsx @harness-fe/runtime @harness-fe/node-runtime
```

**Vite 配置：**

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { harnessFE } from '@harness-fe/vite';

export default defineConfig({
  plugins: [react(), harnessFE()]
});
```

**Next.js 配置：**

```js
// next.config.mjs
import { withHarness } from '@harness-fe/next/config';
export default withHarness({}, { projectId: 'my-app' });
```

```json
// tsconfig.json
{ "compilerOptions": { "jsxImportSource": "@harness-fe/react-jsx" } }
```

### 安装 Agent Skill

```bash
npx @harness-fe/skill install
```

这会向你的 IDE 注入一份操作手册，让 agent 知道如何使用 harness-fe 的所有工具。

---

## Bit (组件平台) 使用

### 配置

在 Bit workspace 的 `workspace.jsonc` 中：

```json
{
  "defaultScope": "dev-infra",
  "remotes": {
    "dev-infra": "http://10.241.30.244:9030"
  }
}
```

### 工作流

```bash
bit add src/components/button
bit tag button --patch
bit export
```

---

## 备份与恢复

### 备份

```bash
./scripts/backup.sh
# 输出到 backups/<timestamp>/
```

### 恢复 GitLab

```bash
docker compose down
# 解压备份到 data/
docker compose up -d gitlab
docker compose exec gitlab gitlab-backup restore BACKUP=<timestamp>
docker compose restart
```

---

## 端口速记表

```
9022  → GitLab SSH
9030  → Bit
9040  → Verdaccio (npm)
9050  → Harness HTTP (MCP)
9051  → Harness WebSocket
9080  → GitLab Web
```

规则：所有端口从 `90xx` 开始，避免与常见开发端口冲突。

---

## 故障排查

| 问题 | 排查步骤 |
|------|---------|
| GitLab 无法访问 | `docker compose logs gitlab` 查看是否仍在初始化（首次需 3-5 分钟） |
| npm publish 403 | 检查是否已 `npm login`，确认 token 有效 |
| npm adduser 被拒 | 已达 1 用户限制，需管理员手动添加 |
| Harness 连不上 | 确认 9050/9051 端口开放，检查防火墙规则 |
| Bit export 失败 | 确认 scope 名称匹配 `dev-infra`，检查 9030 端口 |
| 磁盘空间不足 | 清理 `data/` 下旧日志，或执行 `docker system prune` |
| 服务未启动 | 检查 `COMPOSE_PROFILES` 是否包含对应 profile |

---

## 安全注意事项

- 所有服务绑定 `0.0.0.0`，局域网内可访问
- 不要将 `.env` 文件提交到 Git（已被 `.gitignore` 排除）
- 定期更换 `GITLAB_ROOT_PASSWORD` 和 Verdaccio 管理员密码
- 如需外网访问，务必启用 HTTPS（配置 `ENABLE_HTTPS=true`）
