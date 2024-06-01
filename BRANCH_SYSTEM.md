## Steps to use the DietPi "beta" branch
#### This is the pre-release branch for public testing and may potentially be unstable.
The goal of the beta branch, is to allow for public testing of our next release. Once testing has passed, and, all issues have been resolved, the beta branch will then be set live on our stable branch (master). We will apply updates to the beta branch during pre-release phases, you will then see an update notification. By running `dietpi-update` your beta version will then update to the latest.

By joining the Beta and reporting issues, you will be assisting DietPi (and all our users) to ensure stability before stable release.

#### Beta on a fresh image:
1. Write the DietPi image to SD card.
2. Open the file `/boot/dietpi.txt` on the 1st partition.
3. Change `DEV_GITBRANCH=master` to `DEV_GITBRANCH=beta` (located near the bottom of the file).
4. Save the file, eject media and power on.

#### Beta on an existing installation:
1. Recommended: Backup your system with `dietpi-backup` (or backup quickly with `dietpi-backup 1`).
2. Run the following command to switch to "beta" branch:
    ```sh
    G_DEV_BRANCH beta
    ```
3. Test away, please report any issues on our GitHub page. Also ensure you mention "beta branch" in your post: https://github.com/MichaIng/DietPi/issues
4. If you want to return the system to the previous restore state, run `dietpi-backup` to restore (or restore quickly with `dietpi-backup -1`).

## Steps to use the DietPi "dev" branch
#### This is the active development branch. It is potentially unstable, unsupported and should not be used by end users.
1. Same as above, however, use `G_DEV_BRANCH dev` instead.
