# nginx-custom

使用 nginx 源码编译构建自定义镜像，并通过 GitHub Actions 自动推送到 GitHub Container Registry (ghcr.io)。

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

本地如需把 GeoIP2 数据库打进镜像，需使用 BuildKit secret 传入 MaxMind 凭据：

```bash
docker build \
  --build-arg NGINX_VERSION=1.26.3 \
  --build-arg GEOIP_REQUIRED=true \
  --secret id=mm_account_id,env=MAXMIND_ACCOUNT_ID \
  --secret id=mm_license_key,env=MAXMIND_LICENSE_KEY \
  -t nginx-custom .
```
