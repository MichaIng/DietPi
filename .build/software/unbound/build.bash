#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1

# Apply GitHub token if set
header=()
[[ $GH_TOKEN ]] && header=('-H' "Authorization: token $GH_TOKEN")

# APT dependencies
adeps_build=('make' 'gcc' 'bison' 'flex' 'file' 'pkg-config' 'libc6-dev' 'libsystemd-dev' 'libssl-dev' 'libevent-dev' 'libexpat1-dev' 'libhiredis-dev' 'libnghttp2-dev' 'protobuf-c-compiler' 'libprotobuf-c-dev' 'dns-root-data')
adeps=('libc6' 'libsystemd0' 'libevent-2.1-7' 'libnghttp2-14' 'libprotobuf-c1' 'dns-root-data')
(( $G_DISTRO > 6 )) && adeps+=('libssl3') || adeps+=('libssl1.1')
(( $G_DISTRO > 7 )) && adeps+=('libhiredis1.1.0') || adeps+=('libhiredis0.14')

G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	# Trixie library package names often have a t64 suffix due to 64-but time_t transition: https://wiki.debian.org/ReleaseGoals/64bit-time
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

# Build
NAME='unbound'
ORGA='NLnetLabs'
PRETTY='Unbound'
version=$(curl -sSf "${header[@]}" "https://api.github.com/repos/$ORGA/$NAME/releases/latest" | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $PRETTY version found, aborting ..."; exit 1; }
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m${version#release-}"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/$ORGA/$NAME/archive/$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$version.tar.gz"
G_EXEC rm "$version.tar.gz"
G_EXEC cd "$NAME-$version"
version=${version#release-}
CFLAGS='-g0 -O3' G_EXEC_OUTPUT=1 G_EXEC ./configure --enable-checking --prefix='/usr' --sysconfdir='/etc' --localstatedir='/var' --runstatedir='/run' --without-{pyunbound,pythonmodule} --enable-{systemd,subnet,cachedb,dnstap,tfo-client,tfo-server} --with-{libhiredis,libnghttp2,chroot-dir='',dnstap-socket-path='/run/dnstap.sock',libevent,pthreads,rootkey-file='/usr/share/dns/root.key'} --disable-rpath
G_EXEC_OUTPUT=1 G_EXEC make
G_EXEC strip --remove-section=.comment --remove-section=.note "$NAME"{,-checkconf,-control}
DIR="/tmp/${NAME}_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC_OUTPUT=1 G_EXEC make DESTDIR="$DIR" install

# Prepare DEB package
G_DIETPI-NOTIFY 2 "Building $PRETTY DEB package"
# shellcheck disable=SC2046
G_EXEC rm -R $(find "$DIR" -name '*unbound-anchor*' -o -name '*unbound-host*') "$DIR/usr/"{share/man/man[13],include,lib}
G_EXEC mkdir -p "$DIR/"{DEBIAN,etc/unbound/unbound.conf.d,share/doc/unbound/examples,lib/systemd/system}

# - configs
G_EXEC mv "$DIR/"{etc/unbound/unbound.conf,share/doc/unbound/examples/}
cat << '_EOF_' > "$DIR/etc/unbound/unbound.conf" || exit 1
# Unbound configuration file for Debian.
#
# See the unbound.conf(5) man page.
#
# See /usr/share/doc/unbound/examples/unbound.conf for a commented
# reference config file.
#
# The following line includes additional configuration files from the
# /etc/unbound/unbound.conf.d directory.
include-toplevel: "/etc/unbound/unbound.conf.d/*.conf"
_EOF_

cat << '_EOF_' > "$DIR/etc/unbound/unbound.conf.d/remote-control.conf" || exit 1
remote-control:
  control-enable: yes
  # by default the control interface is is 127.0.0.1 and ::1 and port 8953
  # it is possible to use a unix socket too
  control-interface: /run/unbound.ctl
_EOF_

cat << '_EOF_' > "$DIR/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf" || exit 1
server:
    # The following line will configure unbound to perform cryptographic
    # DNSSEC validation using the root trust anchor.
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
_EOF_

cat << '_EOF_' > "$DIR/etc/unbound/unbound.conf.d/dietpi.conf" || exit 1
# https://nlnetlabs.nl/documentation/unbound/unbound.conf/
server:
	# Do not daemonize, to allow proper systemd service control and status estimation.
	do-daemonize: no

	# A single thread is pretty sufficient for home or small office instances.
	num-threads: 1

	# Logging: For the sake of privacy and performance, keep logging at a minimum!
	# - Verbosity 2 and up practically contains query and reply logs.
	verbosity: 0
	log-queries: no
	log-replies: no
	# - If required, uncomment to log to a file, else logs are available via "journalctl -u unbound".
	#logfile: "/var/log/unbound.log"

	# Set interface to "0.0.0.0" to make Unbound listen on all network interfaces.
	# Set it to "127.0.0.1" to listen on requests from the same machine only, useful in combination with Pi-hole.
	interface: 0.0.0.0
	# Default DNS port is "53". When used with Pi-hole, set this to e.g. "5335", since "5353" is used by mDNS already.
	port: 53

	# Control IP ranges which should be able to use this Unbound instance.
	# The DietPi defaults permit access from official local network IP ranges only, hence requests from www are denied.
	access-control: 0.0.0.0/0 refuse
	access-control: 10.0.0.0/8 allow
	access-control: 127.0.0.1/8 allow
	access-control: 172.16.0.0/12 allow
	access-control: 192.168.0.0/16 allow
	access-control: ::/0 refuse
	access-control: ::1/128 allow
	access-control: fd00::/8 allow
	access-control: fe80::/10 allow

	# Private IP ranges, which shall never be returned or forwarded as public DNS response.
	# NB: 127.0.0.1/8 is sometimes used by adblock lists, hence DietPi by default allows those as response.
	private-address: 10.0.0.0/8
	private-address: 172.16.0.0/12
	private-address: 192.168.0.0/16
	private-address: 169.254.0.0/16
	private-address: fd00::/8
	private-address: fe80::/10

	# Define protocols for connections to and from Unbound.
	# NB: Disabling IPv6 does not disable IPv6 IP resolving, which depends on the clients request.
	do-udp: yes
	do-tcp: yes
	do-ip4: yes
	do-ip6: yes

	# Maximum number of queries per second
	ratelimit: 1000

	# Defend against and print warning when reaching unwanted reply limit.
	unwanted-reply-threshold: 10000

	# Set EDNS reassembly buffer size to match new upstream default, as of DNS Flag Day 2020 recommendation.
	edns-buffer-size: 1232

	# Disable ECS module, matching new Unbound defaults, and mute 2 warnings: https://github.com/NLnetLabs/unbound/commit/35dbbcb, https://github.com/MichaIng/DietPi/issues/7539#issuecomment-2906900497
	module-config: "validator iterator"

	# Increase incoming and outgoing query buffer size to cover traffic peaks.
	so-rcvbuf: 4m
	so-sndbuf: 4m

	# Hardening
	harden-glue: yes
	harden-dnssec-stripped: yes
	harden-algo-downgrade: yes
	harden-large-queries: yes
	harden-short-bufsize: yes

	# Privacy
	use-caps-for-id: yes # Spoof protection by randomising capitalisation
	rrset-roundrobin: yes
	qname-minimisation: yes
	minimal-responses: yes
	hide-identity: yes
	identity: "Server" # Purposefully a dummy identity name
	hide-version: yes

	# Caching
	cache-min-ttl: 300
	cache-max-ttl: 86400
	serve-expired: yes
	neg-cache-size: 4M
	prefetch: yes
	prefetch-key: yes
	msg-cache-size: 50m
	rrset-cache-size: 100m
_EOF_

# - conffiles
cat << '_EOF_' > "$DIR/DEBIAN/conffiles" || exit 1
/etc/unbound/unbound.conf
/etc/unbound/unbound.conf.d/remote-control.conf
/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf
/etc/unbound/unbound.conf.d/dietpi.conf
_EOF_

# - service
cat << _EOF_ > "$DIR/lib/systemd/system/$NAME.service" || exit 1
[Unit]
Description=Unbound DNS server
Documentation=man:unbound(8)
Wants=network-online.target nss-lookup.target
After=network-online.target
Before=nss-lookup.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=notify
ExecStart=/usr/sbin/$NAME -d -p
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
_EOF_

# - postinst
cat << _EOF_ > "$DIR/DEBIAN/postinst" || exit 1
#!/bin/dash -e
if ! ip -6 r l ::/0 > /dev/null && [ -f '/etc/unbound/unbound.conf.d/dietpi.conf' ] && grep -q '^	do-ip6: yes$' /etc/unbound/unbound.conf.d/dietpi.conf
then
	echo 'Disabling $PRETTY IPv6 usage since no IPv6 default route is assigned'
	sed --follow-symlinks -i 's/^	do-ip6: yes$/	do-ip6: no/' /etc/unbound/unbound.conf.d/dietpi.conf
fi

if [ -d '/run/systemd/system' ]
then
	if getent passwd $NAME > /dev/null
	then
		echo 'Configuring $PRETTY service user ...'
		usermod -d /var/lib/$NAME -s /usr/sbin/nologin $NAME
	else
		echo 'Creating $PRETTY service user ...'
		useradd -rMU -d /var/lib/$NAME -s /usr/sbin/nologin $NAME
	fi

	echo 'Setting up $PRETTY data dir ...'
	mkdir -pm 0755 /var/lib/$NAME
	chown -R '$NAME:$NAME' /var/lib/$NAME

	if [ ! -f '/var/lib/$NAME/root.key' ]
	then
		echo 'Bootstrapping root trust anchors /var/lib/$NAME/root.key from /usr/share/dns/root.key ...'
		setpriv --reuid=$NAME --regid=$NAME --clear-groups cp -v /usr/share/dns/root.key /var/lib/$NAME/
	fi

	if [ -f '/etc/init.d/$NAME' ]
	then
		echo 'Removing obsolete $PRETTY SysV service'
		rm /etc/init.d/$NAME
		update-rc.d $NAME remove
	fi

	echo 'Configuring $PRETTY systemd service ...'
	systemctl unmask $NAME
	systemctl --no-reload enable $NAME
	systemctl restart $NAME
fi
_EOF_

# - prerm
cat << _EOF_ > "$DIR/DEBIAN/prerm" || exit 1
#!/bin/dash -e
if [ "$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/$NAME.service' ]
then
	echo 'Deconfiguring $PRETTY systemd service ...'
	systemctl unmask $NAME
	systemctl --no-reload disable --now $NAME
fi
_EOF_

# - postrm
cat << _EOF_ > "$DIR/DEBIAN/postrm" || exit 1
#!/bin/dash -e
if [ "$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/$NAME.service.d' ]
	then
		echo 'Removing $PRETTY systemd service overrides ...'
		rm -rv /etc/systemd/system/$NAME.service.d
	fi

	if [ -d '/etc/$NAME' ]
	then
		echo 'Removing auto-generated TLS keys and certificates'
		rm -fv /etc/unbound/unbound_control.key /etc/unbound/unbound_control.pem /etc/unbound/unbound_server.key /etc/unbound/unbound_server.pem
		rmdir --ignore-fail-on-non-empty -v /etc/$NAME
	fi

	if [ -d '/var/lib/$NAME' ]
	then
		echo 'Removing $PRETTY data dir ...'
		rm -rv /var/lib/$NAME
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
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums"

# - Obtain DEB dependency versions
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Trixie: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
[[ $G_HW_ARCH_NAME == 'armv6l' ]] && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version suffix
G_EXEC_NOHALT=1 G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${NAME}_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC_NOHALT=1 G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && version+="-dietpi$((suffix+1))" || version+="-dietpi1"
G_DIETPI-NOTIFY 2 "Old package version is:       \e[33m$old_version"
G_DIETPI-NOTIFY 2 "Building new package version: \e[33m$version"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: $NAME
Version: $version
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: net
Priority: optional
Homepage: https://www.unbound.net/
Description: validating, recursive, and caching DNS resolver
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# - Permissions
G_EXEC chown -R 0:0 "$DIR"
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/"{"usr/sbin/$NAME"{,-checkconf,-control,-control-setup},DEBIAN/{postinst,prerm,postrm}}

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

exit 0
}
