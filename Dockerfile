ARG NGINX_VERSION=1.26.3

FROM alpine:3.19 AS builder

ARG NGINX_VERSION

RUN apk add --no-cache \
    build-base \
    openssl-dev \
    pcre2-dev \
    zlib-dev \
    linux-headers \
    libmaxminddb-dev \
    git \
    wget

# 下载 nginx 源码
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxf nginx-${NGINX_VERSION}.tar.gz

# 下载 ngx_http_geoip2_module 第三方模块
RUN git clone https://github.com/leev/ngx_http_geoip2_module.git

RUN cd nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib64/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-http_gzip_static_module \
        --with-http_gunzip_module \
        --with-http_slice_module \
        --with-http_realip_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_secure_link_module \
        --with-http_sub_module \
        --with-http_addition_module \
        --with-http_mp4_module \
        --with-http_flv_module \
        --with-http_dav_module \
        --with-http_random_index_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-stream_ssl_preread_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-pcre \
        --add-module=../ngx_http_geoip2_module \
    && make -j$(nproc) && make install

# GeoIP2 下载阶段
FROM alpine:3.19 AS geoip

ARG GEOIP_REQUIRED=false

RUN --mount=type=secret,id=mm_account_id \
    --mount=type=secret,id=mm_license_key \
    apk add --no-cache curl && \
    mkdir -p /geoip && \
    MM_ACCOUNT=$(cat /run/secrets/mm_account_id 2>/dev/null || true) && \
    MM_KEY=$(cat /run/secrets/mm_license_key 2>/dev/null || true) && \
    if [ -z "$MM_ACCOUNT" ] || [ -z "$MM_KEY" ]; then \
        if [ "$GEOIP_REQUIRED" = "true" ]; then \
            echo "MaxMind credentials are required: set MAXMIND_ACCOUNT_ID and MAXMIND_LICENSE_KEY"; \
            exit 1; \
        fi; \
        echo "MaxMind credentials were not provided; skipping GeoIP2 database download"; \
    else \
        echo "Account ID length: ${#MM_ACCOUNT}"; \
        for edition in GeoLite2-Country GeoLite2-City; do \
            curl -fL --retry 3 --retry-delay 5 -sS \
                -u "${MM_ACCOUNT}:${MM_KEY}" \
                "https://download.maxmind.com/geoip/databases/${edition}/download?suffix=tar.gz" \
                -o "/tmp/${edition}.tar.gz"; \
            tar -xzf "/tmp/${edition}.tar.gz" -C /tmp; \
            find /tmp -type f -name "${edition}.mmdb" -exec cp {} /geoip/ \; ; \
            test -s "/geoip/${edition}.mmdb"; \
            rm -rf "/tmp/${edition}.tar.gz" /tmp/${edition}_*; \
        done; \
        ls -lh /geoip; \
    fi && \
    true

FROM alpine:3.19

RUN apk add --no-cache pcre2 openssl zlib tzdata libmaxminddb && \
    addgroup -S nginx && adduser -S -G nginx nginx && \
    mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/geoip \
        /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled \
        /etc/nginx/certs && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=geoip --chown=nginx:nginx /geoip/ /etc/nginx/geoip/
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/
COPY sites-available/ /etc/nginx/sites-available/
COPY sites-enabled/ /etc/nginx/sites-enabled/
COPY certs/ /etc/nginx/certs/
COPY html/index.html /etc/nginx/html/index.html

EXPOSE 80 443 443/udp

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
