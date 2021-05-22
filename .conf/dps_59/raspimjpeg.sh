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
	# - Allows service control for Raspimjpeg and PHP schedule, used by RPi Cam Control
	# - Called from /etc/systemd/system/raspimjpeg.service
	#
	#////////////////////////////////////

	Raspimjeg_Stop(){

		killall -qw php raspimjpeg

	}

	Raspimjeg_Start(){

		mkdir -p /dev/shm/mjpeg
		chown www-data:video /dev/shm/mjpeg
		chmod 770 /dev/shm/mjpeg
		sudo -u www-data raspimjpeg &
		sleep 4
		sudo -u www-data php /var/www/rpicam/schedule.php &

	}

	if [ "$1" = 'stop' ]; then

		Raspimjeg_Stop

	elif [ "$1" = 'start' ]; then

		Raspimjeg_Start

	fi

	exit 0
}
