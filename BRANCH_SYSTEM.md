## Steps to use the DietPi "beta" branch.
#### This is the pre-release branch for public testing and may potentially be unstable.

Fresh image:
1. Write the DietPi image to SD card.
2. Open the file on the 1st partition ```/boot/dietpi.txt```
3. Change ```DEV_GITBRANCH=master``` to ```DEV_GITBRANCH=beta``` (located at the bottom of file)
4. Save the file, eject media and power on.

Existing installation:
1. Recommended: Backup your system with ```dietpi-backup``` (or backup quickly with ```dietpi-backup 1```)
2. Run the following command to switch to 'beta' branch: 
```
G_CONFIG_INJECT 'DEV_GITBRANCH=' 'DEV_GITBRANCH=beta' /DietPi/dietpi.txt
```
3. Run ```dietpi-update``` and reboot system
4. Test away.
5. If you want to return the system to the previous restore state, run ```dietpi-backup``` to restore (or restore quickly with ```dietpi-backup -1```)

## Steps to use the DietPi "dev" branch.
#### This is the active development branch. Its potentially unstable, unsupported and should not be used by end users.

1. Same as above, however, use ```DEV_GITBRANCH=dev``` instead
