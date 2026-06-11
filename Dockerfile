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
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-threads \
        --with-stream \
        --with-stream_realip_module \
        --with-pcre \
        --add-module=../ngx_http_geoip2_module \
    && make -j$(nproc) && make install

FROM alpine:3.19

RUN apk add --no-cache pcre2 openssl tzdata libmaxminddb && \
    addgroup -S nginx && adduser -S -G nginx nginx && \
    mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/geoip && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
# GeoIP2 数据库（由 CI 下载后注入，本地构建时可省略）
COPY --chown=nginx:nginx geoip/ /etc/nginx/geoip/

EXPOSE 80 443

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
