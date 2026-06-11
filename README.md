# nginx-custom

使用 nginx 源码编译构建自定义镜像，并通过 GitHub Actions 自动推送到 GitHub Container Registry (ghcr.io)。

## 启用的模块

| 模块 | 类型 | 说明 |
|---|---|---|
| `http_ssl_module` | 官方 | HTTPS 支持 |
| `http_v2_module` | 官方 | HTTP/2 支持 |
| `http_gzip_static_module` | 官方 | 预压缩静态文件 |
| `http_realip_module` | 官方 | 从代理头还原真实客户端 IP |
| `stream` | 官方 | TCP/UDP 四层代理 |
| `stream_realip_module` | 官方 | Stream 层还原真实 IP |
| `ngx_http_geoip2_module` | 第三方 | 基于 MaxMind GeoLite2 数据库进行 IP 地理位置解析 |

## 配置注意事项

### 1. GitHub Repository Secrets

在仓库 **Settings → Secrets and variables → Actions** 中添加以下 Secret：

| Secret 名称 | 说明 | 获取方式 |
|---|---|---|
| `MAXMIND_ACCOUNT_ID` | MaxMind 账号 ID | 登录 [maxmind.com](https://www.maxmind.com) → Account → Account ID |
| `MAXMIND_LICENSE_KEY` | MaxMind License Key | 登录 maxmind.com → My License Key → Generate new key |

### 2. GitHub Packages 可见性

镜像默认为私有。如需公开：

仓库主页 → **Packages** → 选择镜像 → **Package settings** → Change visibility → Public

### 3. GeoIP2 数据库

- CI 构建时会自动下载 `GeoLite2-Country.mmdb` 和 `GeoLite2-City.mmdb` 并打进镜像
- 本地构建时数据库不存在，nginx 启动会报错，需手动挂载：

```bash
docker run -d -p 80:80 \
  -v /your/geoip/:/etc/nginx/geoip/ \
  ghcr.io/<your-username>/<repo-name>:latest
```

### 4. Real IP 配置

需在 nginx.conf 中声明上游代理的 IP 段，否则 `$remote_addr` 不会被替换。参考 `nginx-geoip-realip.conf.example`：

```nginx
set_real_ip_from  10.0.0.0/8;
real_ip_header    X-Forwarded-For;
real_ip_recursive on;
```

## 触发构建

| 触发方式 | 行为 |
|---|---|
| push 到 main | 构建并推送，打 `latest` 和 `sha-*` 标签 |
| 打 `v*` tag | 构建并推送，打语义化版本标签 |
| Pull Request | 仅构建，不推送 |
| 手动触发 | 可指定 nginx 版本号 |

## 本地构建

```bash
docker build --build-arg NGINX_VERSION=1.26.3 -t nginx-custom .
```
