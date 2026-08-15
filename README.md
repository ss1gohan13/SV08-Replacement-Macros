# SV08 Replacement Macros

A replacement and enhancement package for the Sovol SV08 Klipper macros, with an interactive installer for macro installation, configuration management, hardware utilities, backups, diagnostics, and optional Klipper features.

The installer is designed to simplify replacing the stock SV08 macro configuration while preserving backups of the files it modifies.

---

## How to Install the Macros

### 1. SSH into your printer

Connect to your printer using your preferred SSH client.

### 2. Clone the repository

```bash
cd ~
git clone https://github.com/ss1gohan13/SV08-Replacement-Macros.git
cd SV08-Replacement-Macros
```

### 3. Launch the installer

```bash
./install-macros.sh
```

The installer opens an interactive menu containing installation, configuration, backup, diagnostic, and maintenance options.

From the main menu, select:

```text
1) Install SV08 Replacement Macros
```

Then select:

```text
1) Install standard SV08 macros
```

---

## What the Standard Installation Does

When installing the standard SV08 replacement macros, the installer:

* Verifies the Klipper configuration directory.
* Creates a backup directory if one does not already exist.
* Stops Klipper before modifying configuration files.
* Allows additional user macro files to be identified for backup.
* Backs up the existing `macros.cfg`.
* Backs up `printer.cfg` before modifying it.
* Downloads and installs the latest replacement `macros.cfg`.
* Automatically installs the required `gcode_shell_command` Klipper extension if it is not already installed.
* Checks and configures the part cooling fan for compatibility with the replacement `M106` and `M107` macros.
* Ensures `[include macros.cfg]` is present in `printer.cfg`.
* Comments out conflicting or replaced macro includes when applicable.
* Offers Fluidd or Mainsail configuration.
* Adds or verifies `[force_move]`.
* Adds the required extruder safety settings.
* Restarts Klipper after the installation is complete.

> [!NOTE]
> Backups are stored in the `backup` directory inside your Klipper configuration directory. With the default Klipper configuration path, this is:
>
> ```text
> ~/printer_data/config/backup/
> ```

---

## Part Cooling Fan Configuration

The replacement `M106` and `M107` macros expect the primary part cooling fan to be configured as:

```ini
[fan_generic fan]
```

The installer checks the existing fan configuration automatically during installation.

### Already Compatible

If the installer finds a valid:

```ini
[fan_generic fan]
pin: ...
```

no changes are made.

### Stock Sovol SV08 Fan Configuration

If the installer detects the stock Sovol dual part-cooling fan layout using:

```ini
[fan_generic fan0]
```

and:

```ini
[fan_generic fan1]
```

it will attempt to combine both physical fan outputs into a single logical part cooling fan using:

```ini
[multi_pin print_cooling_fan_pins]
```

and:

```ini
[fan_generic fan]
pin: multi_pin:print_cooling_fan_pins
```

Existing fan control settings are preserved when the two stock fan sections use compatible settings.

If the installer determines that the two fan configurations cannot safely be combined, automatic migration is skipped and the user is given configuration options instead.

### Rappetor / Mainline Configuration

If the installer detects a configuration using:

```ini
[multi_pin print_cooling_fan_pins]
```

with:

```ini
[fan]
pin: multi_pin:print_cooling_fan_pins
```

the existing `[fan]` section is converted to:

```ini
[fan_generic fan]
```

while preserving the existing fan settings.

### Custom Fan Configurations

If the installer cannot confidently identify the existing part cooling fan configuration, it will display any compatible `[fan]` or `[fan_generic ...]` sections it finds.

The user can then:

* Reuse an existing fan section as `[fan_generic fan]`.
* Enter the part cooling fan pin manually.
* Skip fan configuration.

If a fan section is reused, the entire existing section is renamed so its current settings are preserved.

### Manual Pin Configuration

If a pin is entered manually, the installer checks whether that pin is already referenced elsewhere in `printer.cfg`.

If the pin is already in use, a warning is displayed before the installer allows the user to continue. This helps prevent accidental Klipper `pin used multiple times` configuration errors.

A manually created configuration will look similar to:

```ini
# Part cooling fan
# Added by SV08 Replacement Macros
[fan_generic fan]
pin: <YOUR_PIN>
```

> [!IMPORTANT]
> If fan configuration is skipped, `[fan_generic fan]` must be configured manually before the replacement `M106` and `M107` macros can control the primary part cooling fan.

---

## M106 and M107 Fan Control

The replacement macros include custom `M106` and `M107` commands for slicer-compatible fan control.

The current fan mapping is:

```text
No P parameter  -> fan
P2              -> AUX
P3              -> Exhaust
```

### M106

`M106` converts the standard `S0-S255` fan speed range to Klipper's `0.0-1.0` fan speed range.

Examples:

```gcode
M106 S255
```

Sets the primary part cooling fan to 100%.

```gcode
M106 S128
```

Sets the primary part cooling fan to approximately 50%.

```gcode
M106 P2 S255
```

Sets the AUX fan to 100%, if `[fan_generic AUX]` is configured.

```gcode
M106 P3 S255
```

Sets the Exhaust fan to 100%, if `[fan_generic Exhaust]` is configured.

A special case is included for:

```gcode
M106 S0
```

When no `P` parameter is specified, this turns off all configured fans in the fan map.

### M107

Running:

```gcode
M107
```

turns off all configured fans in the fan map.

A specific fan can also be turned off using its `P` value.

Examples:

```gcode
M107 P2
```

Turns off AUX.

```gcode
M107 P3
```

Turns off Exhaust.

Fans that are not configured are ignored or generate a warning instead of preventing the macro from operating.

---

## Interactive Installer

Running:

```bash
./install-macros.sh
```

opens the main installer menu.

The current menu provides access to:

```text
1) Install SV08 Replacement Macros
2) Hardware Configuration Utilities
3) Additional Features & Extensions
4) Backup Management
5) Diagnostics & Troubleshooting
6) Software Management
7) Uninstall
0) Exit
```

---

## Installation Options

The macro installation menu provides:

```text
1) Install standard SV08 macros
2) Install A Better Print_Start Macro
3) Install A Better End Print Macro
```

### Standard SV08 Macros

Installs the replacement `macros.cfg` and performs the standard configuration process described above.

### A Better Print_Start Macro

The installer can optionally install the separate **A Better Print_Start Macro** project.

Project repository:

https://github.com/ss1gohan13/A-better-print_start-macro

KAMP is installed as part of this process because it is required by the Print_Start setup.

Slicer configuration changes may also be required after installation.

### A Better End Print Macro

The installer can optionally install the separate **A Better End Print Macro** project.

Project repository:

https://github.com/ss1gohan13/A-Better-End-Print-Macro

Slicer end G-code changes may be required after installation.

---

## Additional Features & Extensions

The installer includes an Additional Features & Extensions menu containing:

```text
1) Install Print Start Macro
2) Install End Print Macro
3) Install KAMP
4) Install gcode_shell_command extension
5) Enable Eddy NG tap start print function
6) Install Numpy for ADXL Resonance Measurements
7) Install Crowsnest
8) Install Moonraker-Timelapse
```

### gcode_shell_command

`gcode_shell_command` is required by macros that execute shell commands on the Klipper host.

When the standard replacement macros are installed, the installer automatically checks for this extension and installs it if necessary.

It can also be installed independently from the Additional Features & Extensions menu.

### KAMP

KAMP can be installed independently or automatically as part of the A Better Print_Start Macro installation.

The installer creates the appropriate KAMP configuration link and installs `KAMP_Settings.cfg`.

### Numpy / ADXL

Numpy installation is available for users performing resonance measurements and input shaping with an ADXL accelerometer.

### Crowsnest

Crowsnest installation is available from the menu for webcam streaming support.

### Moonraker-Timelapse

Moonraker-Timelapse can also be installed from the Additional Features menu.

---

## Hardware Configuration Utilities

The installer includes a Hardware Configuration Utilities menu containing tools for:

```text
1) Check MCU IDs
2) Check CAN bus devices
3) Enable Eddy NG tap start print function
4) Configure firmware retraction
5) Configure force_move
6) Add extruder settings
7) Configure stepper drivers
```

These utilities can be used separately from the standard macro installation.

> [!CAUTION]
> Hardware configuration tools can modify important Klipper settings. Review the values being entered before applying changes.

---

## Backup Management

The installer contains a dedicated Backup Management menu.

Available options include:

```text
1) List all backups
2) Restore from backup
3) Clean old backups
```

### List Backups

Displays available backup files stored in the configured backup directory.

### Restore a Backup

Allows an individual backup to be selected and restored to its original configuration filename.

Klipper is restarted after the selected backup is restored.

### Clean Old Backups

Allows old backup files to be removed based on age.

The default retention period is:

```text
7 days
```

The installer displays the files that will be removed and asks for confirmation before deleting them.

---

## Diagnostics & Troubleshooting

The installer includes diagnostic tools for checking the Klipper installation and configuration.

Available options include:

```text
1) Check Klipper status
2) View Klipper logs
3) Verify configuration
4) Run full system diagnostics
```

### Configuration Verification

The verification utility checks items including:

* Whether `macros.cfg` exists.
* Whether `printer.cfg` includes `macros.cfg`.
* Whether the Klipper service is running.

### Full System Diagnostics

The full diagnostics option displays information including:

* System information.
* Disk usage.
* Memory usage.
* Klipper service status.
* Klipper configuration files.
* Active configuration includes.
* Available macros.
* Recent Klipper errors.

---

## Software Management

The Software Management menu provides:

```text
1) Install Kiauh
2) Update SV08 macros
3) Check for system updates
```

This allows common software maintenance functions to be accessed without leaving the installer.

---

## Command-Line Options

The installer also supports command-line options.

```text
Usage: ./install-macros.sh [-c <config path>] [-s <klipper service name>] [-u] [-l]
```

### Custom Klipper Configuration Path

```bash
./install-macros.sh -c /path/to/config
```

Use this when the Klipper configuration directory is not:

```text
~/printer_data/config
```

### Custom Klipper Service Name

```bash
./install-macros.sh -s <service-name>
```

The default service name is:

```text
klipper
```

### Uninstall

```bash
./install-macros.sh -u
```

Runs the uninstall process and restores the most recent available configuration backups.

### Linear Installation Mode

```bash
./install-macros.sh -l
```

Skips the main menu and runs the linear installation flow.

This is still an interactive installation and may prompt for configuration and optional components.

### Help

```bash
./install-macros.sh -h
```

Displays the available command-line options.

> [!IMPORTANT]
> Do not run the installer as `root`. The installer is intended to run as the normal Klipper host user and will refuse to continue when executed directly as root.

---

## How to Uninstall the Macros

The macros can be uninstalled either through the interactive menu or with the `-u` command-line option.

### Command-Line Uninstall

```bash
cd ~/SV08-Replacement-Macros
./install-macros.sh -u
```

The uninstall process:

* Verifies the Klipper configuration directory.
* Stops Klipper.
* Looks for the most recent available macro backups.
* Restores the most recent `macros.cfg` backup when available.
* Restores user-specified macro file backups when available.
* Restores the most recent `printer.cfg` backup when available.
* Removes the installed `macros.cfg` if no previous `macros.cfg` backup exists.
* Restarts Klipper.

After verifying that the original configuration has been restored successfully, the cloned repository can optionally be removed:

```bash
cd ~
rm -rf SV08-Replacement-Macros
```

---

# Major Macro Changes & Improvements

The SV08 Replacement Macros provide replacements and updates for a number of macros found in the original SV08 configuration.

## `_CLIENT_VARIABLE`

The previous `_global_var` approach has been replaced with the standard Fluidd/Mainsail-style:

```ini
[gcode_macro _CLIENT_VARIABLE]
```

Parking positions are calculated dynamically using the printer's configured X and Y axis maximums with a safety margin.

The macro also contains configurable values for:

* Pause parking.
* Cancel parking.
* Z-hop.
* Retraction.
* Unretraction.
* Movement speeds.
* Idle timeout.
* Filament runout sensor.
* User pause/resume/cancel hooks.

The default idle timeout value is:

```text
600 seconds / 10 minutes
```

---

## `PAUSE`, `RESUME`, and `CANCEL_PRINT`

The replacement configuration is designed to use the Fluidd or Mainsail client macro implementation for `PAUSE`, `RESUME`, and `CANCEL_PRINT`.

The included `_CLIENT_VARIABLE` section provides the SV08-specific behavior and parking configuration used by those client macros.

---

## `_ALL_FAN_OFF`

A compatibility helper remains available:

```gcode
_ALL_FAN_OFF
```

Fan shutdown is now primarily handled through the replacement `M106` and `M107` system.

---

## `CLEAN_NOZZLE`

`CLEAN_NOZZLE` has been updated for the SV08 nozzle cleaning workflow.

The macro handles preparation, nozzle cleaning movement, and heater behavior while preserving the printer's G-code state.

---

## `G29`

`G29` provides a combined gantry-leveling and bed-mesh workflow.

The macro:

* Homes the printer if required.
* Uses `GANTRY_LEVELING` when available.
* Falls back to `Z_TILT_ADJUST` or `QUAD_GANTRY_LEVEL` when appropriate.
* Re-homes Z when required after leveling.
* Runs adaptive `BED_MESH_CALIBRATE`.
* Re-homes Z after the mesh operation.

The underlying Klipper `BED_MESH_CALIBRATE` command remains available normally.

---

## `G34`

`G34` provides a gantry-leveling workflow with conditional homing.

It uses `GANTRY_LEVELING` when available and otherwise falls back to the configured QGL or Z-Tilt system.

---

## `GANTRY_LEVELING`

`GANTRY_LEVELING` automatically detects whether the printer is configured for:

```text
QUAD_GANTRY_LEVEL
```

or:

```text
Z_TILT_ADJUST
```

The leveling operation runs whenever the macro is called rather than refusing to run because a previous leveling operation was already applied.

Z is re-homed after the leveling process.

---

## `LOAD_FILAMENT`

`LOAD_FILAMENT` includes:

* Automatic nozzle heating.
* Configurable extrusion temperature.
* Fast filament loading.
* Controlled purge movement.
* Print-state checks to prevent filament loading during an active print.

Default parameters are provided but can be overridden when the macro is called.

---

## `UNLOAD_FILAMENT`

`UNLOAD_FILAMENT` includes:

* Automatic nozzle heating.
* Configurable extrusion temperature.
* Initial purge.
* Multi-stage retract movement.
* Filament cooling delay.
* Fast final unload.
* Print-state checks to prevent unloading during an active print.

---

## `M106` and `M107`

The replacement configuration provides custom slicer-compatible `M106` and `M107` fan control.

These macros use `[fan_generic ...]` fan sections and support:

```text
fan
AUX
Exhaust
```

The installer automatically handles the primary `[fan_generic fan]` configuration when possible.

See the **Part Cooling Fan Configuration** section above for details.

---

## `M600`

`M600` uses:

```gcode
PAUSE
```

for filament changes.

Filament parking and pause behavior should therefore be configured through `_CLIENT_VARIABLE` and the Fluidd/Mainsail client macros.

---

## `LIGHT`

The replacement macros include:

```gcode
LIGHT
```

This toggles the printer's configured main LED output on or off.

---

## `PROBE_CALIBRATE`

`PROBE_CALIBRATE` has been customized to prepare the printer before starting Klipper's normal probe calibration procedure.

The macro:

* Homes when required.
* Heats the nozzle to `150°C`.
* Uses a default bed temperature of `60°C`.
* Performs gantry leveling when configured.
* Re-homes Z after leveling when required.
* Continues into the Klipper probe calibration procedure.

The bed temperature can be overridden using:

```gcode
PROBE_CALIBRATE BED_TEMP=<temperature>
```

---

## `START_PRINT`

`START_PRINT` is not included as part of the standard replacement `macros.cfg`.

The installer provides the optional **A Better Print_Start Macro** package for users who want the enhanced print-start workflow.

Project repository:

https://github.com/ss1gohan13/A-better-print_start-macro

---

## `END_PRINT`

`END_PRINT` is not included as part of the standard replacement `macros.cfg`.

The installer provides the optional **A Better End Print Macro** package.

Project repository:

https://github.com/ss1gohan13/A-Better-End-Print-Macro

---

## Removed / Replaced Legacy Macros

Several legacy SV08 macros are no longer included because their functionality has been replaced, incorporated elsewhere, or is still being reevaluated.

These include:

### `_auto_zoffset` / `_CALIBRATION_ZOFFSET`

Not currently included in the replacement macro configuration.

### `_Delay_Calibrate`

Not currently included.

### `_global_var`

Replaced by:

```ini
[gcode_macro _CLIENT_VARIABLE]
```

### `_print_start_wait` / `_resume_wait`

Not included. Their previous functionality is no longer required by the current macro layout.

### `bed_mesh_init`

Not included. Bed mesh preparation is handled through the current leveling and mesh workflow.

### Custom `BED_MESH_CALIBRATE`

A replacement `BED_MESH_CALIBRATE` macro is not used. The `G29` workflow calls Klipper's normal `BED_MESH_CALIBRATE` command.

### Custom `M109` / `M190`

Custom replacements are not included. Klipper's normal temperature wait commands are used.

### `TEST_BELT`

Not currently included.

Klipper's normal resonance testing and input-shaping tools can be used instead.

---

# Installer Architecture

Beginning with version 1.3.0, the installer was refactored from a large monolithic script into separate functional modules.

The current layout includes:

```text
install-macros.sh
│
└── lib/
    ├── functions.sh
    ├── fan_config.sh
    ├── installers.sh
    ├── menus.sh
    ├── hardware.sh
    └── diagnostics.sh
```

### `install-macros.sh`

Main installer entry point.

Handles:

* Command-line options.
* Module loading.
* Interactive vs. linear execution.
* Uninstall execution.

### `lib/functions.sh`

Shared core utilities including:

* Klipper path verification.
* Backup directory creation.
* Klipper service control.
* Installer header output.

### `lib/fan_config.sh`

Part cooling fan configuration module.

Handles:

* Existing `[fan_generic fan]` detection.
* Stock Sovol dual-fan migration.
* Rappetor/Mainline fan migration.
* Existing fan reuse.
* Manual fan pin entry.
* Duplicate pin warnings.
* Custom configuration fallback.

### `lib/installers.sh`

Installation and configuration functions including:

* Macro installation.
* `printer.cfg` updates.
* Backup restoration.
* Web interface configuration.
* KAMP installation.
* `gcode_shell_command`.
* Firmware retraction.
* Extruder settings.
* Eddy NG configuration.
* `force_move`.
* Additional software installation helpers.

### `lib/menus.sh`

Interactive menu system including:

* Macro installation.
* Additional features.
* Software management.
* Backup management.
* Uninstallation.

### `lib/hardware.sh`

Hardware utilities including:

* MCU detection.
* CAN device detection.
* Stepper configuration.
* TMC configuration.
* Firmware retraction.
* Extruder configuration.
* `force_move` configuration.

### `lib/diagnostics.sh`

Diagnostic tools including:

* Klipper service status.
* Log viewing.
* Configuration verification.
* Full system diagnostics.

---

# Version History

## Version 1.3.6

### README Documentation Update

Updated and expanded the project README to better reflect the current installer and macro functionality.

Changes include:

* Expanded installation and configuration documentation.
* Added detailed documentation for the part cooling fan configuration system introduced in version 1.3.5.
* Added documentation for the custom `M106` and `M107` fan control behavior.
* Restored links to the **A Better Print_Start Macro** and **A Better End Print Macro** project repositories.
* Expanded descriptions of installer menus, hardware utilities, diagnostics, backups, and software management.
* Added command-line option documentation.
* Expanded descriptions of the replacement macros and removed/replaced legacy macros.
* Added documentation for the modular installer architecture.
* General formatting, organization, and clarity improvements.

---

## Version 1.3.5

### Part Cooling Fan Configuration

Added `lib/fan_config.sh` to provide automatic part cooling fan configuration for the replacement `M106` and `M107` macros.

Version 1.3.5 adds support for:

* Detecting an existing compatible `[fan_generic fan]`.
* Repairing a `[fan_generic fan]` section that is missing its `pin`.
* Detecting the stock Sovol `fan0` / `fan1` layout.
* Combining compatible stock fan outputs using `multi_pin`.
* Detecting and converting the Rappetor/Mainline `[fan]` layout.
* Reusing custom fan sections.
* Manual fan pin configuration.
* Detection of existing pin references.
* Skipping fan configuration when manual setup is preferred.

---

## Version 1.3.0

### Modular Installer Architecture

The original installer was refactored into separate modules to improve maintainability, readability, and future development.

### Automatic `gcode_shell_command` Installation

The required `gcode_shell_command` extension is automatically installed with the standard replacement macros when it is not already present.

It is also available as a standalone installer option.

### Additional Improvements

Version 1.3.0 also expanded:

* Error handling.
* Configuration validation.
* Hardware configuration utilities.
* Backup management.
* Diagnostic tools.
* Optional feature installation.
* Software management.

---

# Support / Issues

If you encounter a problem with the installer or replacement macros, open an issue on the SV08 Replacement Macros GitHub repository.

When reporting an issue, include as much relevant information as possible, such as:

* The installer option being used.
* The error shown by the installer.
* Relevant Klipper errors.
* Relevant sections of `printer.cfg`.
* Any custom macro or hardware configuration that may affect the issue.

Always review configuration changes before operating the printer after a major configuration update.
