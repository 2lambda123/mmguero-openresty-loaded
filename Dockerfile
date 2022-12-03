####################################################################################
# thanks to:  nginx                       -  https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
#             kvspb/nginx-auth-ldap       -  https://github.com/kvspb/nginx-auth-ldap
#             tiredofit/docker-nginx-ldap -  https://github.com/tiredofit/docker-nginx-ldap/blob/master/Dockerfile
#             jwilder/nginx-proxy         -  https://github.com/jwilder/nginx-proxy/blob/master/Dockerfile.alpine

####################################################################################

FROM alpine:3.17

LABEL maintainer="mero.mero.guero@gmail.com"
LABEL org.opencontainers.image.authors='mero.mero.guero@gmail.com'
LABEL org.opencontainers.image.url='https://github.com/mmguero/nginx-ldap'
LABEL org.opencontainers.image.source='https://github.com/mmguero/nginx-ldap'
LABEL org.opencontainers.image.title='ghcr.io/mmguero/nginx-ldap'
LABEL org.opencontainers.image.description='Dockerized NGINX with LDAP Authentication'

ARG DEFAULT_UID=101
ARG DEFAULT_GID=101
ENV DEFAULT_UID $DEFAULT_UID
ENV DEFAULT_GID $DEFAULT_GID
ENV PUSER "nginx"
ENV PGROUP "nginx"
# not dropping privileges globally so nginx and stunnel can bind privileged ports internally.
# nginx itself will drop privileges to "nginx" user for worker processes
ENV PUSER_PRIV_DROP false

ENV TERM xterm

USER root

# encryption method: HTTPS ('true') vs. unencrypted HTTP ('false') vs. unauthenticated ('no_authentication')
ARG NGINX_SSL=true

# authentication method: HTTP basic authentication ('true') vs nginx-auth-ldap ('false')
ARG NGINX_BASIC_AUTH=true

# NGINX LDAP (NGINX_BASIC_AUTH=false) can support LDAP, LDAPS, or LDAP+StartTLS.
#   For StartTLS, set NGINX_LDAP_TLS_STUNNEL=true to issue the StartTLS command
#   and use stunnel to tunnel the connection.
ARG NGINX_LDAP_TLS_STUNNEL=false

# stunnel will require and verify certificates for StartTLS when one or more
# trusted CA certificate files are placed in the ./nginx/ca-trust directory.
# For additional security, hostname or IP address checking of the associated
# CA certificate(s) can be enabled by providing these values.
# see https://www.stunnel.org/howto.html
#     https://www.openssl.org/docs/man1.1.1/man3/X509_check_host.html
ARG NGINX_LDAP_TLS_STUNNEL_CHECK_HOST=
ARG NGINX_LDAP_TLS_STUNNEL_CHECK_IP=
ARG NGINX_LDAP_TLS_STUNNEL_VERIFY_LEVEL=2

ENV NGINX_SSL $NGINX_SSL
ENV NGINX_BASIC_AUTH $NGINX_BASIC_AUTH
ENV NGINX_LDAP_TLS_STUNNEL $NGINX_LDAP_TLS_STUNNEL
ENV NGINX_LDAP_TLS_STUNNEL_CHECK_HOST $NGINX_LDAP_TLS_STUNNEL_CHECK_HOST
ENV NGINX_LDAP_TLS_STUNNEL_CHECK_IP $NGINX_LDAP_TLS_STUNNEL_CHECK_IP
ENV NGINX_LDAP_TLS_STUNNEL_VERIFY_LEVEL $NGINX_LDAP_TLS_STUNNEL_VERIFY_LEVEL

# build latest nginx with nginx-auth-ldap
ENV NGINX_VERSION=1.20.2
ENV NGINX_AUTH_LDAP_BRANCH=master

ADD https://codeload.github.com/mmguero-dev/nginx-auth-ldap/tar.gz/$NGINX_AUTH_LDAP_BRANCH /nginx-auth-ldap.tar.gz
ADD http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz /nginx.tar.gz
ADD https://raw.githubusercontent.com/mmguero/docker/master/shared/docker-uid-gid-setup.sh /usr/local/bin/docker-uid-gid-setup.sh

RUN set -x ; \
    CONFIG="\
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=${PUSER} \
    --group=${PGROUP} \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-http_perl_module=dynamic \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-compat \
    --with-file-aio \
    --with-http_v2_module \
    --add-module=/usr/src/nginx-auth-ldap \
  " ; \
  apk update --no-cache; \
  apk upgrade --no-cache; \
  apk add --no-cache curl shadow libressl; \
  addgroup -g ${DEFAULT_GID} -S ${PGROUP} ; \
  adduser -S -D -H -u ${DEFAULT_UID} -h /var/cache/nginx -s /sbin/nologin -G ${PGROUP} -g ${PUSER} ${PUSER} ; \
  addgroup ${PUSER} shadow ; \
  mkdir -p /var/cache/nginx ; \
  chown ${PUSER}:${PGROUP} /var/cache/nginx ; \
  apk add --no-cache --virtual .nginx-build-deps \
    gcc \
    gd-dev \
    geoip-dev \
    gnupg \
    libc-dev \
    libressl-dev \
    libxslt-dev \
    linux-headers \
    make \
    openldap-dev \
    pcre-dev \
    perl-dev \
    tar \
    zlib-dev \
    ; \
    \
  mkdir -p /usr/src/nginx-auth-ldap /www /www/logs/nginx ; \
  tar -zxC /usr/src -f /nginx.tar.gz ; \
  tar -zxC /usr/src/nginx-auth-ldap --strip=1 -f /nginx-auth-ldap.tar.gz ; \
  cd /usr/src/nginx-$NGINX_VERSION ; \
    ./configure $CONFIG --with-debug ; \
    make -j$(getconf _NPROCESSORS_ONLN) ; \
    mv objs/nginx objs/nginx-debug ; \
    mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so ; \
    mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so ; \
    mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so ; \
    mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so ; \
    mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so ; \
    ./configure $CONFIG ; \
    make -j$(getconf _NPROCESSORS_ONLN) ; \
    make install ; \
  rm -rf /etc/nginx/html/ ; \
  mkdir -p /etc/nginx/conf.d/ /usr/share/nginx/html/ ; \
    install -m644 html/index.html /usr/share/nginx/html/ ; \
    install -m644 html/50x.html /usr/share/nginx/html/ ; \
    install -m755 objs/nginx-debug /usr/sbin/nginx-debug ; \
    install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so ; \
    install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so ; \
    install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so ; \
    install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so ; \
    install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so ; \
  ln -s ../../usr/lib/nginx/modules /etc/nginx/modules ; \
  strip /usr/sbin/nginx* ; \
  strip /usr/lib/nginx/modules/*.so ; \
  rm -rf /usr/src/nginx-$NGINX_VERSION ; \
  \
  # Bring in gettext so we can get `envsubst`, then throw
  # the rest away. To do this, we need to install `gettext`
  # then move `envsubst` out of the way so `gettext` can
  # be deleted completely, then move `envsubst` back.
  apk add --no-cache --virtual .gettext gettext ; \
    mv /usr/bin/envsubst /tmp/ ; \
    \
    runDeps="$( \
      scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | sort -u \
        | xargs -r apk info --installed \
        | sort -u \
    )" ; \
  apk add --no-cache --virtual .nginx-rundeps $runDeps ca-certificates bash wget openssl apache2-utils openldap stunnel supervisor tzdata; \
  update-ca-certificates; \
  apk del .nginx-build-deps ; \
  apk del .gettext ; \
  mv /tmp/envsubst /usr/local/bin/ ; \
  rm -rf /usr/src/* /var/tmp/* /var/cache/apk/* /nginx.tar.gz /nginx-auth-ldap.tar.gz; \
  touch /etc/nginx/nginx_ldap.conf /etc/nginx/nginx_blank.conf && \
  ln -sf /dev/stdout /var/log/nginx/access.log && \
  ln -sf /dev/stderr /var/log/nginx/error.log && \
  chmod 755 /usr/local/bin/docker-uid-gid-setup.sh

ADD scripts /usr/local/bin/
ADD nginx/*.conf /etc/nginx/
ADD nginx/supervisord.conf /etc/

EXPOSE 80

VOLUME ["/etc/nginx/certs", "/etc/nginx/dhparam"]

ENTRYPOINT ["/usr/local/bin/docker-uid-gid-setup.sh", "/usr/local/bin/docker_entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisord.conf", "-u", "root", "-n"]


# to be populated at build-time:
ARG BUILD_DATE
ARG VCS_REVISION

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.revision=$VCS_REVISION
