# nginx-custom 项目上下文

## 项目目标

从 nginx 源码编译构建自定义 Docker 镜像，通过 GitHub Actions 自动推送到 `ghcr.io/luuiicy/nginx`。

## 技术栈

- **基础镜像**: Alpine 3.19（builder / geoip / runtime 三阶段构建）
- **nginx 默认版本**: 1.26.3（可通过 `workflow_dispatch` 输入覆盖）
- **CI**: GitHub Actions + docker/build-push-action@v5 + BuildKit

## 编译模块

官方模块：`http_ssl`、`http_v2`、`http_gzip_static`、`http_realip`、`stream`、`stream_realip`  
第三方模块：`ngx_http_geoip2_module`（leev/ngx_http_geoip2_module）

## GeoIP2

- 数据库：`GeoLite2-Country.mmdb`、`GeoLite2-City.mmdb`
- 构建时通过 BuildKit secret（`mm_account_id` / `mm_license_key`）下载，对应 GitHub Secrets `MAXMIND_ACCOUNT_ID` / `MAXMIND_LICENSE_KEY`
- 运行时路径：`/etc/nginx/geoip/`
- 本地构建无数据库时需手动挂载：`-v /your/geoip/:/etc/nginx/geoip/`

## 镜像发布

| 触发 | 行为 |
|---|---|
| push main | 推送 `latest` + `sha-*` |
| push `v*` tag | 推送语义化版本标签 |
| PR | 仅构建，不推送 |
| workflow_dispatch | 可指定 nginx 版本 |

## 关键约定

- GeoIP 阶段用 `no-cache-filters: geoip` 保证每次构建都重新下载最新数据库
- secret 检查：用 `if/fi` 而非 `set -eu` + `&&` 链，避免 subshell exit 不传播的 bug
- Real IP 配置需在 `nginx.conf` 中声明上游 IP 段，参考 `nginx-geoip-realip.conf.example`
