## How to Install the Macros

1. **SSH into your printer** using your preferred SSH client.
2. **Run the following commands:**
   ```bash
   cd ~
   git clone https://github.com/ss1gohan13/SV08-Replacement-Macros.git
   cd SV08-Replacement-Macros
   ./install-macros.sh
   ```

**What This Does:**
- Stops the Klipper service for safe modification.
- Detects your Klipper config directory, including custom paths (supports `-c` flag).
- Backs up your existing `macros.cfg`, `printer.cfg`, and any user-specified macro files into `~/printer_data/config/backup/`.
- Downloads and installs the latest `macros.cfg` from GitHub.
- Updates your `printer.cfg` to include the new macros, and comments out any conflicting/old macro includes.
- (If chosen) Installs web interface configuration for Fluidd or Mainsail.
- (If chosen) Installs KAMP (Klipper Adaptive Meshing & Purging) and recommended settings.
- (If chosen) Installs "A Better Print_Start Macro" and/or "A Better End Print Macro" via their install scripts.
- Adds/updates crucial Klipper sections such as `[force_move]`, `[firmware_retraction]`, and extruder safety limits.
- Adds hardware configuration utilities, stepper driver setup, MCU/CAN device detection, and more.
- Restarts the Klipper service.
- Provides an interactive menu for additional features, diagnostics, and hardware/software utilities.
- **All changes are reversible via the uninstall process and backup restoration.**

---

## Detailed List of Changes Made

- **Backups:**  
  All affected config files (`macros.cfg`, `printer.cfg`, user macros) are backed up to `~/printer_data/config/backup/` with timestamps before any modification.

- **Macro Installation:**  
  - Replaces or installs `macros.cfg` in the Klipper config directory.
  - Updates `printer.cfg` to ensure `[include macros.cfg]` is present at the top.
  - Comments out old or conflicting `[include ...]` macro lines.
  - Optionally installs advanced print macros (“A Better Print_Start Macro” and “A Better End Print Macro”).

- **Web Interface Integration:**  
  - Optionally adds `[include fluidd.cfg]` or `[include mainsail.cfg]` to your config for web UI compatibility.

- **KAMP and Extensions:**  
  - Optionally installs KAMP and its config, with symlink and recommended settings.
  - Optionally installs support for Crowsnest (webcam streaming), Moonraker-Timelapse, and more.

- **Hardware Config Utilities:**  
  - Provides interactive configuration of stepper drivers, MCU/CAN bus device detection, and safety parameter tuning.
  - Adds or updates `[force_move]`, `[firmware_retraction]`, and extruder safety settings in `printer.cfg`.

- **Eddy NG Support:**  
  - Optionally enables advanced bed mesh and “Tappy Tap” features if you have an Eddy NG sensor.

- **Software Management:**  
  - Menu-driven tools for updating macros, installing Kiauh, checking/updating system packages, and installing Python dependencies (like numpy for ADXL).

- **Backup Management:**  
  - Menu-driven backup listing, restoration, and cleaning.

- **Uninstallation Support:**  
  - Full uninstall option restores all backed up files, removes the replacement macro if no backup exists, and restarts Klipper.

- **Diagnostics:**  
  - Menu-driven troubleshooting, log viewing, and verification tools included.

---

## How to Uninstall the Macros

1. **Run the uninstaller script:**
   ```bash
   cd ~/SV08-Replacement-Macros
   ./install-macros.sh -u
   ```

2. **Remove the repository folder:**
   ```bash
   cd ~
   rm -rf SV08-Replacement-Macros
   ```

**What This Does:**
- Stops the Klipper service.
- Restores original `macros.cfg`, `printer.cfg`, and any other backed up macro files from backup (if available).
- Removes the replacement `macros.cfg` if no backup is present.
- Restarts the Klipper service.
- Leaves your system in its original state (pre-installation), thanks to full backup/restore.

---

*For advanced options, troubleshooting, or to use the interactive menu, simply run `./install-macros.sh` without any flags.*

## Major Macro Changes & Improvements

The SV08 Replacement Macros project brings a streamlined, modernized, and SV08-optimized macro environment. Below are the key changes, removals, and improvements compared to the original and prior configurations:

### Macros Removed or Replaced

- **`_auto_zoffset` and `_CALIBRATION_ZOFFSET`:**  
  Temporarily removed. Auto Z offset adjustment is currently under review for reliability; will be reintroduced once a robust solution is available.

- **`_Delay_Calibrate`:**  
  Temporarily removed. This macro’s necessity is under evaluation—let us know if you relied on it!

- **`_global_var`:**  
  Removed. Now replaced with the standard `[gcode_macro _CLIENT_VARIABLE]` from Fluidd/Mainsail, customized for SV08. This macro dynamically handles max X/Y positions (with buffer) and eliminates the need for custom global variables.

- **`_print_start_wait` and `_resume_wait`:**  
  Removed as their functionality is now handled by improved print start/end logic or is no longer needed.

- **`ALL_FAN_OFF`:**  
  Mostly obsolete due to improved fan handling, but kept for backward compatibility.

- **`bed_mesh_init`:**  
  Removed. Mesh initialization is now integrated into other macros or handled automatically.

- **`BED_MESH_CALIBRATE`:**  
  Removed and replaced by the standard `G29` command for bed mesh calibration (familiar for Marlin users), improving compatibility and clarity.

- **`CLEAN_NOZZLE`:**  
  Updated and simplified for the stock SV08 nozzle scrubber. Cleans more efficiently and is easier to maintain.

- **`END_PRINT`:**  
  Fully replaced. See the new, improved [A Better End Print Macro](https://github.com/ss1gohan13/A-Better-End-Print-Macro) for advanced end-of-print handling.

- **`Force move`:**  
  No longer a macro; now implemented as a `[force_move]` section in your `printer.cfg` for better integration with Klipper.

- **`G34`:**  
  Removed and replaced with a remastered version for better gantry alignment.

- **`idle timeout`:**  
  Remastered using the Fluidd/Mainsail `_CLIENT_VARIABLE` macro. Default idle timeout is now set to 10 minutes—customize as needed.

- **`M106` and `M107`:**  
  These macros for fan control are now handled by standard Klipper or mainline `printer.cfg` multipin fan sections, and are not needed for most users.

- **`M109` and `M190`:**  
  Removed. These are now handled by stock Klipper macros for temperature control (wait for tool/bed temp).

- **`M600`:**  
  Modified. Now only uses the `PAUSE` macro for filament changes. Customize filament parking and resume positions via the included `_CLIENT_VARIABLE` macro, which references your SV08’s max X/Y values.

- **`mainled`:**  
  New macro! Allows you to toggle your printer’s main LED light directly from the interface or macro.

- **`PROBE_CALIBRATE`:**  
  Removed in favor of Klipper’s standard calibration routines. Remastered behavior: calibration now defaults to 150°C nozzle and 60°C bed, but you can customize the bed temp as needed.

- **`QUAD_GANTRY_LEVEL`:**  
  Removed. Now integrated into the new `GANTRY_LEVELING` macro and start print sequences; leverages Klipper’s native QGL support.

- **`RESUME`, `CANCEL_PRINT`, `PAUSE`:**  
  Fully replaced. These now use `[include fluidd.cfg]` or `[include mainsail.cfg]` in your `printer.cfg` and leverage the `_CLIENT_VARIABLE` macro for dynamic SV08-specific locations.  
  **Note:** If you are not using an SV08, update the positions in `_CLIENT_VARIABLE` as needed.

- **`START_PRINT`:**  
  Fully replaced. See the [A Better Print_Start Macro](https://github.com/ss1gohan13/A-better-print_start-macro) for smarter print job initialization, temperature management, and bed prep.

- **`TEST_BELT`:**  
  Temporarily removed until its reliability is confirmed. For now, use `SHAPER_CALIBRATE` or the "Shake Tune" procedure as a workaround.

- **`LOAD_FILAMENT` and `UNLOAD_FILAMENT`:**  
  Both macros remastered for improved reliability and compatibility with SV08 extruder and filament path.

---

### Why These Changes?

- To improve reliability, compatibility, and ease of use for SV08 (and similar) printers.
- To remove redundancy with standard Klipper features and adopt best practices from Fluidd/Mainsail.
- To simplify macro maintenance and make future updates easier for everyone.
- To enable advanced features and integrations (like dynamic variables, enhanced print start/end, etc.) with less manual editing.

---

**If you need any removed macro, or want to request a specific legacy workflow, open an issue or discussion on the GitHub project!**
