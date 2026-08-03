# DietPi Project Contribution

Are you able to:

- Provide feedback and/or test areas of DietPi, to improve the user experience?
- Report bugs using the [this template](https://github.com/MichaIng/DietPi/issues/new?template=bug_report.md)?
- Improve or add features to DietPi, our [website](https://github.com/MichaIng/DietPi-Website) or [documentation](https://github.com/MichaIng/DietPi-Docs)?
- Add new [software titles](https://github.com/MichaIng/DietPi/wiki/How-to-add-a-new-software-title)?
- Implement support for new single-board computers?

If so, let us know! We are always looking for talented people who believe in the DietPi project, and, wish to contribute in any way you can.

## Developers

- Git coders: use the active development branch: [dev](https://github.com/MichaIng/DietPi/tree/dev).
- See [here](https://github.com/MichaIng/DietPi/blob/dev/BRANCH_SYSTEM.md) for repository branch guidance.
- Read below for developer-focused guidance and quick reference.

## Other Links

- [DietPi website](https://dietpi.com/)
- [DietPi documentation](https://dietpi.com/docs/)
- [DietPi forum](https://dietpi.com/forum/)
- [DietPi blog](https://dietpi.com/blog/)
- [Contribute page](https://dietpi.com/contribute.html)
- [Security policy](https://github.com/MichaIng/DietPi/security/policy)

## Contact

- <micha@dietpi.com>
- GitHub: [MichaIng/DietPi](https://github.com/MichaIng/DietPi)

## DietPi Script Development

The below guide should help contributors add or modify DietPi scripts under
`/boot/dietpi` with minimal friction. It focuses on safe extension points,
shared helpers, persistence conventions, and reviewer-friendly test plans.

### Branch workflow

The DietPi Git repository is separated into three branches:

- `master`: stable release branch (production-ready).
- `beta`: public [pre-release testing branch](https://github.com/MichaIng/DietPi/blob/dev/BRANCH_SYSTEM.md).
- `dev`: active [development branch](https://github.com/MichaIng/DietPi/tree/dev) — implement new features and fixes here.

Guidance:

- Target `dev` for code contributions and open PRs against it unless asked otherwise.
- Switching branches on your DietPi device:
  - Fresh image: Before first boot, edit `dietpi.txt` on the FAT partition of the flashed image, and change `DEV_GITBRANCH=`. Adjust `DEV_GITOWNER=` accordingly, if you want to switch to your fork of DietPi.
  - Existing install: run `dietpi-backup` first, then use `G_DEV_BRANCH beta` or `G_DEV_BRANCH dev` to quickly to the respective branch, invoking `dietpi-update`.
- Warning: `beta` and especially `dev` can be unstable; avoid using them on critical production systems. Have a `dietpi-backup`, or do tests on a dedicated testing system.

### Core concepts

- Globals: scripts source `dietpi/func/dietpi-globals` for shared helpers and
  environment setup (`G_INIT()`, `G_EXIT()`, color vars, etc.). Read this file
  first to understand helper semantics and cancel/error behavior.
- UI: prefer `G_WHIP_*` dialog helpers for menus, input and confirmations to
  maintain a consistent user experience across scripts.
- Error-handling: use `G_EXEC()` to wrap any command call, so DietPi's error
  handler and consistent console output apply. Validate root permissions and
  write access using `G_CHECK_ROOT_USER()` / `G_CHECK_ROOTFS_RW()` where required.
- Persistence: Write arrays or variables into a preference file `/boot/dietpi/.<prog_settings>`.
  Persist arrays as indexed assignments (e.g. `aARRAY[index]=1`). Convert ESC bytes to `\e`
  when saving text if needed. Load the preferences with `. "/boot/dietpi/.<prog_settings>"`

### Helper functions (G_ helpers)

DietPi provides many `G_` prefixed helpers in `dietpi/func/dietpi-globals`. Usage hints:
- Read `dietpi/func/dietpi-globals` when adding behavior that interacts
  with the user, modifies files, or runs external commands — it documents
  optional environment variables and exit/cancel semantics for each helper.
- Prefer the `G_` helpers over ad-hoc implementations to keep error handling
  consistent and reduce reviewer friction.

Below are the most useful ones for contributors and how to use them safely.
- `G_INIT()` — initialize script runtime, sets up the working directory, exit
   traps, consistent locale for parsing external command outputs, and handles
   concurrent execution checks. Call early after sourcing `dietpi-globals`.

- `G_EXEC()` — robust command executor with built-in retries and an interactive
  error handler. Use instead of direct `rm`/`systemctl` in scripts so
  failures are presented to the user and logged consistently. Optional
  env vars: `$G_EXEC_DESC`, `$G_EXEC_RETRIES`, `$G_EXEC_OUTPUT`.

- `G_CHECK_ROOT_USER()`, `G_CHECK_ROOTFS_RW()` — validate that the script runs
  with necessary privileges and writable rootfs before performing writes.
  Using `G_CHECK_ROOT_USER "$@"`, if the script does not have root permissions,
  re-executes with `sudo`. "$@" passes all CLI arguments to the `sudo-ed` script.

- `G_CONFIG_INJECT()` — targeted config-file editing helper. Use to atomically
  replace, uncomment, or add config lines using predictable patterns rather
  than ad-hoc `sed` calls.

- `G_GET_NET()`, `G_GET_WAN_IP()` — network helpers that return standardized
  values; use `-q` to hide error messages.

- `G_DIETPI-NOTIFY()` / `G_BUG_REPORT()` — helpers to generate formatted bug
  reports and diagnostics. Use when capturing logs for PRs / issues.

- `G_WHIP_*` family — dialog and UI helpers: (`G_WHIP_MSG()`, `G_WHIP_YESNO()`,
  `G_WHIP_MENU()`, `G_WHIP_CHECKLIST()`, `G_WHIP_INPUTBOX()`, `G_WHIP_PASSWORD()`,
  `G_WHIP_VIEWFILE()`). Prefer these for user interaction to maintain
  consistent UX and behavior. Quick notes:

  - **Return value**: `$G_WHIP_RETURNED_VALUE` holds the helper result — a
    single value for inputbox and menus, or an array of enabled indices for checklists.
  - **Default item**: `$G_WHIP_DEFAULT_ITEM` sets the pre-selected value. For
    `G_WHIP_MENU()` it must exactly match a menu label.
  - **Checklist structure**: `$G_WHIP_CHECKLIST_ARRAY` entries are triples:
    `'tag' 'Description' 'on/off'`. Use safe tags (letters, digits, underscore)
    to avoid parsing issues.
  - **Enumerated checklists**: set `G_WHIP_CHECKLIST_ENUM=1` to display numeric
    indices in the UI to avoid long, complex, or non-safe keys.
  - **Input validation**: `G_WHIP_INPUTBOX()` supports `$G_WHIP_INPUTBOX_REGEX`
    and `$G_WHIP_INPUTBOX_REGEX_TEXT` to validate and describe allowed input.
    The helper loops until input matches the regex or the user cancels (`|| return`).
  - **Dialog sizing**: use `$G_WHIP_SIZE_X_MAX` to limit dialog width; helpers
    respect terminal width and default to a max of 120 chars.

### Menu extension pattern (safe, minimal)

1. Add handler: implement `Menu_<Name>()` to present inputs (use `G_WHIP_*`),
   validate, and update in-memory variables (e.g. `aENABLED[index]`).
2. Register option: add the menu label into `Menu_Main()` (scripts use a
   case-switch dispatch). Remember to update `$MENU_LASTITEM_*` indices if used.
3. Persist: Write arrays or variables into a preference file (see the 'Core concepts' section).
4. Test: include interactive steps in your PR Test Plan (open menu, toggle,
   verify `cat /boot/dietpi/.<prog_settings>`).

### Practical snippets (quick reference)

Below are minimal, copy-paste-ready examples that follow DietPi conventions.

- A typical script header
  ```
  . /boot/dietpi/func/dietpi-globals
  readonly G_PROGRAM_NAME='DietPi-DevTest'
  G_CHECK_ROOT_USER "$@" # if the script requires root permissions
  G_CHECK_ROOTFS_RW # if the script requires write access
  G_INIT
  ```

- `G_WHIP_MENU()` a menu of items the user can scroll through (choose one):
  ```
  G_WHIP_MENU_ARRAY=( 'Start' 'Start the service' 'Stop' 'Stop the service' )
  G_WHIP_DEFAULT_ITEM='Start'
  G_WHIP_MENU 'Select action:' || return
  case $G_WHIP_RETURNED_VALUE in
    Start) echo 'Starting...';;
    Stop) echo 'Stopping...';;
  esac
  ```
  
- `G_WHIP_CHECKLIST()` a list of items the user can enabled/disabled (multi-select):
  ```
  G_WHIP_CHECKLIST_ARRAY=()
  G_WHIP_CHECKLIST_ARRAY+=( '5' 'Enable Foo' "${aENABLED[5]:=0}" )
  G_WHIP_CHECKLIST_ARRAY+=( '6' 'Enable Bar' "${aENABLED[6]:=0}" )
  # Set G_WHIP_CHECKLIST_ENUM=1 to display numeric indices in the UI
  G_WHIP_CHECKLIST 'Choose features to enable:' || return
  for i in $G_WHIP_RETURNED_VALUE; do aENABLED[$i]=1; done
  Save > "$FP_SAVEFILE"
  ```
  
- `G_WHIP_INPUTBOX()` a text entry box (validated input):
  ```
  G_WHIP_INPUTBOX_REGEX='^[0-9]+$' G_WHIP_INPUTBOX_REGEX_TEXT='a number' G_WHIP_DEFAULT_ITEM=10
  G_WHIP_INPUTBOX 'Set retry count:' || return
  RETRIES=$G_WHIP_RETURNED_VALUE
  ```
  
- `G_WHIP_YESNO()` Yes/No prompt (confirmation):
  ```
  if G_WHIP_YESNO 'Delete backup?'; then
    G_EXEC rm -rf "$TARGET"
  fi
  ```
  
- `G_WHIP_VIEWFILE()` displays a file that can be scrolled:
  ```
  log=1 G_WHIP_VIEWFILE "$FP_LOG" || return
  ```
  
- `G_TRUNCATE_MID()` shorten long strings by squishing the middle characters:
  ```
  G_TRUNCATE_MID "Long text to be shortened by removing the middle" 26
  # -> "Long text to... the middle"

  # And `G_TRUNCATE_MID "alphabetical" N` returns the below, as N decreases
  # alp...al
  # al...al
  # alphab
  # alpha
  # alph
  # alp
  ```

- `Save()` example persistence pattern (beware of escape sequences):
  ```
  Save(){
    # `echo` text to be eval-ed when re-loading
    # Call with `Save > "preference/file/path"`
    echo "aDESCRIPTION[10]='${aDESCRIPTION[10]}'"
    for i in "${!aENABLED[@]}"; do echo "aENABLED[$i]=${aENABLED[$i]}"; done
    for i in {0..6}; do val="${aCOLOUR[$i]}"; esc=$(printf '%s' "$val" | sed $'s/\x1b/\\e/g'); esc=${esc//\'/\\\'}; echo "aCOLOUR[$i]='$esc'"; done
  }
  ```

### DietPi-Banner extension pattern

When adding banner items, follow this minimal pattern:

- Describe: add the label to `aDESCRIPTION[index]` and a default to
  `aENABLED[index]` during initialization if relevant (the standard default is disabled=0).
  If the item needs to show in the main menu checklist, add `index` to MENU_ITEMS.

- Output: implement `Get_<Shortname>()` and add a guarded line in `Print_Banner_raw()`:
  ```
  (( ${aENABLED[index]} )) && Print_Item_State "${aDESCRIPTION[index]}" "$(Get_Shortname 2>&1)"
  ```
  
- Persist: ensure `Save()` writes `aENABLED[index]=...` so the state survives restarts.

### Nested / multi-page menu pattern

```
TARGETMENUID=0  # start at the top level main menu
while (( TARGETMENUID != -1 )); do
  case $TARGETMENUID in
    0) Menu_Main; ;;  # sets TARGETMENUID based on selection
    1) Menu_Settings; TARGETMENUID=0 ;;  # run settings page then return to main menu
    -1) break;;
  esac
done
```
