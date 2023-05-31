#!/bin/dash -e
{
	#////////////////////////////////////
	# DietPi Raspimjpeg control Script
	#
	#////////////////////////////////////
	# Created by Daniel Knight / daniel.knight@dietpi.com / dietpi.com
	#
	# Info:
	# - Location: /var/lib/dietpi/dietpi-software/installed/raspimjpeg.sh
	# - Allows service control for RaspiMJPEG and PHP schedule, used by RPi Cam Web Interface
	# - Called from /etc/systemd/system/raspimjpeg.service
	#
	#////////////////////////////////////

	Raspimjeg_Start()
	{
		[ -d '/dev/shm/mjpeg' ] || mkdir /dev/shm/mjpeg
		chown www-data:video /dev/shm/mjpeg
		chmod 770 /dev/shm/mjpeg
		sudo -u www-data raspimjpeg &
		sleep 4
		sudo -u www-data php /var/www/rpicam/schedule.php &
	}

	case $1 in
		'stop') killall -qw php raspimjpeg;;
		'start') Raspimjeg_Start;;
		*) echo "ERROR: Invalid argument: \"$1\"" >&2; exit 1;;
	esac

	exit 0
}
