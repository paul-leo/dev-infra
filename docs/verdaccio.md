# Verdaccio (私有 npm Registry)

[Verdaccio](https://verdaccio.org/) 是一个轻量级的私有 npm 包注册中心，用于：

- 发布团队内部私有包（如 `@dev-infra/*` scope）
- 缓存公共 npm 包（加速安装、离线可用）
- 缓存 `@harness-fe/*` 包

## 访问地址

| 项目 | 地址 |
|------|------|
| Web UI | http://localhost:9040 |
| Registry API | http://localhost:9040 |

## 用户管理

**限制：只允许注册 1 个用户（管理员）。** 后续用户需由管理员手动创建。

### 注册管理员（首次）

```bash
npm adduser --registry http://localhost:9040
# 输入用户名、密码、邮箱
```

注册成功后，`max_users: 1` 会阻止其他人自行注册。

### 手动添加用户

```bash
# 生成 htpasswd 条目
docker run --rm -it httpd:alpine htpasswd -nB new-username

# 将输出追加到 htpasswd 文件
echo 'new-username:$2y$...' >> ./data/verdaccio/storage/htpasswd
```

### 删除用户

编辑 `./data/verdaccio/storage/htpasswd`，删除对应行即可。

## 包管理

### 发布私有包

```bash
# 登录
npm login --registry http://localhost:9040

# 发布
npm publish --registry http://localhost:9040
```

### 项目级配置（推荐）

在项目根目录创建 `.npmrc`：

```ini
# 私有 scope 指向本地 registry
@dev-infra:registry=http://localhost:9040

# harness-fe 包缓存（可选，加速安装）
@harness-fe:registry=http://localhost:9040

# 认证 token（npm login 后自动生成）
//localhost:9040/:_authToken=your-token-here
```

### pnpm 项目配置

```ini
# .npmrc (pnpm 兼容)
@dev-infra:registry=http://localhost:9040
@harness-fe:registry=http://localhost:9040
```

## 包访问策略

| 包 Scope | 读取 | 发布 | 代理 |
|----------|------|------|------|
| `@dev-infra/*` | 需认证 | 需认证 | 不代理（纯私有） |
| `@harness-fe/*` | 所有人 | 需认证 | npmjs（缓存） |
| 其他所有包 | 所有人 | 需认证 | npmjs（缓存） |

## LAN 访问

团队其他成员使用你的 LAN IP：

```ini
# 其他成员的 .npmrc
@dev-infra:registry=http://192.168.1.100:9040
```

确保 `.env` 中设置了 `HOST_IP=0.0.0.0` 或具体 LAN IP。

## 配置文件

配置位于 `verdaccio/config.yaml`，修改后重启生效：

```bash
docker compose restart verdaccio
```

## 存储

- 包文件：`./data/verdaccio/storage/`
- 用户数据：`./data/verdaccio/storage/htpasswd`

## 故障排查

| 问题 | 解决方案 |
|------|---------|
| `npm adduser` 被拒绝 | 已达到 `max_users` 限制，需管理员手动添加 |
| 发布 403 | 检查是否已 `npm login`，token 是否有效 |
| 安装超时 | 检查 npmjs uplink 网络，或增大 `timeout` |
| Web UI 打不开 | 确认 `VERDACCIO_PORT` 正确，容器正在运行 |
