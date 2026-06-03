# dev-infra

本地内网开发基础设施，基于 Docker Compose 一键启动。提供：

- **GitLab CE** — 私有 Git 仓库 + 包注册表
- **GitLab Runner** — CI/CD 流水线执行器
- **Bit Scope Server** — 自托管 Bit 组件服务器（scope: `dev-infra`）

全部走 HTTP，无需 TLS，仅限内网使用。

---

## 快速开始

**前置条件：** Docker + Docker Compose v2

```bash
# 1. 复制环境变量模板
cp .env.example .env

# 2. 修改 .env（至少改 GITLAB_ROOT_PASSWORD）

# 3. 启动所有服务
docker compose up -d
```

GitLab 首次启动初始化需要约 3-5 分钟。

---

## 服务地址

| 服务 | 默认地址 |
|------|---------|
| GitLab | http://localhost:8080 |
| GitLab SSH | ssh://localhost:9022 |
| Bit Server | http://localhost:3000 |

默认账号：`root` / `.env` 中的 `GITLAB_ROOT_PASSWORD`

---

## 环境变量说明

所有配置集中在 `.env`，全部支持覆盖默认值：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `COMPOSE_PROJECT_NAME` | `dev-infra` | Compose 项目名，影响容器/网络命名 |
| `HOST_IP` | `127.0.0.1` | 服务绑定的 IP。`0.0.0.0` 或局域网 IP 可供团队共用 |
| `GITLAB_PORT` | `8080` | GitLab Web 端口 |
| `GITLAB_SSH_PORT` | `9022` | GitLab SSH 端口 |
| `GITLAB_EXTERNAL_URL` | `http://localhost:8080` | clone 链接和 Web 跳转使用的 URL，必须与 `HOST_IP:GITLAB_PORT` 一致 |
| `GITLAB_ROOT_PASSWORD` | *(必填)* | 初始 root 密码，首次登录后立即修改 |
| `BIT_PORT` | `3000` | Bit Server 端口 |
| `BIT_SCOPE_NAME` | `dev-infra` | Bit scope 名称 |

### 多人共用（局域网机器）示例

```env
HOST_IP=192.168.1.100
GITLAB_EXTERNAL_URL=http://192.168.1.100:8080
GITLAB_ROOT_PASSWORD=your-strong-password
```

---

## GitLab 使用

### 首次登录

访问 http://localhost:8080，用 `root` + 密码登录，进入 Admin Area 完成基础配置：

- 创建用户账号（Admin Area → Users → New user）
- 关闭 root 账号日常使用

### 克隆项目

```bash
# HTTP
git clone http://localhost:8080/yourgroup/yourproject.git

# SSH（需先在 GitLab 添加 SSH 公钥）
git clone ssh://git@localhost:9022/yourgroup/yourproject.git
```

### Package Registry

GitLab 内置包注册表，支持 npm、pip、Maven 等。以 npm 为例：

```bash
# 发布
npm publish --registry http://localhost:8080/api/v4/projects/<project-id>/packages/npm/

# .npmrc 配置
@your-scope:registry=http://localhost:8080/api/v4/packages/npm/
//localhost:8080/api/v4/packages/npm/:_authToken=<your-token>
```

---

## GitLab Runner（CI/CD）

Runner 容器已随服务启动，但需要**注册一次**才能接收 pipeline 任务。

### 注册步骤

1. 登录 GitLab → Admin Area → CI/CD → Runners → **New instance runner**
2. 复制 runner token
3. 执行注册脚本：

```bash
./scripts/register-runner.sh <TOKEN>
```

注册配置持久化在 `data/gitlab-runner/config/config.toml`，重启后无需再次注册。

### Pipeline 示例

项目根目录新建 `.gitlab-ci.yml`：

```yaml
stages:
  - build
  - test

build:
  stage: build
  image: node:22
  script:
    - npm ci
    - npm run build

test:
  stage: test
  image: node:22
  script:
    - npm run test
```

---

## Bit Scope 使用

Bit scope 名称：`dev-infra`，服务地址：`http://localhost:3000`

### 客户端配置

```bash
# 安装 Bit CLI（如未安装）
npm install -g @teambit/bvm && bvm install
```

在项目 `workspace.jsonc` 中配置 remote scope：

```jsonc
{
  "defaultScope": "dev-infra",
  "remotes": {
    "dev-infra": "http://localhost:3000"
  }
}
```

### 日常工作流

```bash
# 追踪组件
bit add src/components/Button

# 打版本
bit tag Button --patch

# 推送到本地 scope server
bit export

# 其他项目导入
bit import dev-infra/button

# 查看已发布组件
open http://localhost:3000/dev-infra
```

### CI 中使用 Bit

在 `.gitlab-ci.yml` 中设置 Bit token：

```yaml
variables:
  BIT_TOKEN: $BIT_TOKEN   # 在 GitLab CI/CD Variables 中配置

before_script:
  - bit config set user.token $BIT_TOKEN
```

获取 token：

```bash
docker exec -it dev-infra-bit-1 bit login --machine-name ci
```

---

## 数据目录

所有持久化数据存放在 `data/`（已加入 `.gitignore`）：

```
data/
├── gitlab/          # GitLab 配置、日志、数据
├── gitlab-runner/   # Runner 配置
└── bit/             # Bit scope 数据
```

备份只需打包 `data/` 目录。

---

## HTTPS / 对外暴露

如需暴露到公网，在前面加 TLS 反向代理（Nginx / Caddy）。`caddy/Caddyfile` 提供了配置参考。
