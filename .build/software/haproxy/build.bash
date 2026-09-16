#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1

# Apply GitHub token if set
header=()
[[ $GH_TOKEN ]] && header=('-H' "Authorization: token $GH_TOKEN")

# APT dependencies
adeps_build=('make' 'gcc' 'libpcre2-dev' 'libssl-dev' 'libcrypt-dev')
adeps=('libc6' 'libpcre2-8-0' 'libcrypt1')
flags=()
# From OpenSSL 3.5 on, use USE_QUIC=1
# From OpenSSL 4.0 on, use USE_ECH=1 (currently in Debian experimental)
case $G_DISTRO in
	7) adeps+=('libssl3');;
	8) adeps+=('libssl3t64') flags+=('USE_QUIC=1');;
	9) adeps+=('libssl3t64') flags+=('USE_QUIC=1');;
	*) Error_Exit "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)";;
esac
G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	dpkg-query -s "$i" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

# Build
NAME='haproxy'
PRETTY='HAProxy'
url=$(curl -sSf "${header[@]}" 'https://www.haproxy.org/' | grep -Po 'href="\K/download/3\..*/src/haproxy-.*\.tar\.gz(?=")' | head -1)
version=${url##*haproxy-}; version=${version%.tar.gz}
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $PRETTY version found, aborting ..."; exit 1; }
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfO "https://www.haproxy.org$url"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$NAME-$version.tar.gz"
G_EXEC rm "$NAME-$version.tar.gz"
G_EXEC cd "$NAME-$version"
G_EXEC_OUTPUT=1 G_EXEC make -j "$(nproc)" TARGET='linux-glibc' USE_PCRE2=1 USE_PCRE2_JIT=1 USE_OPENSSL=1 USE_SLZ=1 USE_PROMEX=1 "${flags[@]}" CFLAGS='-g0 -O3' LDFLAGS='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed'
G_EXEC strip --remove-section=.comment --remove-section=.note "$NAME"
grep -q '^ID=raspbian' /etc/os-release && G_HW_ARCH_NAME='armv6l'
DIR="/tmp/${NAME}_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC_OUTPUT=1 G_EXEC make DESTDIR="$DIR" PREFIX='/usr' install

# Prepare DEB package
G_DIETPI-NOTIFY 2 "Building $PRETTY DEB package"
G_EXEC mkdir -p "$DIR"/{DEBIAN,etc/"$NAME"/errors,lib/systemd/system,var/lib/"$NAME"}

# - error pages
G_EXEC mv examples/errorfiles/*.http "$DIR"/etc/"$NAME"/errors/

# - service
G_EXEC_OUTPUT=1 G_EXEC make -C admin/systemd
G_EXEC mv {admin/systemd,"$DIR"/lib/systemd/system}/"$NAME".service

# - config
cat << '_EOF_' > "$DIR/etc/$NAME/$NAME.cfg" || exit 1
global
	maxconn 64
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets: https://configurator.tlsref.org/#server=haproxy&version=3.4.4&config=intermediate&openssl=3.0.20&guideline=6.0
	ssl-default-bind-curves X25519:prime256v1:secp384r1
	ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305
	ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
	ssl-default-bind-options prefer-client-ciphers ssl-min-ver TLSv1.2 no-tls-tickets

	ssl-default-server-curves X25519:prime256v1:secp384r1
	ssl-default-server-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305
	ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
	ssl-default-server-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
	log     global
	mode    http
	option  httplog
	option  dontlognull
	timeout connect 5000
	timeout client  50000
	timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

frontend localnodes
	bind *:80
	mode http
	default_backend nodes

backend nodes
	mode http
	balance roundrobin
	option forwardfor
	http-request set-header X-Forwarded-Port %[dst_port]
	http-request add-header X-Forwarded-Proto https if { ssl_fc }
	option httpchk HEAD / HTTP/1.1
	http-check send meth HEAD uri / ver HTTP/1.1 hdr host localhost
	server web01 127.0.0.1:9000 check
	server web02 127.0.0.1:9001 check
	server web03 127.0.0.1:9002 check

# Admin web page
	listen stats
	bind *:1338
	stats enable
	stats uri /
	http-request use-service prometheus-exporter if { path /metrics }
	stats hide-version
	stats auth admin:dietpi
_EOF_

# - conffiles
G_EXEC eval "echo '/etc/$NAME/$NAME.cfg' > '$DIR/DEBIAN/conffiles'"
for i in "$DIR/etc/$NAME/errors/"*.http; do G_EXEC eval "echo '${i#"$DIR"}' >> '$DIR/DEBIAN/conffiles'"; done

# - postinst
cat << _EOF_ > "$DIR/DEBIAN/postinst" || exit 1
#!/bin/dash -e
if [ -d '/run/systemd/system' ]
then
	if getent passwd $NAME > /dev/null
	then
		echo 'Configuring $PRETTY service user ...'
		[ ~$NAME = '/var/lib/$NAME' ] || systemctl stop $NAME
		usermod -d /var/lib/$NAME -s /usr/sbin/nologin $NAME
	else
		echo 'Creating $PRETTY service user ...'
		useradd -rMU -d /var/lib/$NAME -s /usr/sbin/nologin $NAME
	fi

	echo 'Configuring $PRETTY systemd service ...'
	systemctl --no-reload unmask $NAME
	systemctl enable $NAME
	systemctl restart $NAME
fi
_EOF_

# - prerm
cat << _EOF_ > "$DIR/DEBIAN/prerm" || exit 1
#!/bin/dash -e
if [ "\$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/$NAME.service' ]
then
	echo 'Deconfiguring $PRETTY systemd service ...'
	systemctl --no-reload unmask $NAME
	systemctl --no-reload disable --now $NAME
fi
_EOF_

# - postrm
cat << _EOF_ > "$DIR/DEBIAN/postrm" || exit 1
#!/bin/dash -e
if [ "\$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/$NAME.service.d' ]
	then
		echo 'Removing $PRETTY systemd service overrides ...'
		rm -Rv /etc/systemd/system/$NAME.service.d
	fi

	if [ -d '/etc/$NAME' ]
	then
		echo 'Removing $PRETTY config dir ...'
		rm -Rv /etc/$NAME
	fi

	if [ -d '/var/lib/$NAME' ]
	then
		echo 'Removing $PRETTY chroot dir ...'
		rm -Rv /var/lib/$NAME
	fi

	if getent passwd $NAME > /dev/null
	then
		echo 'Removing $PRETTY service user ...'
		userdel $NAME
	fi

	if getent group $NAME > /dev/null
	then
		echo 'Removing $PRETTY service group ...'
		groupdel $NAME
	fi
fi
_EOF_

# - md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums" || exit 1

# - Obtain DEB dependency versions
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
[[ $G_HW_ARCH_NAME == 'armv6l' ]] && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version suffix
if G_EXEC_NOHALT=1 G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${NAME}_$G_HW_ARCH_NAME.deb"
then
	old_version=$(dpkg-deb -f package.deb Version)
	G_EXEC rm package.deb
	suffix=${old_version#*-dietpi}
fi
[[ $old_version == "$version-dietpi"[1-9]* ]] && version+="-dietpi$((suffix+1))" || version+='-dietpi1'
G_DIETPI-NOTIFY 2 "Old package version is:       \e[33m$old_version"
G_DIETPI-NOTIFY 2 "Building new package version: \e[33m$version"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control" || exit 1
Package: $NAME
Version: $version
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: net
Priority: optional
Homepage: https://www.haproxy.org/
Description: fast and reliable load balancing reverse proxy
 HAProxy is a TCP/HTTP reverse proxy which is particularly suited for high
 availability environments. It features connection persistence through HTTP
 cookies, load balancing, header addition, modification, deletion both ways. It
 has request blocking capabilities and provides interface to display server
 status.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# - Permissions
G_EXEC chown -R 0:0 "$DIR"
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod 0600 "$DIR/etc/$NAME/$NAME.cfg"
G_EXEC chmod +x "$DIR/"{usr/sbin/*,DEBIAN/{postinst,prerm,postrm}}

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

exit 0
}
