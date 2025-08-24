#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1
Error_Exit(){ G_DIETPI-NOTIFY 1 "$1, aborting ..."; exit 1; }

# Apply GitHub token if set
header=()
[[ $GH_TOKEN ]] && header=('-H' "Authorization: token $GH_TOKEN")

# APT dependencies
adeps_build=('git' 'cmake' 'make' 'g++' 'libssl-dev' 'liblua5.3-dev' 'python3-dev' 'libsqlite3-dev' 'libboost-system-dev' 'libboost-thread-dev' 'libcurl4-openssl-dev' 'libusb-dev')
adeps=('libc6' 'libsqlite3-0' 'libusb-0.1-4')
case $G_DISTRO in
	6) adeps+=('libssl1.1' 'libcurl4');;
	7) adeps+=('libssl3' 'libcurl4');;
	8|9) adeps+=('libssl3t64' 'libcurl4t64');;
	*) Error_Exit "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)";;
esac

G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	dpkg-query -s "$i" &> /dev/null || Error_Exit "Expected dependency package was not installed: $i"
done

G_DIETPI-NOTIFY 2 'Building OpenZWave'
G_EXEC cd /tmp
# Full clone needed for "git describe", used in build to obtain full version string
G_EXEC_OUTPUT=1 G_EXEC git clone 'https://github.com/domoticz/open-zwave' open-zwave-read-only
G_EXEC cd open-zwave-read-only
G_EXEC_OUTPUT=1 G_EXEC make

# Build
NAME='domoticz'
ORGA='domoticz'
PRETTY='Domoticz'
version=$(curl -sSf "${header[@]}" "https://api.github.com/repos/$ORGA/$NAME/releases/latest" | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $version ]] || Error_Exit "No latest $PRETTY version found"
branch='development' # Temporary
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
[[ -d $NAME ]] && G_EXEC rm -R "$NAME"
G_EXEC_OUTPUT=1 G_EXEC git clone --depth=1 --recurse-submodules --shallow-submodules -b "$branch" "https://github.com/$ORGA/$NAME"
[[ -d 'build' ]] && G_EXEC rm -R build
G_EXEC cd "$NAME"
DIR="/tmp/${NAME}_$G_HW_ARCH_NAME"
export CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3'
G_EXEC_OUTPUT=1 G_EXEC cmake -B ../build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DIR/opt/$NAME" -DDISABLE_UPDATER=1
G_EXEC_OUTPUT=1 G_EXEC make -C ../build "-j$(nproc)"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC_OUTPUT=1 G_EXEC make -C ../build install
G_EXEC strip --remove-section=.comment --remove-section=.note "$DIR/opt/$NAME/$NAME"

# Cleanup
G_EXEC rm "$DIR/opt/$NAME/scripts/"{_domoticz_main.bat,download_update.sh,install.sh,restart_domoticz,update_domoticz}

# Prepare DEB package
G_DIETPI-NOTIFY 2 "Building $PRETTY DEB package"
G_EXEC mkdir -p "$DIR/"{DEBIAN,lib/systemd/system,"mnt/dietpi_userdata/$NAME",etc/sudoers.d}

# - configs
G_EXEC mv "$DIR/opt/$NAME/scripts/$NAME.conf" "$DIR/mnt/dietpi_userdata/$NAME/"
G_EXEC mv "$DIR/opt/$NAME/scripts" "$DIR/mnt/dietpi_userdata/$NAME/"
G_EXEC sed --follow-symlinks -i '/^# Disable update checking$/,/^$/d' "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
grep 'updates=' "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf" && Error_Exit 'Internal updater section still present in config file'
G_CONFIG_INJECT 'http_port=' 'http_port=0' "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'ssl_port=' 'ssl_port=8424' "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'ssl_cert=' "ssl_cert=/opt/$NAME/server_cert.pem" "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'ssl_key=' "ssl_key=/opt/$NAME/server_cert.pem" "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'ssl_dhparam=' "ssl_dhparam=/opt/$NAME/server_cert.pem" "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'loglevel=' 'loglevel=error' "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'syslog=' 'syslog=local7' "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'dbase_file=' "dbase_file=/mnt/dietpi_userdata/$NAME/$NAME.db" "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'app_path=' "app_path=/opt/$NAME" "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"
G_CONFIG_INJECT 'userdata_path=' "userdata_path=/mnt/dietpi_userdata/$NAME" "$DIR/mnt/dietpi_userdata/$NAME/$NAME.conf"

# - sudoers: permit shutdown/restart from web UI
G_EXEC eval "echo '$NAME ALL=NOPASSWD: $(command -v shutdown)' > '$DIR/etc/sudoers.d/$NAME'"

# - conffiles
find "$DIR/mnt/dietpi_userdata/$NAME" -type f | sed "s|^$DIR||" > "$DIR/DEBIAN/conffiles" || exit 1
G_EXEC eval "echo '/etc/sudoers.d/$NAME' >> '$DIR/DEBIAN/conffiles'"

# - service
cat << _EOF_ > "$DIR/lib/systemd/system/$NAME.service" || exit 1
[Unit]
Description=$PRETTY
Wants=network-online.target
After=network-online.target

[Service]
User=$NAME
ExecStart=/opt/$NAME/$NAME -f /mnt/dietpi_userdata/$NAME/$NAME.conf

# Hardening
ProtectSystem=strict
ProtectHome=true
PrivateTmp=yes
ReadWritePaths=/mnt/dietpi_userdata/$NAME

[Install]
WantedBy=multi-user.target
_EOF_

# - postinst
cat << _EOF_ > "$DIR/DEBIAN/postinst" || exit 1
#!/bin/dash -e
if [ -d '/run/systemd/system' ]
then
	if getent passwd $NAME > /dev/null
	then
		echo 'Configuring $PRETTY service user "$NAME" ...'
		usermod -aG dialout -d /mnt/dietpi_userdata/$NAME -s /usr/sbin/nologin $NAME
	else
		echo 'Creating $PRETTY service user "$NAME" ...'
		useradd -rMU -G dialout -d /mnt/dietpi_userdata/$NAME -s /usr/sbin/nologin $NAME
	fi

	echo 'Setting up $PRETTY data dir "/mnt/dietpi_userdata/$NAME" ...'
	chown -R '$NAME:$NAME' /mnt/dietpi_userdata/$NAME

	echo 'Configuring $PRETTY systemd service ...'
	systemctl --no-reload unmask $NAME
	systemctl enable $NAME
	pgrep -x 'dietpi-software' || systemctl restart $NAME
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
		rm -rv /etc/systemd/system/$NAME.service.d
	fi

	if [ -d '/mnt/dietpi_userdata/$NAME' ]
	then
		echo 'Removing $PRETTY data dir ...'
		rm -rv /mnt/dietpi_userdata/$NAME
	fi

	if getent passwd $NAME > /dev/null
	then
		echo 'Removing $PRETTY service user "$NAME" ...'
		userdel $NAME
	fi

	if getent group $NAME > /dev/null
	then
		echo 'Removing $PRETTY service group "$NAME" ...'
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
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${version}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
[[ $G_HW_ARCH_NAME == 'armv6l' ]] && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version suffix
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${NAME}_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && version+="-dietpi$((suffix+1))" || version+="-dietpi1"
G_DIETPI-NOTIFY 2 "Old package version is:       \e[33m${old_version:-N/A}"
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
Section: misc
Priority: optional
Homepage: https://www.domoticz.com/
Description: Open source home automation platform
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# - Permissions
G_EXEC chown -R 0:0 "$DIR"
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/"{"opt/$NAME/$NAME",DEBIAN/{postinst,prerm,postrm}}

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

exit 0
}
