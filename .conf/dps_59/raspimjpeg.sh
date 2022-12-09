#!/bin/dash
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

	Raspimjeg_Stop(){ killall -qw php raspimjpeg; }

	Raspimjeg_Start()
	{
		[ -d '/dev/shm/mjpeg' ] || mkdir /dev/shm/mjpeg
		chown www-data:video /dev/shm/mjpeg
		chmod 770 /dev/shm/mjpeg
		sudo -u www-data raspimjpeg &
		sleep 4
		sudo -u www-data php /var/www/rpicam/schedule.php &
	}

	case "$1" in
		'stop') Raspimjeg_Stop;;
		'start') Raspimjeg_Start;;
		*) echo "ERROR: Invalid argument: \"$1\""
	esac

	exit 0
}
