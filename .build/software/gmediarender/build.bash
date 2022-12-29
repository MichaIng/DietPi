#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals

G_AGUP
G_AGDUG

# Build deps
G_AGI automake pkg-config gcc libc6-dev make libgstreamer1.0-dev libupnp-dev gstreamer1.0-alsa gstreamer1.0-libav gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly

# Download
version='0.0.9' # https://github.com/hzeller/gmrender-resurrect/releases
G_DIETPI-NOTIFY 2 "Downloading GMediaRender version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/hzeller/gmrender-resurrect/archive/v$version.tar.gz"
[[ -d gmrender-resurrect-$version ]] && G_EXEC rm -R "gmrender-resurrect-$version"
G_EXEC tar xf "v$version.tar.gz"
G_EXEC rm "v$version.tar.gz"

# Build
G_DIETPI-NOTIFY 2 'Compiling GMediaRender'
G_EXEC cd "gmrender-resurrect-$version"
G_EXEC_OUTPUT=1 G_EXEC ./autogen.sh
CFLAGS='-g0 -O3' G_EXEC_OUTPUT=1 G_EXEC ./configure --prefix='/usr'
G_EXEC_OUTPUT=1 G_EXEC make
G_EXEC strip --remove-section=.comment --remove-section=.note src/gmediarender

# Preparing DEB package
G_DIETPI-NOTIFY 2 'Building GMediaRender DEB package'
G_EXEC cd /tmp
grep -q 'raspbian' /etc/os-release && DIR='gmediarender_armv6l' || DIR="gmediarender_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,usr/{bin,share/{,doc/}gmediarender},lib/systemd/system,etc/default}

# Binary
G_EXEC mv "gmrender-resurrect-$version/src/gmediarender" "$DIR/usr/bin/"

# Copyright
G_EXEC cp "gmrender-resurrect-$version/COPYING" "$DIR/usr/share/doc/gmediarender/copyright"

# Cleanup
G_EXEC rm -R "gmrender-resurrect-$version"

# Icons
> "$DIR/usr/share/gmediarender/grender-64x64.png"
> "$DIR/usr/share/gmediarender/grender-128x128.png"

# systemd service
cat << '_EOF_' >  "$DIR/lib/systemd/system/gmediarender.service"
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
cat << '_EOF_' > "$DIR/etc/default/gmediarender"
# GMediaRender command-line arguments: https://github.com/hzeller/gmrender-resurrect/blob/master/INSTALL.md#commandline-options
ARGS='-u UUID -f HOSTNAME -I eth0 --gstout-audiosink=alsasink --gstout-audiodevice=default --logfile=stdout'
_EOF_

# postinst
cat << '_EOF_' > "$DIR/DEBIAN/postinst"
#!/bin/bash
if [[ -d '/run/systemd/system' ]]
then
	if [[ -f '/etc/default/gmediarender' ]] && grep -q '\-u UUID -f HOSTNAME -I eth0' /etc/default/gmediarender
	then
		echo 'Setting up environment file /etc/default/gmediarender ...'
		[[ ! -f '/boot/dietpi/.hw_model' ]] || . /boot/dietpi/.hw_model
		UUID=${G_HW_UUID:-$(</proc/sys/kernel/random/uuid)}
		INTERFACE=$(ip r l 0/0 | awk '{print $5;exit}')
		[[ $INTERFACE ]] || INTERFACE=$(ip -br a | awk '$2=="UP"{print $1;exit}')
		[[ $INTERFACE ]] || exit 1
		sed -i "s/-u UUID -f HOSTNAME -I eth0/-u $UUID -f $HOSTNAME -I $INTERFACE/" /etc/default/gmediarender
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

# prerm
cat << '_EOF_' > "$DIR/DEBIAN/prerm"
#!/bin/sh
if [ "$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/gmediarender.service' ]
then
	echo 'Deconfiguring GMediaRender systemd service ...'
	systemctl unmask gmediarender
	systemctl disable --now gmediarender
fi
_EOF_

# postrm
cat << '_EOF_' > "$DIR/DEBIAN/postrm"
#!/bin/sh
if [ "$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/gmediarender.service.d' ]
	then
		echo 'Removing GMediaRender systemd service overrides ...'
		rm -Rv /etc/systemd/system/gmediarender.service.d
	fi

	if getent passwd gmediarender > /dev/null
	then
		echo 'Removing GMediaRender service user ...'
		userdel gmediarender
	fi

	if getent group gmediarender > /dev/null
	then
		echo 'Removing GMediaRender service group ...'
		groupdel gmediarender
	fi
fi
_EOF_
G_EXEC chmod +x "$DIR/DEBIAN/"{postinst,prerm,postrm}

# conffiles
echo '/etc/default/gmediarender' > "$DIR/DEBIAN/conffiles"

# md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums"

# Add dependencies
adeps=('libc6' 'gstreamer1.0-alsa' 'gstreamer1.0-libav' 'gstreamer1.0-plugins-good' 'gstreamer1.0-plugins-bad' 'gstreamer1.0-plugins-ugly' 'libupnp13')
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
grep -q 'raspbian' /etc/os-release && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: gmediarender
Version: $version-dietpi1
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -u '+%a, %d %b %Y %T %z')
Standards-Version: 4.6.2.0
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: sound
Priority: optional
Homepage: https://github.com/hzeller/gmrender-resurrect
Vcs-Git: https://github.com/hzeller/gmrender-resurrect.git
Vcs-Browser: https://github.com/hzeller/gmrender-resurrect
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
[[ -f $DIR.deb ]] && G_EXEC rm -R "$DIR.deb"
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"
G_EXEC rm -R "$DIR"

exit 0
}