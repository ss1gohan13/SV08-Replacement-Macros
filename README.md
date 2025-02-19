# SV08-Replacement-Macros (WIP)

<details>
<summary>How to install the macros</summary>

```
cd ~
git clone https://github.com/ss1gohan13/SV08-Replacement-Macros.git
cd SV08-Replacement-Macros
./install-macros.sh
```

This will:

1) Stop the Klipper service
2) Download the macro config from the github
3) Backup the existing macro to `~/printer_data/config/backup/`
4) Install the replacement macro
5) Restart the klipper service
6) OPTIONAL: Ask to install a replacement start print macro

</details>

<details>
<summary>How to uninstall the macros</summary>

```
cd ~/SV08-Replacement-Macros
./install-macros.sh -u

# Then remove the repository
cd ~
rm -rf SV08-Replacement-Macros
```

This will:

1) Stop the Klipper service
2) Remove the replacement macros.cfg if no backup exists
3) Restore your original macros.cfg from backup (if one exists)
4) Restart the Klipper service

</details>

# Changes

- _auto_zoffset and _CALIBRATION_ZOFFSET are temp removed until auto z offset is working
- _Delay_Calibrate temp removed - is it needed?
- _global_var is no longer needed
- _print_start_wait - removed - not needed
- _resume_wait removed
- ALL_FAN_OFF is no longer needed but kept
- bed_mesh_init - removed - not needed
- BED_MESH_CALIBRATE removed - this is a klipper standard - BED_MESH_CALIBRATE ADAPTIVE=1 is the new standard and integrated with replacement [start print macro](https://github.com/ss1gohan13/A-be[...]
- CANCEL_PRINT replaced - add fluidd or mainsail config, and customize, to specific requested settings
- CLEAN_NOZZLE is updated/shortened - this is meant to work with the stock nozzle scrubber setup
- END_PRINT replaced - see the [end print macro](https://github.com/ss1gohan13/A-Better-End-Print-Macro)
- Force move is moved into printer.cfg - Its not a macro... move it
- G34 back. G29 still there too.
- idle timeout moved to fluidd and/or mainsail config. Please update and configure
- M106 can be removed - not needed for mainline - see mainline instructions for multipin fan
- M107 can be removed - not needed for mainline
- M109 removed - not needed
- M190 removed - not needed
- M600 modified - only use PAUSE - use/customize fluidd/mainsail config to use PAUSE macro and parking position
- New toggle version of main LED light
- PAUSE replaced - add fluidd or mainsail config, and customize, to specific requested settings
- PROBE_CALIBRATE removed - this is a klipper standard - calibrate at your requested bed temp
- QUAD_GANTRY_LEVEL removed - not needed - QGL is a klipper standard and can be integrated with replacement [start print macro](https://github.com/ss1gohan13/A-better-print_start-macro-SV08)
- RESUME replaced - add fluidd or mainsail config, and customize, to specific requested settings
- START_PRINT replaced - see the [start print macro](https://github.com/ss1gohan13/A-better-print_start-macro-SV08) replacement
- TEST_BELT: ~~temp removed until confirmed working - Acquire Shake Tune and run calibration as workaround~~ Replaced with SHAPER_CALIBRATE
