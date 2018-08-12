#!/bin/bash

if pgrep 'sshd' &> /dev/null; then

	killall -w sshd

elif pgrep 'dropbear' &> /dev/null; then

	killall -w dropbear

fi

exit 0
