#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Build deps
G_AGUP
G_AGDUG cmake make gcc libc6-dev pkg-config libmpdclient-dev libssl-dev

# Runtime deps
adeps=('libc6' 'libmpdclient2')
case $G_DISTRO in
	6) adeps+=('libssl1.1');;
	7|8) adeps+=('libssl3');;
	*) G_DIETPI-NOTIFY 1 "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)"; exit 1;;
esac
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

G_DIETPI-NOTIFY 2 'Downloading source code...'
G_EXEC cd /tmp
G_EXEC curl -sSfLO 'https://github.com/SuperBFG7/ympd/archive/master.tar.gz'
[[ -d 'ympd-master' ]] && G_EXEC rm -R ympd-master
G_EXEC tar xf master.tar.gz
G_EXEC rm master.tar.gz
G_DIETPI-NOTIFY 2 'Compiling binary...'
G_EXEC mkdir ympd-master/build
G_EXEC cd ympd-master/build
G_EXEC_OUTPUT=1 G_EXEC cmake ..
G_EXEC_OUTPUT=1 G_EXEC make CFLAGS='-g0 -O3'
G_EXEC strip --remove-section=.comment --remove-section=.note ympd

G_DIETPI-NOTIFY 2 'Starting packaging...'

# Package dir
G_EXEC cd /tmp
grep -q '^ID=raspbian' /etc/os-release && G_HW_ARCH_NAME='armv6l'
DIR="ympd_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,lib/systemd/system,usr/{bin,share/man/man1}}

# - Binary
G_EXEC cp ympd-master/build/ympd "$DIR/usr/bin/"

# - man page
# shellcheck disable=SC2016
G_EXEC eval 'gzip -c ympd-master/ympd.1 > $DIR/usr/share/man/man1/ympd.1.gz'

# - systemd service
cat << '_EOF_' > "$DIR/lib/systemd/system/ympd.service"
[Unit]
Description=ympd (DietPi)
After=mpd.service

[Service]
User=ympd
ExecStart=/usr/bin/ympd -h /run/mpd/socket -w 1337

# Hardenings
ProtectSystem=strict
PrivateTmp=true
ProtectHome=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
_EOF_

# - postinst
cat << '_EOF_' > "$DIR/DEBIAN/postinst"
#!/bin/sh
if [ -d '/run/systemd/system' ]
then
	if getent passwd ympd > /dev/null
	then
		echo 'Configuring ympd service user ...'
		usermod -g dietpi -d /nonexistent -s /usr/sbin/nologin ympd
	else
		echo 'Creating ympd service user ...'
		useradd -rMN -g dietpi -d /nonexistent -s /usr/sbin/nologin ympd
	fi

	echo 'Configuring ympd systemd service ...'
	systemctl unmask ympd
	systemctl enable --now ympd
fi
_EOF_

# - prerm
cat << '_EOF_' > "$DIR/DEBIAN/prerm"
#!/bin/sh
if [ "$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/ympd.service' ]
then
	echo 'Deconfiguring ympd systemd service ...'
	systemctl unmask ympd
	systemctl disable --now ympd
fi
_EOF_

# - postrm
cat << '_EOF_' > "$DIR/DEBIAN/postrm"
#!/bin/sh
if [ "$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/ympd.service.d' ]
	then
		echo 'Removing ympd systemd service overrides ...'
		rm -Rv /etc/systemd/system/ympd.service.d
	fi

	if getent passwd ympd > /dev/null
	then
		echo 'Removing ympd service user ...'
		userdel ympd
	fi

	if getent group ympd > /dev/null
	then
		echo 'Removing ympd service group ...'
		groupdel ympd
	fi
fi
_EOF_
G_EXEC chmod +x "$DIR/DEBIAN/"{postinst,prerm,postrm}

# - md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums"

# - Obtain DEB dependency versions
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
[[ $G_HW_ARCH_NAME == 'armv6l' ]] && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version
version="$(mawk -F\" '/CPACK_PACKAGE_VERSION_MAJOR/{print $2;exit}' ympd-master/CMakeLists.txt).$(mawk -F\" '/CPACK_PACKAGE_VERSION_MINOR/{print $2;exit}' ympd-master/CMakeLists.txt).$(mawk -F\" '/CPACK_PACKAGE_VERSION_PATCH/{print $2;exit}' ympd-master/CMakeLists.txt)"
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/ympd_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && suffix="dietpi$((suffix+1))" || suffix="dietpi1"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: ympd
Version: $version-$suffix
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: sound
Priority: optional
Homepage: https://github.com/SuperBFG7/ympd
Description: Standalone MPD Web GUI written in C, utilizing Websockets and Bootstrap/JS
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

# Cleanup
G_EXEC rm -R "$DIR"

exit 0
}