# 自构建 docker nginx 镜像

使用 nginx 源码编译构建自定义镜像，并通过 GitHub Actions 自动推送到 GitHub Container Registry (ghcr.io) 和 Docker Hub。

## 启用的模块

| 模块 | 类型 | 说明 |
|---|---|---|
| `with-compat` | 官方 | 动态模块 ABI 兼容，便于后续加载同版本源码编译的动态模块 |
| `file-aio` | 官方 | 异步文件 I/O |
| `threads` | 官方 | 线程池支持 |
| `http_ssl_module` | 官方 | HTTPS 支持 |
| `http_v2_module` | 官方 | HTTP/2 支持 |
| `http_v3_module` | 官方 | HTTP/3 / QUIC 支持 |
| `http_gzip_static_module` | 官方 | 预压缩静态文件 |
| `http_gunzip_module` | 官方 | 为不支持 gzip 的客户端解压响应 |
| `http_slice_module` | 官方 | 大文件切片请求与缓存优化 |
| `http_realip_module` | 官方 | 从代理头还原真实客户端 IP |
| `http_stub_status_module` | 官方 | 基础运行状态监控 |
| `http_auth_request_module` | 官方 | 基于子请求的统一鉴权 |
| `http_secure_link_module` | 官方 | 安全链接、防盗链和 URL 过期控制 |
| `http_sub_module` | 官方 | 响应文本替换过滤 |
| `http_addition_module` | 官方 | 在响应前后追加子请求内容 |
| `http_mp4_module` | 官方 | MP4 伪流媒体支持 |
| `http_flv_module` | 官方 | FLV 伪流媒体支持 |
| `http_dav_module` | 官方 | WebDAV 文件管理方法支持 |
| `http_random_index_module` | 官方 | 目录随机首页 |
| `stream` | 官方 | TCP/UDP 四层代理 |
| `stream_ssl_module` | 官方 | Stream 层 SSL/TLS 支持 |
| `stream_realip_module` | 官方 | Stream 层还原真实 IP |
| `stream_ssl_preread_module` | 官方 | Stream 层不解密读取 TLS ClientHello 信息，例如 SNI |
| `mail` | 官方 | IMAP/POP3/SMTP 邮件代理 |
| `mail_ssl_module` | 官方 | 邮件代理 SSL/TLS 支持 |
| `ngx_http_geoip2_module` | 第三方 | 基于 MaxMind GeoLite2 数据库进行 IP 地理位置解析 |

## 配置注意事项

### 1. GitHub Repository Secrets

在仓库 **Settings → Secrets and variables → Actions** 中添加以下 Secret：

| Secret 名称 | 说明 | 获取方式 |
|---|---|---|
| `MAXMIND_ACCOUNT_ID` | MaxMind 账号 ID | 登录 [maxmind.com](https://www.maxmind.com) → Account → Account ID |
| `MAXMIND_LICENSE_KEY` | MaxMind License Key | 登录 maxmind.com → My License Key → Generate new key |
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 | Docker Hub 账号名 |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token | Docker Hub → Account settings → Personal access tokens |
| `OCIR_USERNAME` | Oracle Cloud Container Registry 登录用户名 | 通常为 `<tenancy-namespace>/<oci-username>`，身份域用户可能为 `<tenancy-namespace>/<domain>/<username>` |
| `OCIR_AUTH_TOKEN` | Oracle Cloud Auth Token | OCI Console → User settings → Auth tokens |

如需推送到 Docker Hub，还需在 **Settings → Secrets and variables → Actions → Variables** 中添加：

| Variable 名称 | 说明 | 示例 |
|---|---|---|
| `DOCKERHUB_IMAGE` | Docker Hub 镜像名，格式为 `<namespace>/<repository>` | `yourname/nginx` |

Docker Hub 上需提前存在对应仓库，且 `DOCKERHUB_TOKEN` 需要有该仓库的 Read & Write 权限。未配置 `DOCKERHUB_IMAGE` 时，Actions 只会推送到 GHCR。

如需推送到 Oracle Cloud Container Registry，迪拜区域已固定为 `me-dubai-1.ocir.io`，还需添加：

| Variable 名称 | 说明 | 示例 |
|---|---|---|
| `OCIR_NAMESPACE` | OCI Tenancy namespace | `axxxxxx1abcd` |
| `OCIR_REPOSITORY` | OCIR 仓库名，未配置时默认 `nginx` | `nginx` |

最终镜像地址格式：

```text
me-dubai-1.ocir.io/<OCIR_NAMESPACE>/<OCIR_REPOSITORY>:latest
```

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
| push 到 main | 构建并推送到 GHCR / Docker Hub，打 `latest` 和 `sha-*` 标签 |
| 打 `v*` tag | 构建并推送到 GHCR / Docker Hub，打语义化版本标签 |
| Pull Request | 仅构建，不推送 |
| 手动触发 | 可指定 nginx 版本号 |

## 本地构建与推送

### 1. 本地单平台构建

默认构建当前机器平台的镜像，不打包 GeoIP2 数据库：

```bash
docker build \
  --build-arg NGINX_VERSION=1.26.3 \
  -t luuiicy/nginx:latest \
  .
```

本地如需把 GeoIP2 数据库打进镜像，需使用 BuildKit secret 传入 MaxMind 凭据：

```bash
export MAXMIND_ACCOUNT_ID=your_maxmind_account_id
export MAXMIND_LICENSE_KEY=your_maxmind_license_key

docker build \
  --build-arg NGINX_VERSION=1.26.3 \
  --build-arg GEOIP_REQUIRED=true \
  --secret id=mm_account_id,env=MAXMIND_ACCOUNT_ID \
  --secret id=mm_license_key,env=MAXMIND_LICENSE_KEY \
  -t luuiicy/nginx:latest \
  .
```

本地运行验证：

```bash
docker run --rm -p 8080:80 luuiicy/nginx:latest
```

访问 `http://localhost:8080`，默认首页会显示服务器 IP。

### 2. 推送到 Docker Hub

`luuiicy/nginx:latest` 默认对应 Docker Hub 的 `luuiicy/nginx` 仓库：

```bash
docker login
docker push luuiicy/nginx:latest
```

其他机器拉取和运行：

```bash
docker pull luuiicy/nginx:latest

docker run -d --name nginx \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  luuiicy/nginx:latest
```

### 3. 推送到私有仓库

假设私有仓库地址是 `xsfsadfas.com`：

```bash
docker login xsfsadfas.com

docker tag luuiicy/nginx:latest xsfsadfas.com/luuiicy/nginx:latest
docker push xsfsadfas.com/luuiicy/nginx:latest
```

也可以构建时直接打私有仓库标签：

```bash
docker build \
  --build-arg NGINX_VERSION=1.26.3 \
  -t xsfsadfas.com/luuiicy/nginx:latest \
  .
```

### 4. 本地多平台构建并推送

多平台镜像建议直接推送到镜像仓库，因为 `--load` 通常只能把单个平台加载进本地 Docker。

先创建并启用 buildx builder：

```bash
docker buildx create --name multiarch-builder --use
docker buildx inspect --bootstrap
```

构建并推送 `linux/amd64` 和 `linux/arm64`：

```bash
docker login xsfsadfas.com

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg NGINX_VERSION=1.26.3 \
  --build-arg GEOIP_REQUIRED=true \
  --secret id=mm_account_id,env=MAXMIND_ACCOUNT_ID \
  --secret id=mm_license_key,env=MAXMIND_LICENSE_KEY \
  -t xsfsadfas.com/luuiicy/nginx:latest \
  --push \
  .
```

检查多平台 manifest：

```bash
docker buildx imagetools inspect xsfsadfas.com/luuiicy/nginx:latest
```

如果只想分别构建到本地测试，可以单独构建某一个平台：

```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg NGINX_VERSION=1.26.3 \
  --build-arg GEOIP_REQUIRED=true \
  --secret id=mm_account_id,env=MAXMIND_ACCOUNT_ID \
  --secret id=mm_license_key,env=MAXMIND_LICENSE_KEY \
  -t luuiicy/nginx:amd64 \
  --load \
  .
```

```bash
docker buildx build \
  --platform linux/arm64 \
  --build-arg NGINX_VERSION=1.26.3 \
  --build-arg GEOIP_REQUIRED=true \
  --secret id=mm_account_id,env=MAXMIND_ACCOUNT_ID \
  --secret id=mm_license_key,env=MAXMIND_LICENSE_KEY \
  -t luuiicy/nginx:arm64 \
  --load \
  .
```
