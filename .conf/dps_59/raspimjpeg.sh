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
	# - Allows service control for Raspimjpeg and PHP schedule, used by RPi Camera Web
	# - Called from /etc/systemd/system/raspimjpeg.service
	#
	#////////////////////////////////////

	Raspimjeg_Stop(){

		killall -qw raspimjpeg php

	}

	Raspimjeg_Start(){

		mkdir -p /dev/shm/mjpeg
		chown www-data:www-data /dev/shm/mjpeg
		chmod 777 /dev/shm/mjpeg
		sudo -u www-data raspimjpeg > /dev/null 2>&1 &
		sleep 4
		sudo -u www-data php /var/www/rpicam/schedule.php > /dev/null 2>&1 &

	}

	if [ "$1" = 'stop' ]; then

		Raspimjeg_Stop

	elif [ "$1" = 'start' ]; then

		Raspimjeg_Start

	fi

	exit 0
}
