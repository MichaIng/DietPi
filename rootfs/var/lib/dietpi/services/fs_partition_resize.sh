#!/bin/bash
{
	# Error out on command failures
	set -e
	REBOOT=
	EXIT_CODE=0
	TMP_MOUNT=

	# Exit trap to remove temporary mounts and perform reboot on failure
	# shellcheck disable=SC2329
	EXIT_TRAP()
	{
		[[ $TMP_MOUNT ]] && umount -lv "$TMP_MOUNT" && rmdir -v "$TMP_MOUNT" || :

		if [[ $REBOOT ]]
		then
			echo "[ INFO ] Performing final reboot $REBOOT"
			systemctl start reboot.target
		fi
	}
	trap 'EXIT_TRAP' EXIT

	Reboot_to_load_Partition_table()
	{
		echo '[ INFO ] Performing intermediate reboot to load new partition table'
		echo '[ INFO ] Re-enabling this service to continue with filesystem expansion on next boot'
		> /dietpi_skip_partition_resize
		mkdir -pv /etc/systemd/system/local-fs.target.wants
		ln -sfv /etc/systemd/system/dietpi-fs_partition_resize.service /etc/systemd/system/local-fs.target.wants/dietpi-fs_partition_resize.service
		systemctl start reboot.target
		exit 0
	}

	echo '[ INFO ] Remounting root filesystem R/W'
	mount -vo remount,rw /

	echo '[ INFO ] Splitting output to /var/tmp/dietpi/logs/fs_partition_resize.log'
	mkdir -pv /var/tmp/dietpi/logs
	{
	# ---------------------------------------------------------
	echo '[ INFO ] Disabling this service to prevent possible endless loop in case of failure'
	rm -Rfv /etc/systemd/system/*.wants/dietpi-fs_partition_resize.service

	echo '[ INFO ] Obtaining root filesystem device'
	ROOT_DEV=$(findmnt -Ufvnro SOURCE -M /)

	echo '[ INFO ] Detecting root partition and parent drive for supported naming schemes'
	# - SCSI/SATA:   /dev/sd[a-z][1-9]
	# - IDE:         /dev/hd[a-z][1-9]
	# - VirtIO:      /dev/vd[a-z][1-9]
	# - Xen/XCP-ng:  /dev/xvd[a-z][1-9]
	# - eMMC:        /dev/mmcblk[0-9]p[1-9]
	# - NVMe:        /dev/nvme[0-9]n[0-9]p[1-9]
	# - loop:        /dev/loop[0-9]p[1-9]
	if [[ $ROOT_DEV =~ ^/dev/(sd|hd|vd|xvd)[a-z][1-9]$ ]]
	then
		ROOT_PART=${ROOT_DEV: -1}   # /dev/sda1 => 1
		ROOT_DRIVE=${ROOT_DEV::-1}  # /dev/sda1 => /dev/sda

	elif [[ $ROOT_DEV =~ ^/dev/(mmcblk|nvme[0-9]n|loop)[0-9]p[1-9]$ ]]
	then
		ROOT_PART=${ROOT_DEV: -1}   # /dev/mmcblk0p1 => 1
		ROOT_DRIVE=${ROOT_DEV::-2}  # /dev/mmcblk0p1 => /dev/mmcblk0
	else
		echo "[FAILED] Unsupported root device naming scheme ($ROOT_DEV). Aborting ..."
		exit 1
	fi
	echo "[ INFO ] Detected root drive $ROOT_DRIVE with root partition $ROOT_PART"

	echo '[ INFO ] Mounting /tmp for temporary mount points'
	mount -v /tmp || :

	# Skip partition handling if done on first boot already
	if [[ -f '/dietpi_skip_partition_resize' ]]
	then
		rm -v /dietpi_skip_partition_resize

	elif [[ ! -e $ROOT_DRIVE ]]
	then
		echo '[ INFO ] Skipping partition expansion since detected root drive device node does not exist, assuming container system'
	else
		echo '[ INFO ] Checking if the last partition contains a filesystem with DIETPISETUP label'
		# - Use sfdisk to detect last partition, as lsblk with "-r" option on Bullseye does not sort partitions well: https://github.com/MichaIng/DietPi/issues/7527
		SETUP_PART=$(sfdisk -lqo Device "$ROOT_DRIVE" | tail -1)
		# - Probe via blkid instead of lsblk=udev, since systemd-udevd does not run yet at this boot stage. From Trixie on, "lsblk --properties-by blkid" can be used.
		if [[ $(blkid -s LABEL -o value "$SETUP_PART") == 'DIETPISETUP' ]]
		then
			echo "[ INFO ] Detected trailing DietPi setup partition $SETUP_PART"
			echo '[ INFO ] Mounting it and importing files if present and newer'
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
					(( $(date -r '/boot/extlinux/extlinux.conf' '+%s') > $mtime )) && REBOOT='to apply the extlinux.conf change'
				else
					[[ ( $f == 'dietpiEnv.txt' || $f == 'boot.ini' ) && -f /boot/$f ]] && mtime=$(date -r "/boot/$f" '+%s') || mtime=0
					cp -uv "$TMP_MOUNT/$f" /boot/
					[[ $f == 'dietpiEnv.txt' || $f == 'boot.ini' ]] && (( $(date -r "/boot/$f" '+%s') > $mtime )) && REBOOT='to apply the dietpiEnv.txt change'
				fi
			done
			umount -v "$SETUP_PART"
			rmdir -v "$TMP_MOUNT"
			unset -v TMP_MOUNT
			echo '[ INFO ] Deleting trailing DietPi setup partition to allow root filesystem expansion'
			sfdisk --no-reread --no-tell-kernel --delete "$ROOT_DRIVE" "${SETUP_PART: -1}"

		elif grep -q '[[:blank:]]/boot/firmware[[:blank:]][[:blank:]]*vfat[[:blank:]]' /etc/fstab
		then
			BOOT_PART=$(mawk '/[[:blank:]]\/boot\/firmware[[:blank:]][[:blank:]]*vfat[[:blank:]]/{print $1}' /etc/fstab)
			echo "[ INFO ] Detected RPi /boot/firmware partition $BOOT_PART"
			echo '[ INFO ] Mounting it and importing files if present and newer'
			TMP_MOUNT=$(mktemp -d)
			mount -v "$BOOT_PART" "$TMP_MOUNT"
			for f in 'dietpi.txt' 'dietpi-wifi.txt' 'Automation_Custom_PreScript.sh' 'Automation_Custom_Script.sh' 'unattended_pivpn.conf'
			do
				[[ -f $TMP_MOUNT/$f ]] && cp -uv "$TMP_MOUNT/$f" /boot/
			done
			umount -v "$BOOT_PART"
			rmdir -v "$TMP_MOUNT"
			unset -v TMP_MOUNT
		else
			echo '[ INFO ] No DietPi setup partition found:'
			lsblk -po NAME,LABEL,SIZE,TYPE,FSTYPE,MOUNTPOINT "$ROOT_DRIVE"
		fi

		echo '[ INFO ] Maximising root partition size'
		sfdisk --no-reread --no-tell-kernel -fN"$ROOT_PART" "$ROOT_DRIVE" <<< ',+'

		echo '[ INFO ] Informing kernel about changed partition table, rebooting in case of failure (expected in case of GPT partition table)'
		partx -uv "$ROOT_DEV" || Reboot_to_load_Partition_table
	fi

	echo '[ INFO ] Detecting root filesystem type'
	ROOT_FSTYPE=$(findmnt -Ufnro FSTYPE -M /)

	# Maximise root filesystem if type is supported
	case $ROOT_FSTYPE in
		'ext'[234])
			if [[ -b $ROOT_DEV ]]
			then
				echo "[ INFO ] Maximising $ROOT_FSTYPE root filesystem size"
				resize2fs "$ROOT_DEV" || REBOOT='since the root filesystem resize failed' # https://github.com/MichaIng/DietPi/issues/6149
				if [[ $ROOT_FSTYPE == 'ext'[34] ]] && ! tune2fs -l "$ROOT_DEV" | grep -q 'has_journal'
				then
					echo '[ INFO ] Adding root filesystem journal'
					if [[ -e '/run/initramfs/fsck-root' ]]
					then
						REBOOT=' with forced fsck to apply the new root filesystem journal'
						echo -e '#!/bin/dash\ntune2fs -c 0 '"'$ROOT_DEV' && rm /var/lib/dietpi/postboot.d/dietpi-reset_max_mount_count" > /var/lib/dietpi/postboot.d/dietpi-reset_max_mount_count
						tune2fs -O 'has_journal' -c 1 -C 2 "$ROOT_DEV"
						sync
						sleep 1
					else
						tune2fs -O 'has_journal' "$ROOT_DEV"
					fi
				fi
			else
				echo '[ INFO ] Skipping root filesystem expansion since detected root partition device node does not exist, assuming container system'
			fi
		;;
		'f2fs') echo '[ INFO ] F2FS online expansion is not possible. Please do that from another Linux system if needed.';;
		'btrfs')
			echo "[ INFO ] Maximising $ROOT_FSTYPE root filesystem size"
			btrfs filesystem resize max /
		;;
		*)
			echo "[FAILED] Unsupported root filesystem type ($ROOT_FSTYPE). Aborting ..."
			EXIT_CODE=1
		;;
	esac
	# ---------------------------------------------------------
	} &> >(tee -a /var/tmp/dietpi/logs/fs_partition_resize.log); wait $! # Method from dietpi-update to avoid commands running in a subshell, breaking script exits and implying variable changes remaining local

	exit "$EXIT_CODE"
}
