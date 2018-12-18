#!/bin/bash

systemctl disable dietpi-fs_partition_resize

sync

# Naming scheme: https://askubuntu.com/questions/56929/what-is-the-linux-drive-naming-scheme
# - SCSI/SATA:	/dev/sd[a-z][0-9]
# - IDE:	/dev/hd[a-z][0-9]
# - eMMC:	/dev/mmcblk[0-9]p[0-9]
# - NVMe:	/dev/nvme[0-9]n[0-9]p[0-9]
TARGET_DEV=$(findmnt / -o source -n)
if [[ $TARGET_DEV =~ /mmcblk || $TARGET_DEV =~ /nvme ]]; then

	TARGET_PARTITION=${TARGET_DEV##*p}	# mmcblk0p1 => 1
	TARGET_DRIVE=${TARGET_DEV%p[0-9]}	# mmcblk0p1 => mmcblk0

elif [[ $TARGET_DEV =~ /[sh]d[a-z] ]]; then

	TARGET_PARTITION=${TARGET_DEV##*[a-z]}	# /dev/sda1 => 1
	TARGET_DRIVE=${TARGET_DEV%[0-9]}	# /dev/sda1 => /dev/sda

else

	echo "[FAILED] Unsupported drive naming scheme: $TARGET_DEV. Aborting..."
	exit 1

fi

# Only redo partitions, if drive actually contains a partition table.
if [[ $TARGET_PARTITION == [0-9] ]]; then

	# - GPT detection | modified version of ayufan-rock64 resize script.
	if sfdisk $TARGET_DRIVE -l | grep -qi 'disklabel type: gpt'; then

		#	move GPT alternate header to end of disk
		sgdisk -e $TARGET_DRIVE

	fi

	# - Maximize partition size
	sfdisk $TARGET_DRIVE -fN$TARGET_PARTITION --no-reread <<< ',+,,,'

	partprobe $TARGET_DRIVE

else

	echo "[ INFO ] No valid root partition found: $TARGET_PARTITION. Skipping partition resize..."

fi

resize2fs $TARGET_DEV

exit 0
