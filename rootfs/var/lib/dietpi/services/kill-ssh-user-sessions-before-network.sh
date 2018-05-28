#!/bin/bash

if pgrep -i 'sshd' &> /dev/null; then

	killall -w sshd

elif pgrep -i 'dropbear' &> /dev/null; then

	killall -w dropbear

fi

exit 0
