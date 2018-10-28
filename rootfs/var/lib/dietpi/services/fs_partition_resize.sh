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

	TARGET_PARTITION=${TARGET_DEV##*p} # Last [0-9] after "p"
	TARGET_DRIVE=${TARGET_DEV%p[0-9]} # EG: /dev/mmcblk[0-9]

elif [[ $TARGET_DEV =~ /[sh]d[a-z] ]]; then

	TARGET_PARTITION=${TARGET_DEV##*[a-z]} # Last [0-9]
	TARGET_DRIVE=${TARGET_DEV%[0-9]} # EG: /dev/sda

else

	echo "[FAILED] Unsupported drive naming scheme: $TARGET_DEV"
	exit 1

fi

# Only redo partitions, if drive actually contains a partition table.
if [[ $TARGET_PARTITION == [0-9] ]]; then

	# - Check for valid device ID
	#	Do not fail due to RPi has autodetection of hw_model
	if ! HW_MODEL=$(</etc/.dietpi_hw_model_identifier); then

		echo '[FAILED] Could not determine device ID from: /etc/.dietpi_hw_model_identifier'
		echo 'Assuming RPi'
		HW_MODEL=0

	fi

	# - Rock/pro64 GPT resize | modified version of ayufan-rock64 resize script. I take no credit for this.
	if (( $HW_MODEL == 42 || $HW_MODEL == 43 )); then

		# move GPT alternate header to end of disk
		sgdisk -e $TARGET_DRIVE

		# resize partition 7 to as much as possible
		echo ",+,,," | sfdisk $TARGET_DRIVE -N7 --force

	# - Everything else
	else

		cat << _EOF_ | fdisk $TARGET_DRIVE
p
d
$TARGET_PARTITION
n
p
$TARGET_PARTITION
$(parted $TARGET_DRIVE -ms unit s p | grep ':ext4::;' | awk -F: '{print $2}' | sed 's/s//g')

p
w

_EOF_

	fi

	partprobe $TARGET_DRIVE

else

	echo "[ INFO ] No valid root partition found: $TARGET_PARTITION. Skipping partition resize..."

fi

resize2fs $TARGET_DEV

exit 0
