#!/bin/bash

# "G_DIETPI-NOFITY -2 message" starts a process animation.
# If scripts fail to kill the animation, e.g. cancelled by user, terminal PS1 promt has to do it as last resort:
PS1="\\[\$([[ -w /tmp/dietpi-process.pid ]] && rm /tmp/dietpi-process.pid && tput cub 9 && tput ed)\\]$PS1"
