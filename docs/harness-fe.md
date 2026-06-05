# Harness-FE (AI Agent Gateway)

[Harness-FE](https://github.com/Morphicai/harness-fe) 是一个 source-aware 的前端运行时工具，通过 MCP（Model Context Protocol）将 AI agent 连接到你正在运行的应用。它提供：

- **Source-Aware 标注** — 在 JSX/Vue 元素上注入文件位置信息
- **MCP Gateway** — AI agent 通过 WebSocket/HTTP 连接到 browser + server 运行时
- **Browser Runtime** — 捕获 console/network/errors/DOM，提供用户反馈浮层
- **Server-Side Capture** — Next.js Server Component 错误、Route Handler 耗时等

## 本项目中的角色

dev-infra 中运行一个共享的 Harness-FE Gateway 实例，团队中所有前端项目可以指向同一个 gateway，实现：

- 集中管理所有项目的 agent 连接
- 团队共享 gateway（governed 模式）
- 统一的 session 数据存储

## 架构

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  AI Agent       │     │  Harness Gateway  │     │  Browser/App    │
│  (Kiro/Claude)  │◄───►│  :9050 (HTTP)     │◄───►│  Runtime Client │
│                 │ MCP │  :9051 (WebSocket) │ WS  │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## 配置

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HARNESS_ENABLED` | `true` | 是否启用 harness 服务 |
| `HARNESS_IMAGE` | `node:20-alpine` | 容器镜像 |
| `HARNESS_PORT` | `9050` | HTTP MCP 端口 |
| `HARNESS_WS_PORT` | `9051` | WebSocket 端口 |
| `HARNESS_MODE` | `solo` | 模式：`solo`（本地）/ `governed`（团队 RBAC） |
| `HARNESS_PROJECT_ID` | `dev-infra` | 项目绑定 ID |
| `HARNESS_AUTH_TOKEN` | *(空)* | 团队模式认证 token |

### Solo 模式（默认）

单人开发，无需认证，信任本地回环：

```env
HARNESS_MODE=solo
HARNESS_AUTH_TOKEN=
```

### Governed 模式（团队）

多人共享 gateway，启用 RBAC + 审计：

```env
HARNESS_MODE=governed
HARNESS_AUTH_TOKEN=your-secret-team-token
```

## 前端项目接入

### Step 1: 安装依赖

```bash
# Vite + React 项目
pnpm add -D @harness-fe/vite @harness-fe/runtime

# Next.js 项目
pnpm add -D @harness-fe/next @harness-fe/react-jsx @harness-fe/runtime @harness-fe/node-runtime
```

可通过本地 Verdaccio 缓存这些包：

```bash
# .npmrc
@harness-fe:registry=http://localhost:9040
```

### Step 2: 配置构建插件

**Vite:**

```ts
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { harnessFE } from '@harness-fe/vite';

export default defineConfig({
  plugins: [react(), harnessFE()]
});
```

**Next.js:**

```js
// next.config.mjs
import { withHarness } from '@harness-fe/next/config';
export default withHarness({/* your config */}, { projectId: 'my-app' });
```

```json
// tsconfig.json
{ "compilerOptions": { "jsxImportSource": "@harness-fe/react-jsx" } }
```

### Step 3: 配置 IDE Agent 连接

在你的 IDE（Kiro/Cursor/Claude Code）的 MCP 配置中指向共享 gateway：

```json
{
  "mcpServers": {
    "harness-fe": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@harness-fe/cli", "mcp", "--gateway", "http://localhost:9050"]
    }
  }
}
```

### Step 4: 安装 Agent Skill（推荐）

让 agent 自动了解如何使用 harness-fe 工具：

```bash
npx @harness-fe/skill install
```

### Step 5: 启动开发

```bash
pnpm dev
```

浏览器右下角会出现 "H" 浮标，agent 能实时监控你的应用状态。

## 数据存储

Session 数据持久化在 `./data/harness/` 目录，包含：

- `sessions/` — 每个 page-load 的 timeline JSONL 文件
- `tasks/` — 用户通过浮层提交的问题/截图

## 日志

```bash
docker compose logs -f harness
```

## 故障排查

| 问题 | 解决方案 |
|------|---------|
| Agent 连接不上 gateway | 检查 `HARNESS_PORT` 是否正确，确认 `HOST_IP` 允许你的网络访问 |
| 浏览器无 "H" 浮标 | 确认 `NODE_ENV=development`，检查 vite 插件是否正确加载 |
| WebSocket 断开 | 检查 `:9051` 端口可达，反代配置中是否正确处理 WS 升级 |
| Governed 模式 401 | 确认 `HARNESS_AUTH_TOKEN` 一致 |
