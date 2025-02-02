# SV08-Replacement-Macros (WIP)
To fix and replace all of Sovol SV08 macros

- Force move is moved into printer.cfg - Its not a macro... move it
- _global_var is no longer needed
- idle timeout moved to fluidd and/or mainsail config. Please update and configure
- ALL_FAN_OFF is no longer needed but kept
- CLEAN_NOZZLE is updated/shortened - this is meant to work with the stock nozzle scrubber setup
- _CALIBRATION_ZOFFSET and _auto_zoffset are temp removed until auto z offset is working
- _Delay_Calibrate temp removed - is it needed?
- TEST_BELT: ~~temp removed until confirmed working - Acquire Shake Tune and run calibration as workaround~~ Replaced with SHAPER_CALIBRATE
- QUAD_GANTRY_LEVEL removed - not needed - QGL is a klipper standard and can be integrated with replacement [start print macro](https://github.com/ss1gohan13/A-better-print_start-macro-SV08)
- PROBE_CALIBRATE removed - this is a klipper standard - calibrate at your requested bed temp
- BED_MESH_CALIBRATE removed - this is a klipper standard - BED_MESH_CALIBRATE ADAPTIVE=1 is the new standard and integrated with replacement [start print macro](https://github.com/ss1gohan13/A-better-print_start-macro-SV08)
- ~~G34 remove - replaced with G29~~ G34 back. G29 still there too. 
- bed_mesh_init - removed - not needed
- _print_start_wait - removed - not needed
- START_PRINT replaced - see the [start print macro](https://github.com/ss1gohan13/A-better-print_start-macro-SV08) replacement
- END_PRINT replaced - see the [end print macro](https://github.com/ss1gohan13/A-Better-End-Print-Macro)
- CANCEL_PRINT replaced - add fluidd or mainsail config, and customize, to specific requested settings
- PAUSE replaced - add fluidd or mainsail config, and customize, to specific requested settings
- _resume_wait removed
- RESUME replaced - add fluidd or mainsail config, and customize, to specific requested settings
- M109 removed - not needed
- M190 removed - not needed
- M196 can be removed - not needed for mainline
- M107 can be removed - not needed for mainline
- M600 modified - only use PAUSE - use/customize fluidd/mainsail config to use PAUSE macro and parking position
- New toggle version of main LED light
