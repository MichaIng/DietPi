#!/bin/bash
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
##########################################
# Load DietPi-Globals
##########################################
if [[ -f '/boot/dietpi/func/dietpi-globals' ]]
then
	. /boot/dietpi/func/dietpi-globals
else
	curl -sSf "https://raw.githubusercontent.com/${G_GITOWNER:=MichaIng}/DietPi/${G_GITBRANCH:=master}/dietpi/func/dietpi-globals" -o /tmp/dietpi-globals || exit 1
	# shellcheck disable=SC1091
	. /tmp/dietpi-globals
	G_EXEC_NOHALT=1 G_EXEC rm /tmp/dietpi-globals
	export G_GITOWNER G_GITBRANCH G_HW_ARCH_NAME=$(uname -m)
fi
case $G_HW_ARCH_NAME in
	'armv6l') export G_HW_ARCH=1;;
	'armv7l') export G_HW_ARCH=2;;
	'aarch64') export G_HW_ARCH=3;;
	'x86_64') export G_HW_ARCH=10;;
	*) G_DIETPI-NOTIFY 1 "Unsupported host system architecture \"$G_HW_ARCH_NAME\" detected, aborting..."; exit 1;;
esac
readonly G_PROGRAM_NAME='DietPi-Amiberry_container_setup'
G_CHECK_ROOT_USER
G_CHECK_ROOTFS_RW
readonly FP_ORIGIN=$PWD # Store origin dir
G_INIT
G_EXEC cd "$FP_ORIGIN" # Process everything in origin dir instead of /tmp/$G_PROGRAM_NAME

##########################################
# Process inputs
##########################################
DISTRO=
PLATFORM=
while (( $# ))
do
	case $1 in
		'-d') shift; DISTRO=$1;;
		'-p') shift; PLATFORM=$1;;
		*) G_DIETPI-NOTIFY 1 "Invalid input \"$1\", aborting..."; exit 1;;
	esac
	shift
done
distro=
case $DISTRO in
        5) distro='buster';;
	6) distro='bullseye';;
	7) distro='bookworm';;
	*) G_DIETPI-NOTIFY 1 "Invalid distro \"$DISTRO\" passed, aborting..."; exit 1;;
esac
image=
case $PLATFORM in
        'rpi'[1-4]) image="DietPi_Container-ARMv6-${distro^}";;
	'c1'|'xu4'|'RK3288'|'sun8i'|'s812') image="DietPi_Container-ARMv7-${distro^}";;
	'rpi'[34]'-64-dmx'|'AMLSM1'|'n2'|'a64') image="DietPi_Container-ARMv8-${distro^}";;
	'x86-64') image="DietPi_Container-x86_64-${distro^}";;
	*) G_DIETPI-NOTIFY 1 "Invalid platform \"$PLATFORM\" passed, aborting..."; exit 1;;
esac

##########################################
# Dependencies
##########################################
apackages=('7zip' 'parted' 'fdisk' 'systemd-container')
[[ $PLATFORM == 'x86-64' ]] || apackages+=('qemu-user-static' 'binfmt-support')
G_AG_CHECK_INSTALL_PREREQ "${apackages[@]}"

##########################################
# Prepare container
##########################################
# Download
G_EXEC curl -sSfO "https://dietpi.com/downloads/images/$image.7z"
G_EXEC 7zz x "$image.7z"
G_EXEC rm "$image.7z" hash.txt README.md
G_EXEC truncate -s $((2*1024**3)) "$image.img"

# Loop device
FP_LOOP=$(losetup -f)
G_EXEC losetup "$FP_LOOP" "$image.img"
G_EXEC partprobe "$FP_LOOP"
G_EXEC partx -u "$FP_LOOP"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "${FP_LOOP}p1"
G_EXEC_OUTPUT=1 G_EXEC eval "sfdisk -fN1 '$FP_LOOP' <<< ',+'"
G_EXEC partprobe "$FP_LOOP"
G_EXEC partx -u "$FP_LOOP"
G_EXEC_OUTPUT=1 G_EXEC resize2fs "${FP_LOOP}p1"
G_EXEC_OUTPUT=1 G_EXEC e2fsck -fp "${FP_LOOP}p1"
G_EXEC mkdir rootfs
G_EXEC mount "${FP_LOOP}p1" rootfs

# Automated build
cat << '_EOF_' > rootfs/etc/rc.local || exit 1
#!/bin/dash
infocmp "$TERM" > /dev/null 2>&1 || TERM='dumb'
echo '[ INFO ] Running Amiberry build script...'
_EOF_

# - RPi 64-bit: Add RPi repo, ARMv6 container images contain it already
[[ $PLATFORM == 'rpi'[34]'-64-dmx' ]] && cat << _EOF_ >> rootfs/etc/rc.local
echo 'deb https://archive.raspberrypi.org/debian/ ${distro/bookworm/bullseye} main' > /etc/apt/sources.list.d/raspi.list
curl -sSf 'https://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-archive-keyring/raspberrypi-archive-keyring_2021.1.1+rpt1_all.deb' -o /tmp/keyring.deb
dpkg -i /tmp/keyring.deb
rm -v /tmp/keyring.deb
_EOF_

cat << _EOF_ >> rootfs/etc/rc.local || exit 1
bash -c "\$(curl -sSf 'https://raw.githubusercontent.com/$G_GITOWNER/DietPi/$G_GITBRANCH/.build/software/Amiberry/build.bash')" 'DietPi-Amiberry_build' '$PLATFORM'
mv -v '/tmp/amiberry_$PLATFORM.deb' '/amiberry_$PLATFORM.deb'
poweroff
_EOF_
G_EXEC chmod +x rootfs/etc/rc.local

# Assure that build starts after DietPi-PostBoot
[[ -d 'rootfs/etc/systemd/system/rc-local.service.d' ]] || G_EXEC mkdir rootfs/etc/systemd/system/rc-local.service.d
G_EXEC eval 'echo -e '\''[Unit]\nAfter=dietpi-postboot.service'\'' > rootfs/etc/systemd/system/rc-local.service.d/dietpi.conf'

##########################################
# Boot container
##########################################
systemd-nspawn -bD rootfs --bind="$FP_LOOP"{,p1} --bind=/dev/disk
[[ -f rootfs/amiberry_$PLATFORM.deb ]] || exit 1
}
