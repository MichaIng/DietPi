# Copilot Instructions for DietPi

## Project Overview

DietPi is an extremely lightweight Debian-based OS optimised for single-board computers (SBCs) and x86/x86_64 systems. The entire codebase is written in **Bash shell scripting** — there is no build or compile step.

## Repository Structure

- `dietpi/` — Main DietPi scripts (dietpi-software, dietpi-config, dietpi-update, etc.)
- `dietpi/func/` — Shared global functions and variables (`dietpi-globals` is sourced by all scripts)
- `dietpi/misc/` — Miscellaneous helper scripts
- `rootfs/` — Files placed onto the root filesystem
- `.conf/` — Configuration file templates
- `.build/` — Build-related scripts and resources
- `.update/` — Patches applied during DietPi updates
- `.meta/` — Metadata and one-off migration scripts
- `.github/` — GitHub Actions workflows, issue templates, and contribution guidelines

## Coding Conventions

### Shell Scripting Style

- All scripts use `#!/bin/bash` shebang and wrap the entire body in a single `{ ... }` block.
- Script header comments follow this pattern:
  ```bash
  #!/bin/bash
  {
  	#////////////////////////////////////
  	# DietPi-<ScriptName>
  	#
  	#////////////////////////////////////
  	# Created by Daniel Knight / daniel.knight@dietpi.com / dietpi.com
  	#
  	#////////////////////////////////////
  	#
  	# Info:
  	# - Location: /boot/dietpi/dietpi-<scriptname>
  	# - <description>
  	#////////////////////////////////////
  ```
- Use **tabs** for indentation (not spaces).
- Avoid trailing whitespace on any line.
- No more than one consecutive blank line anywhere in a file.

### DietPi Globals (`dietpi-globals`)

All DietPi scripts source `/boot/dietpi/func/dietpi-globals` at the top and call `G_INIT` to initialise the environment:

```bash
. /boot/dietpi/func/dietpi-globals
readonly G_PROGRAM_NAME='DietPi-<Name>'
G_CHECK_ROOT_USER "$@"
G_CHECK_ROOTFS_RW
G_INIT
```

Key global conventions:
- Global variables and functions are prefixed with `G_` (e.g., `G_EXEC`, `G_DIETPI-NOTIFY`, `G_WHIP_BUTTON`).
- Use `G_EXEC` instead of bare commands when you want automatic error handling, logging, and retry support.
- Use `G_DIETPI-NOTIFY` for user-facing output (levels: 0=info, 1=warning, 2=error, 3=phase/step header).
- Use `G_WHIP_*` functions for interactive whiptail menus.
- Use `G_AGI` / `G_AGA` / `G_AGP` / `G_AGU` as wrappers around `apt-get install/autoremove/purge/update`.
- Hardware info is available through `G_HW_MODEL`, `G_HW_ARCH`, `G_HW_MEMORY_SIZE`, etc.

### Variable Naming

- Global (script-wide) variables: `UPPER_SNAKE_CASE`.
- Local variables inside functions: use `local` keyword.
- Array variables: prefixed with `a` (e.g., `aSOFTWARE_INSTALL_STATE`).
- Avoid unnecessary subshells; prefer `[[ ... ]]` over `[ ... ]`.

### ShellCheck

All shell scripts are linted with [ShellCheck](https://github.com/koalaman/shellcheck). The global disabled rules are listed in `.shellcheckrc`. Do not introduce new ShellCheck violations. Per-file or per-line disables should be used sparingly and only with justification.

## Development Workflow

- The **active development branch is `dev`**. All pull requests must target `dev`, not `master`.
- `master` is the stable release branch.
- Changes are tested on actual DietPi hardware or VMs before merging.
- There is no automated test suite; correctness is validated manually and through CI shellcheck.

## CI / Linting

The primary CI check is **ShellCheck** (`.github/workflows/shellcheck.yml`), which:
1. Checks all files with a `.sh` extension or a shell shebang line.
2. Runs shellcheck with `-xo all` (all optional checks enabled).
3. Checks for trailing whitespace.
4. Checks for multiple consecutive blank lines.

**Before submitting changes, ensure:**
- `shellcheck` passes with no new warnings or errors.
- No trailing whitespace is introduced.
- No multiple consecutive blank lines are introduced.

## Software Titles (dietpi-software)

When adding or modifying software installations in `dietpi/dietpi-software`:
- Each software title has a unique numeric ID.
- Install/uninstall/reinstall logic is structured in clearly labelled `# MENUS` and `# FUNCTIONS` sections.
- Use `G_AGI` to install APT packages and `G_EXEC` to run commands.
- Always handle uninstall logic that cleanly reverses the install.
- Update the software state array `aSOFTWARE_INSTALL_STATE` appropriately.
- Document new software IDs in the relevant wiki page.

## Useful Links

- [DietPi Documentation](https://dietpi.com/docs/)
- [DietPi Forum](https://dietpi.com/forum/)
- [How to add a new software title](https://github.com/MichaIng/DietPi/wiki/How-to-add-a-new-software-title)
- [ShellCheck checks reference](https://github.com/koalaman/shellcheck/wiki/Checks)
