#!/bin/bash
{
	# Error out on command failures
	set -e
	EXIT_CODE=0

	Reboot_to_load_Partition_table()
	{
		> /dietpi_skip_partition_resize
		systemctl enable dietpi-fs_partition_resize
		echo '[ INFO ] Rebooting to load the new partition table'
		sync
		reboot
		exit 0
	}

	# Disable this service
	! systemctl is-enabled dietpi-fs_partition_resize > /dev/null || systemctl disable dietpi-fs_partition_resize

	# Detect root device
	ROOT_DEV=$(findmnt -Ufnro SOURCE -M /)

	# Detect root partition and parent drive for supported naming schemes:
	# - SCSI/SATA:	/dev/sd[a-z][1-9]
	# - IDE:	/dev/hd[a-z][1-9]
	# - VirtIO:	/dev/vd[a-z][1-9]
	# - eMMC:	/dev/mmcblk[0-9]p[1-9]
	# - NVMe:	/dev/nvme[0-9]n[0-9]p[1-9]
	# - loop:	/dev/loop[0-9]p[1-9]
	if [[ $ROOT_DEV == /dev/[shv]d[a-z][1-9] ]]
	then
		ROOT_PART=${ROOT_DEV: -1}	# /dev/sda1 => 1
		ROOT_DRIVE=${ROOT_DEV::-1}	# /dev/sda1 => /dev/sda

	elif [[ $ROOT_DEV =~ ^/dev/(mmcblk|nvme[0-9]n|loop)[0-9]p[1-9]$ ]]
	then
		ROOT_PART=${ROOT_DEV: -1}	# /dev/mmcblk0p1 => 1
		ROOT_DRIVE=${ROOT_DEV::-2}	# /dev/mmcblk0p1 => /dev/mmcblk0
	else
		echo "[FAILED] Unsupported root device naming scheme ($ROOT_DEV). Aborting..."
		exit 1
	fi
	echo "[ INFO ] Detected root drive $ROOT_DRIVE with root partition $ROOT_PART"

	# Check if the last partition contains a FAT filesystem with DIETPISETUP label
	REBOOT=0
	LAST_PART=$(lsblk -nrbo FSTYPE,LABEL "$ROOT_DRIVE" | tail -1)
	if [[ $LAST_PART == 'vfat DIETPISETUP' ]]
	then
		SETUP_PART=$(sfdisk -lqo DEVICE "$ROOT_DRIVE" | tail -1)
		echo "[ INFO ] Detected trailing DietPi setup partition $SETUP_PART"
		# Mount it and copy files if present and newer
		TMP_MOUNT=$(mktemp -d)
		mount -v "$SETUP_PART" "$TMP_MOUNT"
		for f in 'dietpi.txt' 'dietpi-wifi.txt' 'dietpiEnv.txt' 'boot.ini' 'extlinux.conf' 'Automation_Custom_PreScript.sh' 'Automation_Custom_Script.sh' 'unattended_pivpn.conf'
		do
			[[ -f $TMP_MOUNT/$f ]] || continue
			if [[ $f == 'extlinux.conf' ]]
			then
				mkdir -pv /boot/extlinux
				[[ -f '/boot/extlinux/extlinux.conf' ]] && mtime=$(date -r '/boot/extlinux/extlinux.conf' '+%s') || mtime=0
				cp -uv "$TMP_MOUNT/$f" /boot/extlinux/
				(( $(date -r '/boot/extlinux/extlinux.conf' '+%s') > $mtime )) && REBOOT=1
			else
				[[ ( $f == 'dietpiEnv.txt' || $f == 'boot.ini' ) && -f /boot/$f ]] && mtime=$(date -r "/boot/$f" '+%s') || mtime=0
				cp -uv "$TMP_MOUNT/$f" /boot/
				[[ $f == 'dietpiEnv.txt' || $f == 'boot.ini' ]] && (( $(date -r "/boot/$f" '+%s') > $mtime )) && REBOOT=1
			fi
		done
		umount -v "$SETUP_PART"
		rmdir -v "$TMP_MOUNT"
		# Finally delete the partition so the resizing works
		sfdisk --no-reread --no-tell-kernel --delete "$ROOT_DRIVE" "${SETUP_PART: -1}"

	elif grep -q '[[:blank:]]/boot/firmware[[:blank:]][[:blank:]]*vfat[[:blank:]]' /etc/fstab
	then
		BOOT_PART=$(mawk '/[[:blank:]]\/boot\/firmware[[:blank:]][[:blank:]]*vfat[[:blank:]]/{print $1}' /etc/fstab)
		echo "[ INFO ] Detected RPi boot/firmware partition $BOOT_PART"
		# Mount it and copy files if present and newer
		TMP_MOUNT=$(mktemp -d)
		mount -v "$BOOT_PART" "$TMP_MOUNT"
		for f in 'dietpi.txt' 'dietpi-wifi.txt' 'Automation_Custom_PreScript.sh' 'Automation_Custom_Script.sh' 'unattended_pivpn.conf'
		do
			[[ -f $TMP_MOUNT/$f ]] && cp -uv "$TMP_MOUNT/$f" /boot/
		done
		umount -v "$BOOT_PART"
		rmdir -v "$TMP_MOUNT"
	else
		echo "[ INFO ] No DietPi setup partition found, last partition is: \"$LAST_PART\""
		lsblk -po NAME,LABEL,SIZE,TYPE,FSTYPE,MOUNTPOINT "$ROOT_DRIVE"
	fi

	# Only increase partition size if not yet done on first boot
	if [[ -f '/dietpi_skip_partition_resize' ]]
	then
		rm -v /dietpi_skip_partition_resize
	else
		# Failsafe: Sync changes to disk before touching partitions
		sync

		# GPT partition table: Move backup GPT data structures to the end of the disk
		# - lsblk -ndo PTTYPE "$ROOT_DRIVE" does not work inside systemd-nspawn containers.
		[[ $(blkid -s PTTYPE -o value -c /dev/null "$ROOT_DRIVE") != 'gpt' ]] || sgdisk -e "$ROOT_DRIVE"

		# Maximise root partition size
		sfdisk --no-reread --no-tell-kernel -fN"$ROOT_PART" "$ROOT_DRIVE" <<< ',+'

		# Inform kernel about changed partition table, be failsafe by using two different methods and reboot if any fails
		partprobe "$ROOT_DRIVE" || Reboot_to_load_Partition_table
		partx -u "$ROOT_DRIVE" || Reboot_to_load_Partition_table

		# Give the system some time to have the changes fully applied: https://github.com/MichaIng/DietPi/issues/5006
		sleep 0.5
	fi

	# Detect root filesystem type
	ROOT_FSTYPE=$(findmnt -Ufnro FSTYPE -M /)

	# Maximise root filesystem if type is supported
	case $ROOT_FSTYPE in
		'ext'[234]) resize2fs "$ROOT_DEV" || REBOOT=1;; # Reboot if resizing fails: https://github.com/MichaIng/DietPi/issues/6149
		'f2fs')
			mount -o remount,ro /
			resize.f2fs "$ROOT_DEV"
			mount -o remount,rw /
		;;
		'btrfs') btrfs filesystem resize max /;;
		*)
			echo "[FAILED] Unsupported root filesystem type ($ROOT_FSTYPE). Aborting..."
			EXIT_CODE=1
		;;
	esac

	# Reboot if needed
	(( $REBOOT )) && { sync; reboot; }

	exit "$EXIT_CODE"
}
