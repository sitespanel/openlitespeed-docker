# OpenLiteSpeed with LSPHP for one PHP version (TASK-0198, step 2; ADR-0044). This is the Dockerfile for the founder's image repository
# (openlitespeed-docker, published to europe-docker.pkg.dev/PROJECT/sitespanel-images/openlitespeed); it is kept here so the contract in image-manifest/images.yaml and the
# conditions of the security test (planning/reports/2026-10-31T0200-openlitespeed-lscgid-security-test.md) are checked against the same text.
#
#   docker build --build-arg PHP_MM=84 --build-arg PHP_VERSION=8.4.27-1+resolute -t europe-docker.pkg.dev/PROJECT/sitespanel-images/openlitespeed:8.4 images/openlitespeed
#
# Licences: OpenLiteSpeed is GPL-3.0+ (its package says so), LSPHP is the PHP License, the extensions have their own (see /usr/share/licenses/openlitespeed-image).
# The packages come from LiteSpeed's apt repository, unmodified; the corresponding source of OpenLiteSpeed is
# https://github.com/litespeedtech/openlitespeed at the tag of the version below, and is available on request (see the image labels).
FROM ubuntu:26.04@sha256:c098726dd9b9733f3e885f8de0ef375206a311b0a317eadc40d347b1115fb944

# The repository's signing key is checked against this fingerprint (RSA 4096, 2016). LiteSpeed's setup script downloads keys over plain HTTP
# with no check; this does not. The older DSA 1024 key the repository also lists is not trusted.
ARG LITESPEED_KEY_FPR=3E892522DB44E1B063D366C5011AA62DEDA1F085
ARG OLS_VERSION=1.9.4-2+resolute
ARG PHP_MM=84
ARG PHP_VERSION=8.4.27-1+resolute
ARG APCU_VERSION=5.1.28-1+resolute
ARG IMAGICK_VERSION=3.8.1-1+resolute
ARG REDIS_VERSION=6.3.0-1+resolute
ARG IGBINARY_VERSION=3.2.16-1+resolute
# Server user and group: ids no site ever runs as (sites start at 20000); each site's lsphp runs as the site's own ids, set per virtual host
# (condition 1 of the security test).
ARG SERVER_ID=991

RUN set -eu; \
    apt-get update -qq; \
    apt-get install -y -qq --no-install-recommends ca-certificates curl gnupg >/dev/null; \
    curl -fsS http://rpms.litespeedtech.com/debian/lst_repo.gpg -o /tmp/lst_repo.gpg; \
    gpg --show-keys --with-colons /tmp/lst_repo.gpg | awk -F: '/^fpr/{print $10; exit}' | grep -qx "$LITESPEED_KEY_FPR"; \
    gpg --dearmor < /tmp/lst_repo.gpg > /usr/share/keyrings/litespeed.gpg; \
    . /etc/os-release; \
    echo "deb [signed-by=/usr/share/keyrings/litespeed.gpg] http://rpms.litespeedtech.com/debian/ $VERSION_CODENAME main" > /etc/apt/sources.list.d/litespeed.list; \
    apt-get update -qq; \
    apt-get install -y -qq --no-install-recommends \
      "openlitespeed=$OLS_VERSION" \
      "lsphp$PHP_MM=$PHP_VERSION" "lsphp$PHP_MM-common=$PHP_VERSION" "lsphp$PHP_MM-mysql=$PHP_VERSION" "lsphp$PHP_MM-curl=$PHP_VERSION" \
      "lsphp$PHP_MM-intl=$PHP_VERSION" "lsphp$PHP_MM-opcache=$PHP_VERSION" \
      "lsphp$PHP_MM-apcu=$APCU_VERSION" "lsphp$PHP_MM-imagick=$IMAGICK_VERSION" "lsphp$PHP_MM-redis=$REDIS_VERSION" "lsphp$PHP_MM-igbinary=$IGBINARY_VERSION" >/dev/null; \
    # openlitespeed brings LSPHP 8.3 by default; only the version this image is for stays.
    for v in 83 84 85; do [ "$v" = "$PHP_MM" ] || rm -rf "/usr/local/lsws/lsphp$v"; done; \
    # No admin console (condition 3), no demo virtual host, no documentation, no add-ons, no installer helpers (no acme.sh, no WP-CLI here). The server
    # refuses to start without an "admin virtual host" and a listener for it (found in step 2), so a skeleton stays: no pages, no scripts, no password
    # file, no keys, and a listener on the container's loopback only that answers 404 or 403 to everything.
    rm -rf /usr/local/lsws/Example /usr/local/lsws/docs /usr/local/lsws/add-ons /usr/local/lsws/phpbuild /usr/local/lsws/lsrecaptcha \
           /usr/local/lsws/conf/vhosts /usr/local/lsws/conf/templates; \
    cd /usr/local/lsws/admin; \
    rm -rf html html.open html.disabled fcgi-bin misc conf/htpasswd conf/webadmin.crt conf/webadmin.key conf/php.ini; \
    printf 'enableCoreDump 0\nsessionTimeout 3600\naccessControl {\n  allow 127.0.0.1\n}\nlistener adminListener{\n  address 127.0.0.1:7080\n  secure 0\n}\n' > conf/admin_config.conf; \
    chown lsadm:lsadm conf/admin_config.conf; chmod 640 conf/admin_config.conf; cd /; \
    # The PHP License text, which the LSPHP package does not ship, taken from PHP itself, and the packages' own licence files.
    mkdir -p /usr/share/licenses/openlitespeed-image; \
    "/usr/local/lsws/lsphp$PHP_MM/bin/php" -r 'phpinfo(INFO_LICENSE);' > /usr/share/licenses/openlitespeed-image/PHP-LICENSE.txt; \
    cp /usr/local/lsws/share/doc/openlitespeed/copyright /usr/share/licenses/openlitespeed-image/OPENLITESPEED-COPYRIGHT.txt; \
    cp /usr/local/lsws/GPL.txt /usr/share/licenses/openlitespeed-image/GPL-3.0.txt; \
    dpkg-query -W -f='${Package} ${Version}\n' openlitespeed "lsphp$PHP_MM" "lsphp$PHP_MM-common" > /usr/share/licenses/openlitespeed-image/PACKAGES.txt; \
    # The lsphp command line is the image's `php` (shell, cron and the manifest's extension list use it).
    ln -s "/usr/local/lsws/lsphp$PHP_MM/bin/php" /usr/local/bin/php; \
    # Dedicated server user and group.
    groupadd -r -g "$SERVER_ID" ols; \
    useradd -r -u "$SERVER_ID" -g "$SERVER_ID" -M -d /nonexistent -s /usr/sbin/nologin ols; \
    # The package hands its working directories to the group nogroup (also the group of "nobody", where the shipped default runs site code); they go to ols.
    gpasswd -d lsadm nogroup >/dev/null; usermod -aG ols lsadm; \
    chgrp -R ols /usr/local/lsws/logs /usr/local/lsws/admin/cgid /usr/local/lsws/admin/logs /usr/local/lsws/admin/tmp /usr/local/lsws/conf; \
    chown -R ols:ols /usr/local/lsws/tmp /usr/local/lsws/cgid /usr/local/lsws/cachedata; \
    apt-get purge -y -qq curl gnupg >/dev/null; apt-get autoremove -y -qq >/dev/null; \
    rm -rf /var/lib/apt/lists/* /tmp/lst_repo.gpg /etc/apt/sources.list.d/litespeed.list /usr/share/keyrings/litespeed.gpg

# The idle configuration and account files: exactly what the panel's agent renders for a container with no site yet (internal/agent/ols, kept equal by
# a test). The agent mounts the site's own versions of these two folders over them. The server's main configuration and the container's accounts are
# links into them, because the root is read-only and a site's PHP user has no entry in the image: OpenLiteSpeed looks the user up by name and, when it
# is not found, silently runs PHP as the server's own user.
COPY --chown=root:ols --chmod=0640 site/ /usr/local/lsws/site/
COPY --chmod=0644 nss/ /usr/local/lsws/nss/
COPY --chmod=0755 ols-run /usr/local/bin/ols-run
RUN mkdir /usr/local/lsws/idle-html && chmod 0755 /usr/local/lsws/idle-html /usr/local/lsws/nss && chmod 0750 /usr/local/lsws/site; \
    rm -rf /usr/local/lsws/conf/vhosts /usr/local/lsws/conf/httpd_config.conf; \
    ln -s /usr/local/lsws/site/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf; \
    rm /etc/passwd /etc/group; \
    ln -s /usr/local/lsws/nss/passwd /etc/passwd; ln -s /usr/local/lsws/nss/group /etc/group

LABEL org.opencontainers.image.title="OpenLiteSpeed with LSPHP" \
      org.opencontainers.image.licenses="GPL-3.0-or-later AND PHP-3.01" \
      org.opencontainers.image.source="https://github.com/litespeedtech/openlitespeed" \
      org.opencontainers.image.description="Unmodified OpenLiteSpeed and LSPHP packages from LiteSpeed's apt repository. The corresponding source of OpenLiteSpeed is at the source URL at the tag of the installed version, and the Dockerfile that built this image is public; the corresponding source is also available on request from the image's publisher." \
      io.sitespanel.web-server="openlitespeed"

# The panel's agent starts the container with a small init (for SIGUSR1/SIGTERM), a read-only root, only the capabilities in ADR-0044 and the folders the
# server writes as volumes (TASK-0198, step 3). Until the agent writes its configuration (step 4) the server serves nothing.
CMD ["/usr/local/bin/ols-run"]
