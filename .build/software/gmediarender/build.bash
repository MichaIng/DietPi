#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

# Build deps
G_AGUP
G_AGDUG automake pkg-config gcc libc6-dev make libgstreamer1.0-dev libupnp-dev gstreamer1.0-alsa gstreamer1.0-libav gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
adeps=('libc6' 'gstreamer1.0-alsa' 'gstreamer1.0-libav' 'gstreamer1.0-plugins-good' 'gstreamer1.0-plugins-bad' 'gstreamer1.0-plugins-ugly')
(( $G_DISTRO > 7 )) && adeps+=('libupnp17') || adeps+=('libupnp13')
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

# Obtain latest version
name='gmediarender'
name_pretty='GMediaRender'
repo='https://github.com/hzeller/gmrender-resurrect'
version=$(curl -sSf 'https://api.github.com/repos/hzeller/gmrender-resurrect/releases/latest' | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $name_pretty version found, aborting ..."; exit 1; }

# Download
G_DIETPI-NOTIFY 2 "Downloading $name_pretty version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "$repo/archive/$version.tar.gz"
[[ -d gmrender-resurrect-${version#v} ]] && G_EXEC rm -R "gmrender-resurrect-${version#v}"
G_EXEC tar xf "$version.tar.gz"
G_EXEC rm "$version.tar.gz"
version=${version#v}

# Compile
G_DIETPI-NOTIFY 2 "Compiling $name_pretty"
G_EXEC cd "gmrender-resurrect-$version"
G_EXEC_OUTPUT=1 G_EXEC ./autogen.sh
CFLAGS='-g0 -O3' G_EXEC_OUTPUT=1 G_EXEC ./configure --prefix='/usr'
G_EXEC_OUTPUT=1 G_EXEC make
G_EXEC strip --remove-section=.comment --remove-section=.note "src/$name"

# Package dir: In case of Raspbian, force ARMv6
G_DIETPI-NOTIFY 2 "Preparing $name_pretty DEB package directory"
G_EXEC cd /tmp
grep -q '^ID=raspbian' /etc/os-release && G_HW_ARCH_NAME='armv6l'
DIR="gmediarender_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
# - Control files, config, systemd service, executable, icons, copyright
G_EXEC mkdir -p "$DIR/"{DEBIAN,etc/default,lib/systemd/system,usr/{bin,share/{,doc/}gmediarender}}

# Binary
G_EXEC mv "gmrender-resurrect-$version/src/gmediarender" "$DIR/usr/bin/"

# Copyright
G_EXEC cp "gmrender-resurrect-$version/COPYING" "$DIR/usr/share/doc/gmediarender/copyright"

# Icons
> "$DIR/usr/share/gmediarender/grender-64x64.png"
> "$DIR/usr/share/gmediarender/grender-128x128.png"

# systemd service
cat << '_EOF_' >  "$DIR/lib/systemd/system/$name.service"
[Unit]
Description=GMediaRender (DietPi)
Documentation=https://github.com/hzeller/gmrender-resurrect/blob/master/INSTALL.md#commandline-options
Wants=network-online.target
After=network-online.target sound.target

[Service]
User=gmediarender
EnvironmentFile=/etc/default/gmediarender
ExecStart=/usr/bin/gmediarender $ARGS

[Install]
WantedBy=multi-user.target
_EOF_

# Environment file
cat << '_EOF_' > "$DIR/etc/default/$name"
# GMediaRender command-line arguments: https://github.com/hzeller/gmrender-resurrect/blob/master/INSTALL.md#commandline-options
ARGS='-u UUID -f HOSTNAME -I eth0 --gstout-audiosink=alsasink --gstout-audiodevice=default --logfile=stdout'
_EOF_

# Control files

# - conffiles
echo "/etc/default/$name" > "$DIR/DEBIAN/conffiles"

# - postinst
cat << '_EOF_' > "$DIR/DEBIAN/postinst"
#!/bin/sh
if [ -d '/run/systemd/system' ]
then
	if [ -f '/etc/default/gmediarender' ] && grep -q '\-u UUID -f HOSTNAME -I eth0' /etc/default/gmediarender
	then
		echo 'Setting up environment file /etc/default/gmediarender ...'
		[ ! -f '/boot/dietpi/.hw_model' ] || . /boot/dietpi/.hw_model
		[ "$G_HW_UUID" ] || read -r G_HW_UUID < /proc/sys/kernel/random/uuid
		read -r HOSTNAME < /etc/hostname
		[ "$HOSTNAME" ] || HOSTNAME='DietPi'
		INTERFACE=$(ip r l 0/0 | awk '{print $5;exit}')
		[ "$INTERFACE" ] || INTERFACE=$(ip -br a | awk '$2=="UP"{print $1;exit}')
		[ "$INTERFACE" ] || exit 1
		sed --follow-symlinks -i "s/-u UUID -f HOSTNAME -I eth0/-u $G_HW_UUID -f $HOSTNAME -I $INTERFACE/" /etc/default/gmediarender
	fi

	if getent passwd gmediarender > /dev/null
	then
		echo 'Configuring GMediaRender service user ...'
		usermod -aG audio -d /nonexistent -s /usr/sbin/nologin gmediarender
	else
		echo 'Creating GMediaRender service user ...'
		useradd -rMU -G audio -d /nonexistent -s /usr/sbin/nologin gmediarender
	fi

	echo 'Configuring GMediaRender systemd service ...'
	systemctl unmask gmediarender
	systemctl enable --now gmediarender
fi
_EOF_

# - prerm
cat << _EOF_ > "$DIR/DEBIAN/prerm"
#!/bin/sh
if [ "\$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/$name.service' ]
then
	echo 'Deconfiguring $name_pretty systemd service ...'
	systemctl unmask $name
	systemctl disable --now $name
fi
_EOF_

# - postrm
cat << _EOF_ > "$DIR/DEBIAN/postrm"
#!/bin/sh
if [ "\$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/$name.service.d' ]
	then
		echo 'Removing $name_pretty systemd service overrides ...'
		rm -Rv /etc/systemd/system/$name.service.d
	fi

	if getent passwd $name > /dev/null
	then
		echo 'Removing $name_pretty service user ...'
		userdel $name
	fi

	if getent group $name > /dev/null
	then
		echo 'Removing $name_pretty service group ...'
		groupdel $name
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

# - Obtain version suffix
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${name}_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && suffix="dietpi$((suffix+1))" || suffix="dietpi1"

# control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: $name
Version: $version-$suffix
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: sound
Priority: optional
Homepage: $repo
Description: Minimalist UPNP AV renderer
 gmrender-resurrect is a minimalist UPNP AV renderer that can be used to
 play music controlled by a UPNP AV control point.  This package contains
 only a renderer and will therefore require these things to be installed
 either on this device or another device on the local network in order to
 be usable.  gmrender-resurrect usese GStreamer to provide the
 infrastructure for playing music.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

# Cleanup
G_EXEC rm -R "gmrender-resurrect-$version" "$DIR"

exit 0
}
