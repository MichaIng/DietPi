#!/bin/bash
{
	# Disable this service
	systemctl disable dietpi-fs_partition_resize

	# Grab root device
	# Naming scheme: https://askubuntu.com/questions/56929/what-is-the-linux-drive-naming-scheme
	# - SCSI/SATA:	/dev/sd[a-z][0-9]
	# - IDE:	/dev/hd[a-z][0-9]
	# - eMMC:	/dev/mmcblk[0-9]p[0-9]
	# - NVMe:	/dev/nvme[0-9]n[0-9]p[0-9]
	TARGET_DEV=$(findmnt -no SOURCE /)
	if [[ $TARGET_DEV == '/dev/mmcblk'* || $TARGET_DEV == '/dev/nvme'* ]]; then

		TARGET_PARTITION=${TARGET_DEV##*p}	# /dev/mmcblk0p1 => 1
		TARGET_DRIVE=${TARGET_DEV%p[0-9]}	# /dev/mmcblk0p1 => /dev/mmcblk0

	elif [[ $TARGET_DEV == /dev/[sh]d[a-z]* ]]; then

		TARGET_PARTITION=${TARGET_DEV##*[a-z]}	# /dev/sda1 => 1
		TARGET_DRIVE=${TARGET_DEV%[0-9]}	# /dev/sda1 => /dev/sda

	else

		echo "[FAILED] Unsupported block device naming scheme ($TARGET_DEV). Aborting..."
		exit 1

	fi

	# Maximize partition, only if drive actually contains a partition table
	if [[ $TARGET_PARTITION == [0-9] ]]; then

		# Failsafe: Sync changes to disk before touching partitions
		sync

		# GPT detection | Modified version of ayufan-rock64 resize script: # Move GPT alternate header to end of disk
		sfdisk $TARGET_DRIVE -l | grep -qi 'disklabel type: gpt' && sgdisk -e $TARGET_DRIVE

		# Maximize partition size
		sfdisk --no-reread $TARGET_DRIVE -fN$TARGET_PARTITION <<< ',+,,,'

		# Reread partition table
		partprobe $TARGET_DRIVE

	else

		echo "[ INFO ] No (valid) root partition found ($TARGET_PARTITION). Most likely the drive does not contain a partition table. Skipping partition resize..."

	fi

	# Maximize file system
	resize2fs $TARGET_DEV

	exit 0
}
