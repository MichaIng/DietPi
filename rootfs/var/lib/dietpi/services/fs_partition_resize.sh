#!/bin/bash

systemctl disable dietpi-fs_partition_resize

sync

# Naming scheme: https://askubuntu.com/questions/56929/what-is-the-linux-drive-naming-scheme
# - SCSI/SATA:	/dev/sd[a-z][0-9]
# - IDE:	/dev/hd[a-z][0-9]
# - eMMC:	/dev/mmcblk[0-9]p[0-9]
# - NVMe:	/dev/nvme[0-9]n[0-9]
TARGET_DEV=$(findmnt / -o source -n)
TARGET_PARTITION=${TARGET_DEV##*[a-z]} # Last [0-9]
TARGET_DRIVE=${TARGET_DEV%[0-9]} # EG: /dev/mmcblk[0-9]p
[[ $TARGET_DEV =~ mmcblk ]] || [[ $TARGET_DEV =~ nvme ]] && TARGET_DRIVE=${TARGET_DRIVE%[a-z]} # EG: /dev/mmcblk[0-9]

# Only redo partitions, if drive actually contains a partition table.
if [[ $TARGET_PARTITION ]]; then

	#Rock64 GPT resize | modified version of ayufan-rock64 resize script. I take no credit for this.
	if [[ -f /etc/.dietpi_hw_model_identifier ]] && (( $(</etc/.dietpi_hw_model_identifier) == 43 )); then

		gdisk $TARGET_DRIVE << _EOF_
x
e
m
d
$TARGET_PARTITION
n
$TARGET_PARTITION


8300
c
$TARGET_PARTITION
root
w
Y
_EOF_

	#Everything else
	else

		cat << _EOF_ | fdisk $TARGET_DRIVE
p
d
$TARGET_PARTITION
n
p
$TARGET_PARTITION
$(parted $TARGET_DRIVE -ms unit s p | grep ':ext4::;' | sed 's/:/ /g' | sed 's/s//g' | awk '{ print $2 }')

p
w

_EOF_

	fi

fi

partprobe $TARGET_DRIVE

resize2fs $TARGET_DEV

exit 0

