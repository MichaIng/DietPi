DietPi Project Contribution
=============================================

#### Are you able to?:
- Provide feedback and/or test areas of DietPi, to improve the user experience [Contributing notes](https://github.com/MichaIng/DietPi/blob/master/CONTRIBUTING.md)
- Add another [software title](https://github.com/MichaIng/DietPi/wiki/How-to-add-a-new-software-title)
- Report bugs using the [template](https://github.com/MichaIng/DietPi/issues/new?template=bug_report.md)
- Compile software for our [supported platforms](https://dietpi.com/docs/hardware/)
- Improve/add more features to the DietPi [website](https://github.com/MichaIng/DietPi-Website) or [docs](https://github.com/MichaIng/DietPi-Docs)

If so, let us know! We are always looking for talented people who believe in the DietPi project, and, wish to contribute in any way you can.

#### Developers:
- Git coders: use the active development branch: [dev](https://github.com/MichaIng/DietPi/tree/dev).
- See [here](https://github.com/MichaIng/DietPi/blob/dev/BRANCH_SYSTEM.md) for repository branch guidance.
- Read below for developer-focused guidance and quick reference.

#### Other Links:
- [DietPi forum](https://dietpi.com/forum/)
- [Contribute page](https://dietpi.com/contribute.html)
- [Security policy](https://github.com/MichaIng/DietPi/security/policy)

#### Contact:
- micha@dietpi.com
- GitHub: [MichaIng/DietPi](https://github.com/MichaIng/DietPi)

## DietPi Script Development

The below guide should help contributors add or modify DietPi scripts under
`/boot/dietpi` with minimal friction. It focuses on safe extension points,
shared helpers, persistence conventions, and reviewer-friendly test plans.

Branch workflow
---------------
DietPi separates stable releases, pre-release testing and active development:

- `master`: stable release branch (production-ready).
- `beta`: public [pre-release testing branch](https://github.com/MichaIng/DietPi/blob/dev/BRANCH_SYSTEM.md).
- `dev`: active [development branch](https://github.com/MichaIng/DietPi/tree/dev) — implement new features and fixes here.

Guidance:

- Target `dev` for code contributions and open PRs against it unless asked otherwise.
- Switching branches on-device:
  - Fresh image: edit `/boot/dietpi.txt` and change `DEV_GITBRANCH=` then reboot.
  - Existing install: run `dietpi-backup` first, then use `G_DEV_BRANCH beta` or `G_DEV_BRANCH dev` to switch.
- Warnings: `dev` and `beta` can be unstable; avoid using them on critical systems. Always include a Test Plan and restore steps in PRs when testing pre-release branches.

Core concepts
-------------
- Globals: scripts source `func/dietpi-globals` for shared helpers and
  environment setup (`G_INIT`, `G_EXIT`, color vars, etc.). Read this file
  first to understand helper semantics and cancel/error behavior.
- UI: prefer `G_WHIP_*` dialog helpers for menus, input and confirmations to
  maintain a consistent user experience across scripts.
- Persistence: use `FP_SAVEFILE` / `FP_SETTINGS` to write small shell-sourcable
  files. Persist arrays as indexed assignments (e.g. `aENABLED[3]=1`) to
  preserve compatibility across edits.
- Safe system changes: use `G_EXEC` for any commands that modify the system so
  DietPi's error handling and reporting apply. Always validate root/write
  access using `G_CHECK_ROOT_USER` / `G_CHECK_ROOTFS_RW` where required.

Helper functions (G_ helpers)
-----------------------------
DietPi provides many `G_` prefixed helpers in `func/dietpi-globals`. Below
are the most useful ones for contributors and how to use them safely.

- `G_INIT` — initialize script runtime, set traps, and handle concurrent
  execution checks. Call early after sourcing globals. It sets up `G_EXIT`.

- `G_EXIT` — cleanup/exit handler registered by `G_INIT`. Avoid overriding
  unless you re-register a compatible trap; use `G_EXIT` to ensure proper
  teardown on SIGINT/EXIT.

- `G_EXEC` — robust command executor with built-in retries and an interactive
  error handler. Use instead of direct `rm`/`systemctl` in scripts so
  failures are presented to the user and logged consistently. Optional
  env vars: `G_EXEC_DESC`, `G_EXEC_RETRIES`, `G_EXEC_OUTPUT`.

- `G_CONFIG_INJECT` — targeted config-file editing helper. Use to atomically
  replace or add config lines using predictable patterns rather than ad-hoc
  `sed` calls.

- `G_WHIP_*` family — dialog and UI helpers (`G_WHIP_MENU`,
  `G_WHIP_CHECKLIST`, `G_WHIP_INPUTBOX`, `G_WHIP_YESNO`, `G_WHIP_VIEWFILE`).
  Prefer these for user interaction to maintain consistent UX and behavior.

G_WHIP specifics
----------------
These details are commonly needed when implementing menus and input boxes.

- `G_WHIP_INPUTBOX`:
  - Use `G_WHIP_INPUTBOX_REGEX` to provide a validation regex and
    `G_WHIP_INPUTBOX_REGEX_TEXT` to describe allowed input (human-friendly).
  - `G_WHIP_DEFAULT_ITEM` pre-fills the input field. The helper loops until
    input matches the regex or the user cancels (`|| return`).
  - On success the entered value is returned in `$G_WHIP_RETURNED_VALUE`.

- `G_WHIP_YESNO`:
  - Presents a Yes/No dialog. Exit status `0` indicates Yes; non-zero is
    No or cancel. Some helper versions may also set `$G_WHIP_RETURNED_VALUE`.
  - Use for confirmations before destructive actions. Combine with
    `G_EXEC` for safe command execution on confirmation.

- `G_WHIP_DEFAULT_ITEM`:
  - Controls the pre-selected menu item or prefilled input box value.
  - When using `G_WHIP_MENU`, set it to a label matching one of the menu
    entries to pre-select that entry (exact match is used).

- `G_WHIP_SIZE_X_MAX`:
  - Optional integer to limit dialog width (chars). Useful for very long
    content to keep dialogs within readable proportions on narrow terminals.
  - Set it before calling a `G_WHIP_*` helper; the helper respects it when
    calculating `WHIP_SIZE_X`.

- `G_CHECK_ROOT_USER`, `G_CHECK_ROOTFS_RW` — validate that the script runs
  with necessary privileges and writable rootfs before performing writes.

- `G_GET_NET`, `G_GET_WAN_IP` — network helpers that return standardized
  values; use `-q` to request raw values suitable for scripting.

- `G_TRUNCATE_MID` — utility to shorten long strings with `...` in the
  middle; useful for CLI-friendly output.

- `G_DIETPI-NOTIFY` / `G_BUG_REPORT` — helpers to generate formatted bug
  reports and diagnostics. Use when capturing logs for PRs / issues.

Usage hints:
- Read `func/dietpi-globals` when adding behavior that interacts with the
  user, modifies files, or runs external commands — it documents optional
  environment variables and exit/cancel semantics for each helper.
- Prefer the `G_` helpers over ad-hoc implementations to keep error handling
  consistent and reduce reviewer friction.

Menu extension pattern (safe, minimal)
--------------------------------------
1. Add handler: implement `Menu_<Name>()` to present inputs (use `G_WHIP_*`),
   validate, and update in-memory variables (e.g. `aENABLED[index]`).
2. Register option: add the menu label into `Menu_Main()` (scripts use a
   case-switch dispatch). Remember to update `MENU_LASTITEM_*` indices if used.
3. Persist: call `Save` or `Write_Settings_File()` to write to `FP_SAVEFILE`.
   Persist arrays as `aENABLED[index]=...` lines; convert ESC bytes to `\e`
   when saving color slots if needed.
4. Test: include interactive steps in your PR Test Plan (open menu, toggle,
   verify `cat /boot/dietpi/.<prog_settings>`).

Practical snippets (quick reference)
-----------------------------------
Below are minimal, copy-paste-ready examples that follow DietPi conventions.

- `G_WHIP_MENU` (single choice):
```
G_WHIP_MENU_ARRAY=( 'Start' 'Start the service' 'Stop' 'Stop the service' )
G_WHIP_DEFAULT_ITEM='Start'
G_WHIP_MENU 'Select action:' || return
case $G_WHIP_RETURNED_VALUE in
  Start) echo 'Starting...';;
  Stop) echo 'Stopping...';;
esac
```
- `G_WHIP_CHECKLIST_ARRAY` (multi-select):
```
G_WHIP_CHECKLIST_ARRAY=()
G_WHIP_CHECKLIST_ARRAY+=( '5' 'Enable Foo' "${aENABLED[5]:=0}" )
G_WHIP_CHECKLIST_ARRAY+=( '6' 'Enable Bar' "${aENABLED[6]:=0}" )
G_WHIP_CHECKLIST 'Choose features to enable:' || return
for i in $G_WHIP_RETURNED_VALUE; do aENABLED[$i]=1; done
Save > "$FP_SAVEFILE"
```
- `G_WHIP_INPUTBOX` (validated input):
```
G_WHIP_INPUTBOX_REGEX='^[0-9]+$' G_WHIP_INPUTBOX_REGEX_TEXT='a number' G_WHIP_DEFAULT_ITEM=10
G_WHIP_INPUTBOX 'Set retry count:' || return
RETRIES=$G_WHIP_RETURNED_VALUE
```
- `G_WHIP_YESNO` (confirmation):
```
if G_WHIP_YESNO 'Delete backup?'; then
  G_EXEC rm -rf "$TARGET"
fi
```
- `G_WHIP_VIEWFILE` (show a logfile):
```
log=1 G_WHIP_VIEWFILE "$FP_LOG" || return
```
- `Save()` persistence pattern (follow dietpi-banner conventions):
```
Save(){
  echo "aDESCRIPTION[10]='${aDESCRIPTION[10]}'"
  for i in "${!aENABLED[@]}"; do echo "aENABLED[$i]=${aENABLED[$i]}"; done
  for i in {0..6}; do val="${aCOLOUR[$i]}"; esc=$(printf '%s' "$val" | sed $'s/\x1b/\\e/g'); esc=${esc//\'/\\\'}; echo "aCOLOUR[$i]='$esc'"; done
}
```

Banner extension pattern (example)
----------------------------------
When adding banner items (e.g. `dietpi-banner`), follow this minimal pattern:

- Describe: add the label to `aDESCRIPTION[index]` and a default to
  `aENABLED[index]` during initialization.

- Output: implement `Print_<ShortName>()` or add a guarded line in `Print_Banner_raw()`:
```
(( ${aENABLED[index]} )) && echo -e "$GREEN_BULLET ${aCOLOUR[1]}${aDESCRIPTION[index]} $GREEN_SEPARATOR $(Print_<ShortName>)"
```
- Persist: ensure `Save()` writes `aENABLED[index]=...` and any custom
  `aDESCRIPTION[...]` lines so the state survives restarts.

Nested / multi-page menu pattern
--------------------------------
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

AWK wrapper call (word-wrap helper)
-----------------------------------

Purpose: wrap banner lines to a target column while ignoring terminal
colour codes and aligning content after bullets or colons.

Call example:
```
mawk -v "MAXCOL=$(tput cols)" -v "INDENT_TYPE=$BW_INDENT_TYPE" -v "INDENT_FIXED=$BW_INDENT_FIXED" -f "$FP_BANNERWRAP_AWK"
```
Key options:
- `INDENT_TYPE`: `colon` | `dash` | `fixed` (controls how indent is calculated)
- `INDENT_FIXED`: integer used when `INDENT_TYPE=fixed`

Quick test:
```
printf '%s\n' " - Example: Let's Encrypt cert status: https://example.com | long text to wrap" | mawk -v "MAXCOL=50" -v "INDENT_TYPE=colon" -v "INDENT_FIXED=3" -f "$FP_BANNERWRAP_AWK"
```
See `func/dietpi-banner-wrap.awk` for full implementation details.