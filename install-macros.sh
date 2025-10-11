#!/bin/bash
# Force script to exit if an error occurs
set -e

# Script Info
# Last Updated: 2025-01-14 00:27:26 UTC
# Author: ss1gohan13

KLIPPER_CONFIG="${HOME}/printer_data/config"
KLIPPER_PATH="${HOME}/klipper"
KLIPPER_SERVICE_NAME=klipper
BACKUP_DIR="${KLIPPER_CONFIG}/backup"
CURRENT_DATE=$(date +%Y%m%d_%H%M%S)
VERSION="1.2.0"

# Default to menu mode - menu will show by default
MENU_MODE=1

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line arguments
usage() {
    echo "Usage: $0 [-c <config path>] [-s <klipper service name>] [-u] [-l]" 1>&2
    echo "  -c : Specify custom config path (default: ${KLIPPER_CONFIG})" 1>&2
    echo "  -s : Specify Klipper service name (default: klipper)" 1>&2
    echo "  -u : Uninstall" 1>&2
    echo "  -l : Run in linear mode (skip interactive menu)" 1>&2
    echo "  -h : Show this help message" 1>&2
    exit 1
}

while getopts "c:s:ulh" arg; do
    case $arg in
        c)
            KLIPPER_CONFIG="$OPTARG"
            ;;
        s)
            KLIPPER_SERVICE_NAME="$OPTARG"
            ;;
        u)
            UNINSTALL=1
            ;;
        l)
            MENU_MODE=0
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

# Utility to check Klipper config dir exists
check_klipper() {
    if [ ! -d "$KLIPPER_CONFIG" ]; then
        echo -e "${RED}[ERROR] Klipper config directory not found at \"$KLIPPER_CONFIG\". Please verify path or specify with -c.${NC}"
        exit -1
    fi
    echo -e "${GREEN}Klipper config directory found at $KLIPPER_CONFIG${NC}"
}

# Create backup directory if it doesn't exist
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Creating backup directory at $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
}

# Verify script is not run as root
verify_ready() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}[ERROR] This script must not run as root${NC}"
        exit -1
    fi
}

# Service management functions
start_klipper() {
    echo -n "Starting Klipper... "
    sudo systemctl start $KLIPPER_SERVICE_NAME
    echo -e "${GREEN}[OK]${NC}"
}

stop_klipper() {
    echo -n "Stopping Klipper... "
    sudo systemctl stop $KLIPPER_SERVICE_NAME
    echo -e "${GREEN}[OK]${NC}"
}

# Declare global array for backup files
declare -a BACKUP_FILES

# Modified to properly handle user input for macro files
get_user_macro_files() {
    echo "Looking for macro files in $KLIPPER_CONFIG..."
    echo "Found these potential macro files:"
    find "$KLIPPER_CONFIG" -maxdepth 1 -type f -name "*.cfg" | sort | while read -r file; do
        if [[ ! "$(basename "$file")" =~ (backup|[0-9]{8}_[0-9]{6})\.cfg$ ]]; then
            echo "  - $(basename "$file")"
        fi
    done

    echo ""
    read -p "Do you have a custom macro.cfg installed? (y/N): " has_custom_macro
    if [[ ! "$has_custom_macro" =~ ^[Yy]$ ]]; then
        echo "No custom macro.cfg detected. Will use default 'macros.cfg'."
        MACRO_FILES=("macros.cfg")
        echo "Will download new macros to: macros.cfg"
        return
    fi
    
    echo "Please enter the filenames of your macro files (space separated)."
    echo "Example: macros.cfg sv08_macros.cfg custom_macros.cfg"
    echo "Press Enter if you have no existing macro files."
    read -p "> " USER_MACRO_FILES
    
    MACRO_FILES=("macros.cfg")
    
    if [ -n "$USER_MACRO_FILES" ]; then
        echo "Will back up the following files: $USER_MACRO_FILES"
        read -ra USER_FILES <<< "$USER_MACRO_FILES"
        for file_name in "${USER_FILES[@]}"; do
            if [ -f "${KLIPPER_CONFIG}/${file_name}" ]; then
                echo "Will back up existing ${file_name}"
                BACKUP_FILES+=("$file_name")
            fi
        done
    else
        echo "No files specified. Will use default 'macros.cfg'."
    fi
    
    echo "Will download new macros to: macros.cfg"
}

# Modified to use both specified user files and default macros.cfg
backup_existing_macros() {
    local found_macro=0
    
    # First check if macros.cfg exists and back it up
    if [ -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
        echo "Creating backup of existing macros.cfg..."
        cp "${KLIPPER_CONFIG}/macros.cfg" "${BACKUP_DIR}/macros.cfg.backup_${CURRENT_DATE}"
        echo "Backup created at ${BACKUP_DIR}/macros.cfg.backup_${CURRENT_DATE}"
        found_macro=1
    fi
    
    # Also back up any additional files specified by the user
    if [ -n "${BACKUP_FILES}" ]; then
        for file_name in "${BACKUP_FILES[@]}"; do
            if [ -f "${KLIPPER_CONFIG}/${file_name}" ] && [ "$file_name" != "macros.cfg" ]; then
                echo "Creating backup of existing ${file_name}..."
                cp "${KLIPPER_CONFIG}/${file_name}" "${BACKUP_DIR}/${file_name}.backup_${CURRENT_DATE}"
                echo "Backup created at ${BACKUP_DIR}/${file_name}.backup_${CURRENT_DATE}"
                found_macro=1
            fi
        done
    fi

    if [ $found_macro -eq 1 ]; then
        echo "All specified macro configurations have been backed up."
    else
        echo "No existing macro files found to back up."
    fi
}

# Using the exact curl command that works - always to macros.cfg
install_macros() {
    echo "Downloading and installing new macros to macros.cfg..."
    # Always download to macros.cfg regardless of what the user entered
    curl -L https://raw.githubusercontent.com/ss1gohan13/SV08-Replacement-Macros/main/printer_data/config/macros.cfg -o "${KLIPPER_CONFIG}/macros.cfg"
    # Verify download was successful
    if [ -s "${KLIPPER_CONFIG}/macros.cfg" ]; then
        echo -e "${GREEN}[OK]${NC} Macros file downloaded successfully"
        echo "First few lines of downloaded file:"
        head -n 3 "${KLIPPER_CONFIG}/macros.cfg"
    else
        echo -e "${RED}[ERROR] Failed to download macros file. Please check your internet connection.${NC}"
        exit 1
    fi
}

# Completely rewritten function to handle printer.cfg properly
check_and_update_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    
    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        echo "You will need to manually add: [include macros.cfg] to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    echo "Created backup of printer.cfg at ${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    
    echo "Processing printer.cfg file..."

    # Comment out the hardcoded Macro.cfg (existing behavior)
    sed -i 's/^\[include Macro\.cfg\]/# [include Macro.cfg]/' "$working_cfg"
    
    # NEW: Comment out user-specified macro files
    if [ -n "$USER_MACRO_FILES" ]; then
        read -ra USER_FILES <<< "$USER_MACRO_FILES"
        for file_name in "${USER_FILES[@]}"; do
            # Remove any path and get just the filename
            base_name=$(basename "$file_name")
            # Escape dots for sed regex
            escaped_name=$(echo "$base_name" | sed 's/\./\\./g')
            # Comment out this include line
            sed -i "s/^\[include ${escaped_name}\]/# [include ${base_name}]/" "$working_cfg"
            echo "Commented out [include ${base_name}]"
        done
    fi
    
    # Also comment out any files in BACKUP_FILES array
    if [ -n "${BACKUP_FILES}" ]; then
        for file_name in "${BACKUP_FILES[@]}"; do
            # Remove any path and get just the filename
            base_name=$(basename "$file_name")
            # Skip if it's macros.cfg since we want that to remain active
            if [ "$base_name" != "macros.cfg" ]; then
                # Escape dots for sed regex
                escaped_name=$(echo "$base_name" | sed 's/\./\\./g')
                # Comment out this include line
                sed -i "s/^\[include ${escaped_name}\]/# [include ${base_name}]/" "$working_cfg"
                echo "Commented out [include ${base_name}]"
            fi
        done
    fi
    
    # Check if macros.cfg include already exists (existing behavior)
    if grep -q '^\[include macros\.cfg\]' "$working_cfg"; then
        echo "Found existing [include macros.cfg]. No need to add another."
    else
        sed -i '1i[include macros.cfg]\n' "$working_cfg"
        echo "Added [include macros.cfg] to the top of printer.cfg"
    fi

    # Remove any commented duplicate macros.cfg lines (existing behavior)
    sed -i 's/^# \[include macros\.cfg\]//' "$working_cfg"

    mv "$working_cfg" "$printer_cfg"
    echo "Updated printer.cfg successfully"
}

# Modified to restore latest backup of specified macro files
restore_backup() {
    local latest_macros_backup=$(ls -t ${BACKUP_DIR}/macros.cfg.backup_* 2>/dev/null | head -n1)
    if [ -n "$latest_macros_backup" ]; then
        echo "Restoring from backup: $latest_macros_backup"
        cp "$latest_macros_backup" "${KLIPPER_CONFIG}/macros.cfg"
        echo -e "${GREEN}[OK]${NC}"
    else
        echo "No backup found for macros.cfg"
        if [ -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
            echo "Removing installed macros.cfg"
            rm "${KLIPPER_CONFIG}/macros.cfg"
        fi
    fi
    
    if [ -n "${BACKUP_FILES}" ]; then
        for file_name in "${BACKUP_FILES[@]}"; do
            if [ "$file_name" != "macros.cfg" ]; then
                local latest_backup=$(ls -t ${BACKUP_DIR}/${file_name}.backup_* 2>/dev/null | head -n1)
                if [ -n "$latest_backup" ]; then
                    echo "Restoring from backup: $latest_backup"
                    cp "$latest_backup" "${KLIPPER_CONFIG}/${file_name}"
                    echo -e "${GREEN}[OK]${NC}"
                fi
            fi
        done
    fi

    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [[ ! "$(basename "$printer_cfg")" =~ [0-9]{8}_[0-9]{6}\.cfg$ ]]; then
        local printer_backup=$(ls -t ${BACKUP_DIR}/printer.cfg.backup_* 2>/dev/null | head -n1)
        if [ -n "$printer_backup" ]; then
            echo "Restoring printer.cfg from backup: $printer_backup"
            cp "$printer_backup" "$printer_cfg"
            echo -e "${GREEN}[OK]${NC}"
        fi
    fi
}
# Function to install web interface configuration
install_web_interface_config() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        echo "You will need to manually add web interface configuration"
        return
    fi

    echo ""
    echo "What web interface are you using?"
    echo "1) Fluidd"
    echo "2) Mainsail"
    read -p "Select an option (1/2): " web_interface_choice
    
    local include_directive=""
    case $web_interface_choice in
        1)
            include_directive="[include fluidd.cfg]"
            echo "You selected Fluidd"
            ;;
        2)
            include_directive="[include mainsail.cfg]"
            echo "You selected Mainsail"
            ;;
        *)
            echo "Invalid selection. Skipping web interface configuration."
            return
            ;;
    esac
    
    local config_file=$(echo "$include_directive" | sed -n 's/\[include \(.*\)\]/\1/p')
    
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.webinterface_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.webinterface_${CURRENT_DATE}"

    echo "Processing printer.cfg for web interface configuration..."
    if grep -q "^\[include ${config_file}\]" "$working_cfg"; then
        echo "Found existing ${include_directive}. No need to add another."
    else
        if grep -q '^\[include macros\.cfg\]' "$working_cfg"; then
            sed -i "/\[include macros\.cfg\]/a\\${include_directive}" "$working_cfg"
            echo "Added ${include_directive} after [include macros.cfg]"
        else
            sed -i "1i${include_directive}\n" "$working_cfg"
            echo "Added ${include_directive} to the top of printer.cfg"
        fi
    fi

    sed -i "s/^# \[include ${config_file}\]//" "$working_cfg"
    mv "$working_cfg" "$printer_cfg"
    echo "Updated printer.cfg with web interface configuration"
}

# Function to install KAMP
install_kamp() {
    if [ -d "${KLIPPER_CONFIG}/KAMP" ]; then
        echo "KAMP is already installed."
        return
    fi

    echo "Installing KAMP..."
    cd
    git clone https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging.git
    ln -s ~/Klipper-Adaptive-Meshing-Purging/Configuration "${KLIPPER_CONFIG}/KAMP"
    cp ~/Klipper-Adaptive-Meshing-Purging/Configuration/KAMP_Settings.cfg "${KLIPPER_CONFIG}/KAMP_Settings.cfg"
    echo -e "${GREEN}KAMP installation complete!${NC}"
    
    # ADD THIS LINE: Automatically add firmware retraction after KAMP installation
    echo "Adding firmware retraction configuration..."
    add_firmware_retraction_to_printer_cfg
}

# Add firmware retraction to printer.cfg
add_firmware_retraction_to_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    local working_cfg="${BACKUP_DIR}/printer.cfg.firmware_retraction_${CURRENT_DATE}"

    local firmware_retraction_block="[firmware_retraction]
retract_length: 0.6
#   The length of filament (in mm) to retract when G10 is activated,
#   and to unretract when G11 is activated (but see
#   unretract_extra_length below). The default is 0 mm.
retract_speed: 60
#   The speed of retraction, in mm/s. The default is 20 mm/s.
unretract_extra_length: 0
#   The length (in mm) of *additional* filament to add when
#   unretracting.
unretract_speed: 60
#   The speed of unretraction, in mm/s. The default is 10 mm/s.
"

    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        echo "You will need to manually add the firmware retraction block to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "$working_cfg"
    echo "Created backup of printer.cfg at ${working_cfg}"

    if grep -q '^\[firmware_retraction\]' "$working_cfg"; then
        echo -e "${GREEN}Firmware retraction section already exists. Skipping addition.${NC}"
        rm "$working_cfg"
        return
    fi

    # Look for the SAVE_CONFIG comment marker instead of [save_config]
    local save_config_line=$(grep -n '#\*# <---------------------- SAVE_CONFIG ---------------------->' "$working_cfg" | cut -d: -f1 | head -n 1)
    
    if [ -n "$save_config_line" ]; then
        # Insert firmware retraction just before SAVE_CONFIG marker
        awk -v block="$firmware_retraction_block" -v line="$save_config_line" '
            NR==line {print block}
            {print}
        ' "$working_cfg" > "${working_cfg}.new"
        mv "${working_cfg}.new" "$printer_cfg"
        echo -e "${GREEN}Added firmware retraction above SAVE_CONFIG section in printer.cfg${NC}"
    else
        # No SAVE_CONFIG marker found, append to end
        echo "$firmware_retraction_block" >> "$working_cfg"
        mv "$working_cfg" "$printer_cfg"
        echo -e "${GREEN}Appended firmware retraction to end of printer.cfg${NC}"
    fi
}

# Function to add extruder settings to printer.cfg
add_extruder_settings_to_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    local working_cfg="${BACKUP_DIR}/printer.cfg.extruder_settings_${CURRENT_DATE}"

    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        echo "You will need to manually add the extruder settings to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "$working_cfg"
    echo "Created backup of printer.cfg at ${working_cfg}"

    # Check if extruder section exists
    if ! grep -q '^\[extruder\]' "$working_cfg"; then
        echo -e "${YELLOW}[WARNING] No [extruder] section found in printer.cfg${NC}"
        echo "You will need to manually add the extruder settings to your printer.cfg"
        rm "$working_cfg"
        return
    fi

    # Check if max_extrude_cross_section already exists
    if grep -q '^max_extrude_cross_section:' "$working_cfg"; then
        echo -e "${GREEN}Extruder settings already exist. Skipping addition.${NC}"
        rm "$working_cfg"
        return
    fi

    # Add the three extruder settings at the end of the [extruder] section
    awk '
        /^\[extruder\]/ { 
            extruder_section = 1
            print
            next
        }
        /^\[/ && extruder_section {
            # We found the start of the next section, add our settings before it
            print "max_extrude_cross_section: 10"
            print "max_extrude_only_distance: 500"
            print "max_extrude_only_velocity: 120"
            print ""
            extruder_section = 0
            print
            next
        }
        { print }
        END {
            # If we never found another section after [extruder], add settings at the end
            if (extruder_section) {
                print "max_extrude_cross_section: 10"
                print "max_extrude_only_distance: 500"
                print "max_extrude_only_velocity: 120"
            }
        }
    ' "$working_cfg" > "${working_cfg}.new"
    
    mv "${working_cfg}.new" "$printer_cfg"
    echo -e "${GREEN}Added extruder settings to printer.cfg${NC}"
    echo "Added: max_extrude_cross_section: 10"
    echo "Added: max_extrude_only_distance: 500"
    echo "Added: max_extrude_only_velocity: 120"
}

# Function to configure Eddy NG Tap in the start print macro and GANTRY_LEVELING macro
configure_eddy_ng_tap() {
    echo ""
    echo "Do you have Eddy NG installed?"
    echo "This will enable 'Tappy Tap' functionality, rapid bed mesh scanning, and enhanced gantry leveling."
    read -p "Enable Eddy NG features? (y/N): " enable_eddy_ng
    
    if [[ "$enable_eddy_ng" =~ ^[Yy]$ ]]; then
        echo "Enabling Eddy NG features in your configuration..."
        
        # Find the start print macro file
        local start_print_file="${KLIPPER_CONFIG}/print_start_macro.cfg"
        local macros_file="${KLIPPER_CONFIG}/macros.cfg"
        
        # --- Configure Start Print Macro ---
        if [ ! -f "$start_print_file" ]; then
            # Try to find the file that might contain the START_PRINT macro
            for potential_file in "${KLIPPER_CONFIG}"/*.cfg; do
                if grep -q "\[gcode_macro START_PRINT\]" "$potential_file"; then
                    start_print_file="$potential_file"
                    echo "Found START_PRINT macro in: $start_print_file"
                    break
                fi
            done
        fi
        
        if [ -f "$start_print_file" ]; then
            # Create a backup of the file
            cp "$start_print_file" "${BACKUP_DIR}/$(basename "$start_print_file").backup_${CURRENT_DATE}"
            
            # Uncomment the Eddy NG tapping lines
            sed -i 's/^#STATUS_CALIBRATING_Z/STATUS_CALIBRATING_Z/' "$start_print_file"
            sed -i 's/^#M117 Tappy Tap.../M117 Tappy Tap.../' "$start_print_file"
            sed -i 's/^#PROBE_EDDY_NG_TAP.*/PROBE_EDDY_NG_TAP/' "$start_print_file"
            
            # Uncomment the Method=rapid_scan for bed mesh
            sed -i 's/BED_MESH_CALIBRATE ADAPTIVE=1 #Method=rapid_scan/BED_MESH_CALIBRATE ADAPTIVE=1 Method=rapid_scan/' "$start_print_file"
            
            echo -e "${GREEN}Eddy NG tapping and rapid bed mesh scanning have been enabled in your start print macro.${NC}"
        else
            echo -e "${YELLOW}[WARNING] Could not find the START_PRINT macro file.${NC}"
            echo "You will need to manually uncomment the Eddy NG features in your start print macro."
        fi
        
        # --- Configure GANTRY_LEVELING Macro ---
        if [ -f "$macros_file" ]; then
            # Create a backup of the macros file
            cp "$macros_file" "${BACKUP_DIR}/macros.cfg.backup_eddy_${CURRENT_DATE}"
            
            # Uncomment retry_tolerance parameters for QGL and Z_TILT
            sed -i 's/QUAD_GANTRY_LEVEL horizontal_move_z=5 #retry_tolerance=1/QUAD_GANTRY_LEVEL horizontal_move_z=5 retry_tolerance=1/' "$macros_file"
            sed -i 's/Z_TILT_ADJUST horizontal_move_z=5 #RETRY_TOLERANCE=1/Z_TILT_ADJUST horizontal_move_z=5 RETRY_TOLERANCE=1/' "$macros_file"
            
            # Uncomment second pass fine adjustments
            sed -i 's/^#QUAD_GANTRY_LEVEL horizontal_move_z=2/QUAD_GANTRY_LEVEL horizontal_move_z=2/' "$macros_file"
            sed -i 's/^#Z_TILT_ADJUST horizontal_move_z=2/Z_TILT_ADJUST horizontal_move_z=2/' "$macros_file"
            
            # Also update G29 macro for rapid scanning
            sed -i 's/BED_MESH_CALIBRATE ADAPTIVE=1       # Method=rapid_scan/BED_MESH_CALIBRATE ADAPTIVE=1 Method=rapid_scan       #/' "$macros_file"
            
            echo -e "${GREEN}Eddy NG enhanced gantry leveling has been enabled in your GANTRY_LEVELING macro.${NC}"
            echo "Both QGL and Z_TILT configurations have been updated with retry_tolerance and fine adjustment passes."
        else
            echo -e "${YELLOW}[WARNING] Could not find macros.cfg file.${NC}"
            echo "You will need to manually uncomment the Eddy NG features in your gantry leveling macro."
        fi
        
        echo -e "${GREEN}All Eddy NG features have been enabled in your configuration.${NC}"
        
    else
        echo "Skipping Eddy NG features configuration."
    fi
}

# Function to add force_move section to printer.cfg
add_force_move() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        return
    fi

    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    
    if grep -q '^\[force_move\]' "$working_cfg"; then
        if grep -q '^\[force_move\]' -A 2 "$working_cfg" | grep -q 'enable_force_move: true'; then
            echo -e "${GREEN}Force move already enabled in printer.cfg${NC}"
            rm "$working_cfg"
            return
        else
            sed -i '/^\[force_move\]/,/^$/s/enable_force_move:.*$/enable_force_move: true/' "$working_cfg"
            if ! grep -q 'enable_force_move: true' "$working_cfg"; then
                sed -i '/^\[force_move\]/a enable_force_move: true' "$working_cfg"
            fi
            echo -e "${GREEN}Updated existing force_move section${NC}"
        fi
    else
        sed -i '1i[force_move]\nenable_force_move: true\n' "$working_cfg"
        echo -e "${GREEN}Added force_move section to printer.cfg${NC}"
    fi
    mv "$working_cfg" "$printer_cfg"
}

# New function to install Numpy for ADXL resonance measurements
install_numpy_for_adxl() {
    show_header
    echo -e "${BLUE}INSTALL NUMPY FOR ADXL RESONANCE MEASUREMENTS${NC}"
    
    echo "This will install numpy in the Klipper Python environment."
    echo "Numpy is required for processing ADXL345 accelerometer data for input shaping."
    echo "Reference: https://www.klipper3d.org/Measuring_Resonances.html"
    echo ""
    
    # Check if klippy-env exists
    if [ ! -d "${HOME}/klippy-env" ]; then
        echo -e "${RED}Error: Klipper Python environment not found at ~/klippy-env${NC}"
        echo "Please make sure Klipper is properly installed."
        return
    fi
    
    echo "Installing numpy (this may take a few minutes)..."
    ${HOME}/klippy-env/bin/pip install -v numpy
    
    # Verify installation
    if ${HOME}/klippy-env/bin/pip list | grep -q numpy; then
        echo -e "${GREEN}Numpy installed successfully!${NC}"
        echo "You can now use ADXL345-based resonance measurements with your printer."
        echo "For configuration instructions, see: https://www.klipper3d.org/Measuring_Resonances.html"
    else
        echo -e "${RED}Error: Failed to install numpy. Please try again or install manually.${NC}"
    fi
}

#############################################
# NEW FUNCTIONALITY: INTERACTIVE MENU SYSTEM
#############################################

show_header() {
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    SV08 Replacement Macros Installer v${VERSION}${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${YELLOW}Author: ss1gohan13${NC}"
    echo -e "${YELLOW}Last Updated: 2025-10-11${NC}"
    echo ""
}

show_main_menu() {
    show_header
    echo -e "${BLUE}MAIN MENU${NC}"
    echo "1) Install SV08 Replacement Macros"
    echo "2) Hardware Configuration Utilities"
    echo "3) Additional Features & Extensions"
    echo "4) Backup Management"
    echo "5) Diagnostics & Troubleshooting"
    echo "6) Software Management"
    echo "7) Uninstall"
    echo "0) Exit"
    echo ""
    read -p "Select an option: " menu_choice
    
    case $menu_choice in
        1) install_core_macros_menu ;;
        2) hardware_config_menu ;;
        3) additional_features_menu ;;
        4) manage_backups ;;
        5) diagnostics_menu ;;
        6) software_management_menu ;;
        7) uninstall_menu ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; show_main_menu ;;
    esac
}

# Revised menu structure for macros installation
install_core_macros_menu() {
    show_header
    echo -e "${BLUE}INSTALL SV08 REPLACEMENT MACROS${NC}"
    echo "Select which macros to install:"
    echo ""
    echo "1) Install standard SV08 macros"
    echo "2) Install A Better Print_Start Macro"
    echo "3) Install A Better End Print Macro"
    echo "0) Back to main menu"
    echo ""
    read -p "Select an option: " install_choice
    
    case $install_choice in
        1) 
            check_klipper
            create_backup_dir
            stop_klipper
            get_user_macro_files
            backup_existing_macros
            install_macros
            check_and_update_printer_cfg
            install_web_interface_config
            add_force_move
            add_extruder_settings_to_printer_cfg
            start_klipper
            echo -e "${GREEN}Standard SV08 macros installed successfully!${NC}"
            read -p "Press Enter to continue..." dummy
            show_main_menu
            ;;
        2)
            check_klipper
            create_backup_dir
            stop_klipper
            # First install base macros if not already installed
            if [ ! -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
                get_user_macro_files
                backup_existing_macros
                install_macros
                check_and_update_printer_cfg
            fi
            
            # Then install KAMP (required by Print_Start Macro)
            echo "Installing KAMP (required for A Better Print_Start Macro)..."
            install_kamp
            
            # Install Print_Start Macro
            echo "Installing A Better Print_Start Macro..."
            curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-better-print_start-macro/main/install_start_print.sh | bash
            
            start_klipper
            echo -e "${GREEN}A Better Print_Start Macro installed successfully!${NC}"
            echo -e "${YELLOW}Remember to update your slicer's start G-code as per the documentation${NC}"
            echo -e "${YELLOW}Visit https://github.com/ss1gohan13/A-better-print_start-macro for details${NC}"
            read -p "Press Enter to continue..." dummy
            show_main_menu
            ;;
        3)
            check_klipper
            create_backup_dir
            stop_klipper
            # First install base macros if not already installed
            if [ ! -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
                get_user_macro_files
                backup_existing_macros
                install_macros
                check_and_update_printer_cfg
            fi
            
            # Install End Print Macro
            echo "Installing A Better End Print Macro..."
            curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-Better-End-Print-Macro/main/direct_install.sh | bash
            
            start_klipper
            echo -e "${GREEN}A Better End Print Macro installed successfully!${NC}"
            echo -e "${YELLOW}Remember to update your slicer's end G-code as per the documentation${NC}"
            echo -e "${YELLOW}Visit https://github.com/ss1gohan13/A-Better-End-Print-Macro for details${NC}"
            read -p "Press Enter to continue..." dummy
            show_main_menu
            ;;
        0) show_main_menu ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; install_core_macros_menu ;;
    esac
}

# Additional features menu
additional_features_menu() {
    show_header
    echo -e "${BLUE}ADDITIONAL FEATURES & EXTENSIONS${NC}"
    echo "1) Install Print Start Macro"
    echo "2) Install End Print Macro"
    echo "3) Install KAMP"
    echo "4) Enable Eddy NG tap start print function"
    echo "5) Install Numpy for ADXL Resonance Measurements"
    echo "6) Install Crowsnest (webcam streaming)"
    echo "7) Install Moonraker-Timelapse"
    echo "0) Back to main menu"
    echo ""
    read -p "Select an option: " feature_choice
    
    case $feature_choice in
        1)
            echo "Installing A Better Print_Start Macro..."
            install_kamp
            curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-better-print_start-macro/main/install_start_print.sh | bash
            echo -e "${GREEN}Print_Start macro installed successfully!${NC}"
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        2)
            echo "Installing A Better End Print Macro..."
            curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-Better-End-Print-Macro/main/direct_install.sh | bash
            echo -e "${GREEN}End Print macro installed successfully!${NC}"
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        3)
            install_kamp
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        4)
            check_klipper
            create_backup_dir
            stop_klipper
            configure_eddy_ng_tap
            start_klipper
            echo -e "${GREEN}Eddy NG tap start print function enabled successfully!${NC}"
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        5)
            install_numpy_for_adxl
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        6)
            echo "Installing Crowsnest..."
            cd ~
            git clone https://github.com/mainsail-crew/crowsnest.git
            cd crowsnest
            sudo bash ./tools/install.sh
            echo -e "${GREEN}Crowsnest installation complete!${NC}"
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        7)
            echo "Installing Moonraker-Timelapse..."
            cd ~
            git clone https://github.com/mainsail-crew/moonraker-timelapse.git
            cd moonraker-timelapse
            bash ./install.sh
            echo -e "${GREEN}Moonraker-Timelapse installation complete!${NC}"
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        0) show_main_menu ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; additional_features_menu ;;
    esac
}

# Software management menu
software_management_menu() {
    show_header
    echo -e "${BLUE}SOFTWARE MANAGEMENT${NC}"
    echo "1) Install Kiauh"
    echo "2) Update SV08 macros"
    echo "3) Check for system updates"
    echo "0) Back to main menu"
    echo ""
    read -p "Select an option: " sw_choice
    
    case $sw_choice in
        1) install_kiauh ;;
        2) update_macros ;;
        3) check_system_updates ;;
        0) show_main_menu ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; software_management_menu ;;
    esac
}

# Function to install Kiauh
install_kiauh() {
    show_header
    echo -e "${BLUE}INSTALL KIAUH${NC}"
    echo "Kiauh is the Klipper Installation And Update Helper"
    echo ""
    
    if [ -d "${HOME}/kiauh" ]; then
        echo "Kiauh is already installed."
        echo "1) Launch Kiauh"
        echo "2) Update Kiauh"
        echo "0) Back to software menu"
        
        read -p "Select option: " kiauh_option
        
        case $kiauh_option in
            1)
                cd ~/kiauh
                ./kiauh.sh
                ;;
            2)
                cd ~/kiauh
                git pull
                echo -e "${GREEN}Kiauh updated successfully!${NC}"
                ;;
            0)
                software_management_menu
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    else
        echo "Installing Kiauh..."
        cd ~
        git clone https://github.com/th33xitus/kiauh.git
        
        if [ -d "${HOME}/kiauh" ]; then
            echo -e "${GREEN}Kiauh installed successfully!${NC}"
            echo "Would you like to launch Kiauh now?"
            read -p "(y/N): " launch_kiauh
            
            if [[ "$launch_kiauh" =~ ^[Yy]$ ]]; then
                cd ~/kiauh
                ./kiauh.sh
            fi
        else
            echo -e "${RED}Failed to install Kiauh. Please check your internet connection.${NC}"
        fi
    fi
    
    read -p "Press Enter to continue..." dummy
    software_management_menu
}

update_macros() {
    show_header
    echo -e "${BLUE}UPDATE SV08 MACROS${NC}"
    
    echo "This will update your SV08 macros to the latest version."
    echo "Your current macros will be backed up first."
    
    read -p "Continue with update? (y/N): " confirm_update
    
    if [[ "$confirm_update" =~ ^[Yy]$ ]]; then
        check_klipper
        create_backup_dir
        stop_klipper
        backup_existing_macros
        install_macros
        start_klipper
        
        echo -e "${GREEN}SV08 macros updated successfully!${NC}"
    else
        echo "Update cancelled."
    fi
    
    read -p "Press Enter to continue..." dummy
    software_management_menu
}

check_system_updates() {
    show_header
    echo -e "${BLUE}CHECK FOR SYSTEM UPDATES${NC}"
    
    echo "Checking for system updates..."
    sudo apt update
    
    echo -e "\n${CYAN}Available Updates:${NC}"
    apt list --upgradable
    
    echo ""
    read -p "Would you like to install available updates? (y/N): " install_updates
    
    if [[ "$install_updates" =~ ^[Yy]$ ]]; then
        echo "Installing updates... This may take a while."
        sudo apt upgrade -y
        echo -e "${GREEN}System updates complete!${NC}"
    else
        echo "Update installation cancelled."
    fi
    
    read -p "Press Enter to continue..." dummy
    software_management_menu
}

# Uninstall menu
uninstall_menu() {
    show_header
    echo -e "${RED}UNINSTALL SV08 MACROS${NC}"
    
    echo "This will remove the SV08 replacement macros and restore your previous configuration."
    echo "Are you sure you want to uninstall?"
    
    read -p "Type 'YES' to confirm: " confirm
    
    if [ "$confirm" = "YES" ]; then
        check_klipper
        create_backup_dir
        stop_klipper
        get_user_macro_files
        restore_backup
        start_klipper
        
        echo -e "${GREEN}Uninstallation complete! Original configuration has been restored.${NC}"
    else
        echo "Uninstallation cancelled."
    fi
    
    read -p "Press Enter to continue..." dummy
    show_main_menu
}

# Function to configure stepper drivers
configure_stepper_drivers() {
    echo -e "${CYAN}=== Stepper Driver Configuration ===${NC}"
    echo "This will help you configure your stepper drivers and TMC settings."
    echo ""
    
    while true; do
        echo -e "${BLUE}Select Stepper to Configure:${NC}"
        echo "1) X Stepper"
        echo "2) Y Stepper" 
        echo "3) Z Stepper"
        echo "4) E Stepper (Extruder)"
        echo "5) Return to main menu"
        echo ""
        read -p "Enter your choice (1-5): " stepper_choice
        
        case $stepper_choice in
            1) configure_axis_stepper "x" ;;
            2) configure_axis_stepper "y" ;;
            3) configure_axis_stepper "z" ;;
            4) configure_extruder_stepper ;;
            5) break ;;
            *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
        esac
        echo ""
    done
}

# Function to apply stepper configuration using AWK
apply_stepper_config() {
    local axis="$1"
    local working_cfg="$2"
    local printer_cfg="$3"
    shift 3
    local step_pin="$1" dir_pin="$2" enable_pin="$3" microsteps="$4" rotation_distance="$5"
    local endstop_pin="$6" position_endstop="$7" position_min="$8" position_max="$9"
    shift 9
    local homing_speed="$1" homing_retract_dist="$2" homing_positive_dir="$3"
    local uart_pin="$4" diag_pin="$5" uart_address="$6" run_current="$7" driver_sgthrs="$8"
    local stealthchop_threshold="$9" interpolate="${10}" sense_resistor="${11}"
    
    # Create the configuration blocks
    local stepper_config=""
    stepper_config+="[stepper_${axis}]\n"
    [ -n "$step_pin" ] && stepper_config+="step_pin: ${step_pin}\n"
    [ -n "$dir_pin" ] && stepper_config+="dir_pin: ${dir_pin}\n"
    [ -n "$enable_pin" ] && stepper_config+="enable_pin: ${enable_pin}\n"
    stepper_config+="microsteps: ${microsteps}\n"
    stepper_config+="rotation_distance: ${rotation_distance}\n"
    stepper_config+="endstop_pin: ${endstop_pin}\n"
    [ -n "$position_endstop" ] && stepper_config+="position_endstop: ${position_endstop}\n"
    stepper_config+="position_min: ${position_min}\n"
    [ -n "$position_max" ] && stepper_config+="position_max: ${position_max}\n"
    stepper_config+="homing_speed: ${homing_speed}\n"
    stepper_config+="homing_retract_dist: ${homing_retract_dist}\n"
    stepper_config+="homing_positive_dir: ${homing_positive_dir}\n\n"
    
    local tmc_config=""
    tmc_config+="[tmc2209 stepper_${axis}]\n"
    [ -n "$uart_pin" ] && tmc_config+="uart_pin: ${uart_pin}\n"
    [ -n "$diag_pin" ] && tmc_config+="diag_pin: ${diag_pin}\n"
    tmc_config+="uart_address: ${uart_address}\n"
    [ -n "$run_current" ] && tmc_config+="run_current: ${run_current}\n"
    [ -n "$driver_sgthrs" ] && tmc_config+="driver_sgthrs: ${driver_sgthrs}\n"
    tmc_config+="stealthchop_threshold: ${stealthchop_threshold}\n"
    tmc_config+="interpolate: ${interpolate}\n"
    tmc_config+="sense_resistor: ${sense_resistor}\n"
    
    # Use AWK to replace or add the configuration sections
    awk -v stepper_section="stepper_${axis}" \
        -v tmc_section="tmc2209 stepper_${axis}" \
        -v stepper_config="$stepper_config" \
        -v tmc_config="$tmc_config" '
    BEGIN { 
        in_stepper = 0
        in_tmc = 0
        stepper_replaced = 0
        tmc_replaced = 0
    }
    
    # Start of stepper section
    $0 ~ "^\\[" stepper_section "\\]" {
        print stepper_config
        stepper_replaced = 1
        in_stepper = 1
        next
    }
    
    # Start of TMC section  
    $0 ~ "^\\[" tmc_section "\\]" {
        print tmc_config
        tmc_replaced = 1
        in_tmc = 1
        next
    }
    
    # End of any section
    /^\[/ && (in_stepper || in_tmc) {
        in_stepper = 0
        in_tmc = 0
        print
        next
    }
    
    # Skip lines within sections being replaced
    in_stepper || in_tmc { next }
    
    # Print all other lines
    { print }
    
    END {
        # Add sections if they were not found and replaced
        if (!stepper_replaced) {
            print stepper_config
        }
        if (!tmc_replaced) {
            print tmc_config  
        }
    }
    ' "$working_cfg" > "${working_cfg}.new"
    
    mv "${working_cfg}.new" "$printer_cfg"
    echo "Configuration applied to printer.cfg"
}

# Enhanced function to properly calculate endstop position and position_min
configure_axis_stepper() {
    local axis="$1"
    local AXIS=$(echo "$axis" | tr '[:lower:]' '[:upper:]')
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    local working_cfg="${BACKUP_DIR}/printer.cfg.stepper_${axis}_${CURRENT_DATE}"
    
    echo -e "${CYAN}=== Configuring ${AXIS} Stepper ===${NC}"
    
    # Create backup
    if [ ! -f "$printer_cfg" ]; then
        echo -e "${RED}[ERROR] printer.cfg not found at ${printer_cfg}${NC}"
        return
    fi
    
    cp "$printer_cfg" "$working_cfg"
    echo "Created backup at ${working_cfg}"
    
    # Collect basic stepper parameters
    echo -e "${YELLOW}Enter stepper parameters (press Enter to skip):${NC}"
    read -p "step_pin: " step_pin
    read -p "dir_pin: " dir_pin
    read -p "enable_pin: " enable_pin
    read -p "microsteps [16]: " microsteps
    microsteps=${microsteps:-16}
    read -p "rotation_distance [40]: " rotation_distance
    rotation_distance=${rotation_distance:-40}
    read -p "endstop_pin [tmc2209_stepper_${axis}:virtual_endstop]: " endstop_pin
    endstop_pin=${endstop_pin:-"tmc2209_stepper_${axis}:virtual_endstop"}
    
    # Enhanced position and endstop configuration
    echo ""
    echo -e "${CYAN}=== Endstop and Position Configuration ===${NC}"
    echo "We need to determine three key values:"
    echo "1. Where the endstop physically triggers"
    echo "2. Where you want coordinate 0 to be (position_endstop)"  
    echo "3. How far past 0 the axis can travel (position_min)"
    echo ""
    
    # Step 1: Determine endstop trigger location
    echo -e "${BLUE}Step 1: Physical Endstop Location${NC}"
    echo "Where does the endstop switch/sensor physically trigger?"
    echo "Examples:"
    echo "  - If endstop triggers when nozzle is 5mm from bed edge: enter 5"
    echo "  - If endstop triggers exactly at desired 0 position: enter 0"
    echo "  - If endstop triggers when nozzle is past desired 0: enter negative value"
    echo ""
    read -p "Endstop trigger distance from desired 0 position (mm): " endstop_trigger_distance
    endstop_trigger_distance=${endstop_trigger_distance:-0}
    
    # Step 2: Calculate position_endstop
    echo ""
    echo -e "${BLUE}Step 2: Position Endstop Calculation${NC}"
    echo "position_endstop defines where coordinate 0 will be after homing."
    echo "Based on your endstop trigger distance: ${endstop_trigger_distance}mm"
    
    local position_endstop
    if [ "$endstop_trigger_distance" = "0" ]; then
        position_endstop="0"
        echo "Endstop triggers at desired 0 position → position_endstop: 0"
    elif [ "$endstop_trigger_distance" -gt 0 ] 2>/dev/null; then
        position_endstop="-${endstop_trigger_distance}"
        echo "Endstop triggers ${endstop_trigger_distance}mm before 0 → position_endstop: -${endstop_trigger_distance}"
    else
        # Negative trigger distance means endstop is past 0
        positive_distance=$(echo "$endstop_trigger_distance" | sed 's/^-//')
        position_endstop="$positive_distance"
        echo "Endstop triggers ${positive_distance}mm past 0 → position_endstop: ${positive_distance}"
    fi
    
    # Step 3: Determine additional negative travel
    echo ""
    echo -e "${BLUE}Step 3: Additional Negative Travel${NC}"
    echo "After homing to position 0, can the axis travel further in the negative direction?"
    echo "This is the mechanical travel available beyond your 0 position."
    echo ""
    read -p "Additional negative travel available (mm) [0]: " additional_negative_travel
    additional_negative_travel=${additional_negative_travel:-0}
    
    # Calculate position_min
    local position_min
    if [ "$additional_negative_travel" = "0" ]; then
        position_min="0"
    else
        position_min="-${additional_negative_travel}"
    fi
    
    # Step 4: Position max (manual)
    echo ""
    echo -e "${BLUE}Step 4: Maximum Position${NC}"
    echo "For position_max, you need to physically jog the axis to its maximum travel."
    echo "Leave blank to configure this later manually."
    read -p "position_max (maximum travel coordinate): " position_max
    
    # Summary with visual representation
    echo ""
    echo -e "${CYAN}=== Configuration Summary ===${NC}"
    echo "Visual representation of ${AXIS} axis:"
    echo ""
    
    # Create a simple ASCII representation
    local endstop_pos="ENDSTOP"
    local zero_pos="0"
    local min_pos="MIN"
    local max_pos="MAX"
    
    echo "Axis Travel: [${min_pos}]----[${zero_pos}]----[${endstop_pos}]----[${max_pos}]"
    echo ""
    echo "Calculated values:"
    echo "  position_min: $position_min (furthest negative travel)"
    echo "  position_endstop: $position_endstop (where 0 coordinate will be)"
    echo "  position_max: ${position_max:-'(to be set manually)'}"
    echo "  endstop_trigger_distance: ${endstop_trigger_distance}mm"
    echo "  additional_negative_travel: ${additional_negative_travel}mm"
    echo ""
    
    # Validation
    echo -e "${YELLOW}Validation:${NC}"
    echo "• Endstop will trigger at: calculated position"
    echo "• After homing, 0 position will be at: position_endstop ($position_endstop)"
    echo "• Axis can travel from $position_min to ${position_max:-'MAX'}"
    echo ""
    
    read -p "Does this configuration look correct? (Y/n): " confirm_config
    if [[ "$confirm_config" =~ ^[Nn]$ ]]; then
        echo "Configuration cancelled. Please restart the configuration process."
        return
    fi
    
    # Homing parameters
    echo ""
    echo -e "${YELLOW}Homing parameters:${NC}"
    read -p "homing_speed [50]: " homing_speed
    homing_speed=${homing_speed:-50}
    read -p "homing_retract_dist [5]: " homing_retract_dist
    homing_retract_dist=${homing_retract_dist:-5}
    
    # Determine homing direction
    local homing_positive_dir="false"
    echo "Setting homing_positive_dir: false (standard for min endstop)"
    
    # TMC2209 parameters
    echo ""
    echo -e "${YELLOW}Enter TMC2209 parameters:${NC}"
    read -p "uart_pin: " uart_pin
    read -p "diag_pin: " diag_pin
    read -p "uart_address [0]: " uart_address
    uart_address=${uart_address:-0}
    read -p "run_current: " run_current
    read -p "driver_sgthrs: " driver_sgthrs
    read -p "stealthchop_threshold [999999]: " stealthchop_threshold
    stealthchop_threshold=${stealthchop_threshold:-999999}
    read -p "interpolate [true]: " interpolate
    interpolate=${interpolate:-true}
    read -p "sense_resistor [0.110]: " sense_resistor
    sense_resistor=${sense_resistor:-0.110}
    
    # Apply the configuration
    apply_stepper_config "$axis" "$working_cfg" "$printer_cfg" \
        "$step_pin" "$dir_pin" "$enable_pin" "$microsteps" "$rotation_distance" \
        "$endstop_pin" "$position_endstop" "$position_min" "$position_max" \
        "$homing_speed" "$homing_retract_dist" "$homing_positive_dir" \
        "$uart_pin" "$diag_pin" "$uart_address" "$run_current" "$driver_sgthrs" \
        "$stealthchop_threshold" "$interpolate" "$sense_resistor"
    
    echo -e "${GREEN}${AXIS} stepper configured successfully!${NC}"
    
    # Post-configuration instructions
    echo ""
    echo -e "${CYAN}=== Next Steps ===${NC}"
    if [ -z "$position_max" ]; then
        echo "1. Test homing: HOME_${AXIS} or G28 ${AXIS}"
        echo "2. Verify 0 position is where expected"
        echo "3. Manually jog to maximum travel and note coordinate"
        echo "4. Update position_max in printer.cfg"
    else
        echo "1. Test homing: HOME_${AXIS} or G28 ${AXIS}"
        echo "2. Verify 0 position is where expected"
        echo "3. Test travel limits: jog to position_min and position_max"
    fi
    echo "5. Test negative travel if configured"
}

# Function to configure extruder stepper
configure_extruder_stepper() {
    echo -e "${CYAN}=== Configuring Extruder Stepper ===${NC}"
    
    # Similar structure but with extruder-specific parameters
    # Include all the extruder parameters you specified
    
    # Ask about PID tuning
    echo ""
    read -p "Would you like to run PID tuning for the hotend? (y/N): " do_pid
    if [[ "$do_pid" =~ ^[Yy]$ ]]; then
        read -p "Enter target temperature for PID tuning (default 200): " pid_temp
        pid_temp=${pid_temp:-200}
        
        echo -e "${YELLOW}Starting PID calibration at ${pid_temp}°C...${NC}"
        echo "This process will take several minutes. Please wait..."
        echo "The hotend will heat up and oscillate around the target temperature."
        
        # Execute PID calibration (this would need to be sent to the printer)
        echo "PID_CALIBRATE HEATER=extruder TARGET=${pid_temp}"
        echo "After completion, use SAVE_CONFIG to save the results."
    fi
}

# NEW: Hardware configuration menu
hardware_config_menu() {
    show_header
    echo -e "${BLUE}HARDWARE CONFIGURATION UTILITIES${NC}"
    echo "1) Check MCU IDs"
    echo "2) Check CAN bus devices"
    echo "3) Enable Eddy NG tap start print function"
    echo "4) Configure firmware retraction"
    echo "5) Configure force_move"
    echo "6) Add extruder settings"
    echo "7) Configure stepper drivers"
    echo "0) Back to main menu"
    echo ""
    read -p "Select an option: " hw_choice
    
    case $hw_choice in
        1) check_mcu_ids ;;
        2) check_can_bus ;;
        3) configure_eddy_ng_tap; hardware_config_menu ;;
        4) add_firmware_retraction_to_printer_cfg; hardware_config_menu ;;
        5) add_force_move; hardware_config_menu ;;
        6) add_extruder_settings_to_printer_cfg; hardware_config_menu ;;
        7) configure_stepper_drivers; hardware_config_menu ;;
        0) show_main_menu ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; hardware_config_menu ;;
    esac
}

# ENHANCED: Function to check MCU IDs with more robust section detection
check_mcu_ids() {
    show_header
    echo -e "${BLUE}MCU ID CHECKER & UPDATER${NC}"
    echo "This will show MCU IDs of all connected devices and let you update your printer.cfg"
    echo ""
    
    # First check if ls command exists
    if ! command -v ls &> /dev/null; then
        echo -e "${RED}Error: ls command not found${NC}"
        read -p "Press Enter to continue..." dummy
        hardware_config_menu
        return
    fi
    
    # Array to store all found MCU IDs with descriptive labels
    declare -a all_mcus
    
    echo "Serial MCUs:"
    echo "------------"
    if [ -d "/dev/serial/by-id/" ]; then
        i=1
        while read -r line; do
            mcu_path=$(echo "$line" | awk '{print $NF}')
            mcu_id=$(echo "$line" | awk '{print $9}')
            if [ -n "$mcu_id" ] && [ "$mcu_id" != "." ] && [ "$mcu_id" != ".." ]; then
                echo "$i) $mcu_id → $mcu_path"
                all_mcus+=("SERIAL|$mcu_id|$mcu_path")
                i=$((i+1))
            fi
        done < <(ls -la /dev/serial/by-id/ 2>/dev/null | grep -v '^total' | grep -v '^d')
    else
        echo "No serial MCUs found"
    fi
    echo ""
    
    echo "USB MCUs:"
    echo "---------"
    if [ -d "/dev/serial/by-path/" ]; then
        while read -r line; do
            mcu_path=$(echo "$line" | awk '{print $NF}')
            mcu_id=$(echo "$line" | awk '{print $9}')
            if [ -n "$mcu_id" ] && [ "$mcu_id" != "." ] && [ "$mcu_id" != ".." ]; then
                echo "$i) $mcu_id → $mcu_path"
                all_mcus+=("USB|$mcu_id|$mcu_path")
                i=$((i+1))
            fi
        done < <(ls -la /dev/serial/by-path/ 2>/dev/null | grep -v '^total' | grep -v '^d')
    else
        echo "No USB MCU paths found"
    fi
    echo ""
    
    # CAN bus UUIDs if available
    if [ -f "${HOME}/klipper/scripts/canbus_query.py" ] && command -v ip &> /dev/null; then
        echo "CAN bus devices:"
        echo "--------------"
        can_interfaces=($(ip -d link show | grep -i can | cut -d: -f2 | awk '{print $1}' | tr -d ' '))
        
        if [ ${#can_interfaces[@]} -gt 0 ]; then
            for interface in "${can_interfaces[@]}"; do
                echo "Querying CAN interface: $interface"
                can_results=$("${HOME}/klippy-env/bin/python" "${HOME}/klipper/scripts/canbus_query.py" "$interface" 2>/dev/null || echo "Error querying $interface")
                if [[ "$can_results" != *"Error"* ]]; then
                    while read -r uuid; do
                        if [[ -n "$uuid" ]]; then
                            echo "$i) $uuid (CAN bus on $interface)"
                            all_mcus+=("CAN|$uuid|$interface")
                            i=$((i+1))
                        fi
                    done < <(echo "$can_results" | grep -o '[0-9a-f]\{32\}')
                else
                    echo "  No devices found on $interface"
                fi
            done
        else
            echo "  No CAN interfaces found"
        fi
        echo ""
    fi
    
    # Show currently configured MCUs in printer.cfg
    echo "Currently configured MCUs in printer.cfg:"
    echo "----------------------------------------"
    
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    declare -a configured_mcus
    
    if [ -f "$printer_cfg" ]; then
        while read -r mcu_line; do
            section=$(echo "$mcu_line" | tr -d '[:space:]')
            section=${section#\[}
            section=${section%\]}
            
            if [[ "$section" == mcu* ]]; then
                echo -e "${CYAN}Found MCU section: [$section]${NC}"
                configured_mcus+=("$section")
                
                serial_line=$(sed -n "/\[$section\]/,/^\[/p" "$printer_cfg" | grep -i "serial:" | head -n 1)
                canbus_line=$(sed -n "/\[$section\]/,/^\[/p" "$printer_cfg" | grep -i "canbus_uuid:" | head -n 1)
                
                echo -e "${CYAN}[$section]${NC}"
                if [ -n "$serial_line" ]; then
                    echo "  $serial_line"
                elif [ -n "$canbus_line" ]; then
                    echo "  $canbus_line"
                else
                    echo "  No serial/canbus configuration found"
                fi
                echo ""
            fi
        done < <(grep -i "^\s*\[mcu" "$printer_cfg")
        
        if [ ${#configured_mcus[@]} -eq 0 ]; then
            echo -e "${YELLOW}No MCU sections found using standard detection.${NC}"
        fi
    else
        echo -e "${RED}printer.cfg not found${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo "1) Update MCU configuration in printer.cfg"
    echo "2) Return to hardware menu"
    
    read -p "Select an option: " mcu_option
    
    case $mcu_option in
        1)
            if [ ${#all_mcus[@]} -eq 0 ]; then
                echo -e "${RED}No MCUs found to configure${NC}"
                read -p "Press Enter to continue..." dummy
                hardware_config_menu
                return
            fi
            
            if [ ! -f "$printer_cfg" ]; then
                echo -e "${RED}printer.cfg not found. Cannot update configuration.${NC}"
                read -p "Press Enter to continue..." dummy
                hardware_config_menu
                return
            fi
            
            local backup_file="${BACKUP_DIR}/printer.cfg.mcu_update_${CURRENT_DATE}"
            cp "$printer_cfg" "$backup_file"
            echo "Created backup at $backup_file"
            
            if [ ${#configured_mcus[@]} -gt 0 ]; then
                echo ""
                echo "Which MCU section would you like to update?"
                for i in "${!configured_mcus[@]}"; do
                    echo "$((i+1))) ${configured_mcus[$i]}"
                done
                echo "$((${#configured_mcus[@]}+1))) Create new MCU section"
                
                read -p "Select MCU number: " mcu_num
                
                if [[ ! "$mcu_num" =~ ^[0-9]+$ ]] || [ "$mcu_num" -lt 1 ] || [ "$mcu_num" -gt $((${#configured_mcus[@]}+1)) ]; then
                    echo -e "${RED}Invalid selection${NC}"
                    read -p "Press Enter to continue..." dummy
                    hardware_config_menu
                    return
                fi
                
                if [ "$mcu_num" -eq $((${#configured_mcus[@]}+1)) ]; then
                    echo "Select MCU type:"
                    echo "1) Main MCU [mcu]"
                    echo "2) Secondary MCU (e.g., [mcu z], [mcu extruder])"
                    read -p "Select type (1/2): " mcu_type
                    
                    if [ "$mcu_type" -eq 1 ]; then
                        selected_mcu="mcu"
                    elif [ "$mcu_type" -eq 2 ]; then
                        read -p "Enter name for secondary MCU (e.g., z, extruder): " secondary_name
                        selected_mcu="mcu $secondary_name"
                    else
                        echo -e "${RED}Invalid selection${NC}"
                        read -p "Press Enter to continue..." dummy
                        hardware_config_menu
                        return
                    fi
                    
                    sed -i "1i[$selected_mcu]\n" "$printer_cfg"
                    echo -e "${GREEN}Created new [$selected_mcu] section in printer.cfg${NC}"
                else
                    selected_mcu="${configured_mcus[$((mcu_num-1))]}"
                fi
            else
                echo "No MCU sections found. Creating a new one."
                echo "Select MCU type:"
                echo "1) Main MCU [mcu]"
                echo "2) Secondary MCU (e.g., [mcu z], [mcu extruder])"
                read -p "Select type (1/2): " mcu_type
                
                if [ "$mcu_type" -eq 1 ]; then
                    selected_mcu="mcu"
                elif [ "$mcu_type" -eq 2 ]; then
                    read -p "Enter name for secondary MCU (e.g., z, extruder): " secondary_name
                    selected_mcu="mcu $secondary_name"
                else
                    echo -e "${RED}Invalid selection${NC}"
                    read -p "Press Enter to continue..." dummy
                    hardware_config_menu
                    return
                fi
                
                sed -i "1i[$selected_mcu]\n" "$printer_cfg"
                echo -e "${GREEN}Created new [$selected_mcu] section in printer.cfg${NC}"
            fi
            
            echo ""
            echo "Which MCU ID would you like to use for [${selected_mcu}]?"
            for i in "${!all_mcus[@]}"; do
                IFS='|' read -r type id path <<< "${all_mcus[$i]}"
                if [ "$type" == "CAN" ]; then
                    echo "$((i+1))) $id (CAN bus on $path)"
                else
                    echo "$((i+1))) $id ($type)"
                fi
            done
            
            read -p "Select MCU ID number: " id_num
            
            if [[ ! "$id_num" =~ ^[0-9]+$ ]] || [ "$id_num" -lt 1 ] || [ "$id_num" -gt ${#all_mcus[@]} ]; then
                echo -e "${RED}Invalid selection${NC}"
                read -p "Press Enter to continue..." dummy
                hardware_config_menu
                return
            fi
            
            selected_mcu_info="${all_mcus[$((id_num-1))]}"
            IFS='|' read -r type id path <<< "$selected_mcu_info"
            
            local tmp_file="${BACKUP_DIR}/printer.cfg.tmp_${CURRENT_DATE}"
            
            if [ "$type" == "CAN" ]; then
                cat "$printer_cfg" > "$tmp_file"
                
                selected_mcu_escaped=$(echo "$selected_mcu" | sed 's/ /\\ /g')
                
                sed -i "/^\[$selected_mcu_escaped\]/,/^\[/ {/^\[$selected_mcu_escaped\]/b; /^\[/b; /^serial:/d; /^canbus_uuid:/d}" "$tmp_file" 2>/dev/null || true
                
                if [[ "$selected_mcu" == *" "* ]]; then
                    awk -v mcu="[$selected_mcu]" -v uuid="canbus_uuid: $id" '
                    $0 ~ mcu {print; print uuid; next}
                    {print}
                    ' "$tmp_file" > "${tmp_file}.new"
                    mv "${tmp_file}.new" "$tmp_file"
                else
                    sed -i "/^\[$selected_mcu\]/a canbus_uuid: $id" "$tmp_file"
                fi
                
                echo -e "${GREEN}Updated [$selected_mcu] with CAN bus UUID: $id${NC}"
            else
                cat "$printer_cfg" > "$tmp_file"
                
                selected_mcu_escaped=$(echo "$selected_mcu" | sed 's/ /\\ /g')
                
                sed -i "/^\[$selected_mcu_escaped\]/,/^\[/ {/^\[$selected_mcu_escaped\]/b; /^\[/b; /^serial:/d; /^canbus_uuid:/d}" "$tmp_file" 2>/dev/null || true
                
                if [[ "$selected_mcu" == *" "* ]]; then
                    awk -v mcu="[$selected_mcu]" -v serial="serial: /dev/serial/by-id/$id" '
                    $0 ~ mcu {print; print serial; next}
                    {print}
                    ' "$tmp_file" > "${tmp_file}.new"
                    mv "${tmp_file}.new" "$tmp_file"
                else
                    sed -i "/^\[$selected_mcu\]/a serial: /dev/serial/by-id/$id" "$tmp_file"
                fi
                
                echo -e "${GREEN}Updated [$selected_mcu] with serial: /dev/serial/by-id/$id${NC}"
            fi
            
            mv "$tmp_file" "$printer_cfg"
            echo -e "${GREEN}MCU configuration updated successfully!${NC}"
            echo "Backup of previous configuration saved at: $backup_file"
            
            read -p "Press Enter to continue..." dummy
            check_mcu_ids
            ;;
        2|*)
            hardware_config_menu
            ;;
    esac
}

# Function to check CAN bus devices
check_can_bus() {
    show_header
    echo -e "${BLUE}CAN BUS DEVICE CHECKER${NC}"
    echo "Checking for CAN interfaces and devices..."
    echo ""
    
    if ! command -v ip &> /dev/null; then
        echo -e "${RED}Error: ip command not found${NC}"
        read -p "Press Enter to continue..." dummy
        hardware_config_menu
        return
    fi
    
    can_interfaces=($(ip -d link show | grep -i can | cut -d: -f2 | awk '{print $1}' | tr -d ' '))
    
    if [ ${#can_interfaces[@]} -eq 0 ]; then
        echo -e "${YELLOW}No CAN interfaces found${NC}"
        read -p "Press Enter to continue..." dummy
        hardware_config_menu
        return
    fi
    
    for interface in "${can_interfaces[@]}"; do
        echo -e "${CYAN}Interface: $interface${NC}"
        echo "Status: $(ip link show $interface | grep -o 'state [A-Z]*' | cut -d' ' -f2)"
        
        if [ -f "${HOME}/klipper/scripts/canbus_query.py" ]; then
            echo "Devices found:"
            can_results=$("${HOME}/klippy-env/bin/python" "${HOME}/klipper/scripts/canbus_query.py" "$interface" 2>/dev/null || echo "Error querying $interface")
            if [[ "$can_results" != *"Error"* ]]; then
                while read -r uuid; do
                    if [[ -n "$uuid" ]]; then
                        echo "  - UUID: $uuid"
                    fi
                done < <(echo "$can_results" | grep -o '[0-9a-f]\{32\}')
            else
                echo "  No devices found or error querying interface"
            fi
        else
            echo "  Cannot query devices (canbus_query.py not found)"
        fi
        echo ""
    done
    
    read -p "Press Enter to continue..." dummy
    hardware_config_menu
}

# Backup management menu
manage_backups() {
    show_header
    echo -e "${BLUE}BACKUP MANAGEMENT${NC}"
    echo "1) List all backups"
    echo "2) Restore from backup"
    echo "3) Clean old backups"
    echo "0) Back to main menu"
    echo ""
    read -p "Select an option: " backup_choice
    
    case $backup_choice in
        1) list_backups ;;
        2) restore_from_backup ;;
        3) clean_old_backups ;;
        0) show_main_menu ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; manage_backups ;;
    esac
}

list_backups() {
    show_header
    echo -e "${BLUE}ALL BACKUPS${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}No backup directory found${NC}"
        read -p "Press Enter to continue..." dummy
        manage_backups
        return
    fi
    
    backup_files=($(find "$BACKUP_DIR" -name "*.backup_*" -type f | sort -r))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No backup files found${NC}"
    else
        echo "Found ${#backup_files[@]} backup files:"
        echo ""
        for backup in "${backup_files[@]}"; do
            filename=$(basename "$backup")
            filesize=$(du -h "$backup" | cut -f1)
            echo "  $filename ($filesize)"
        done
    fi
    
    read -p "Press Enter to continue..." dummy
    manage_backups
}

restore_from_backup() {
    show_header
    echo -e "${BLUE}RESTORE FROM BACKUP${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}No backup directory found${NC}"
        read -p "Press Enter to continue..." dummy
        manage_backups
        return
    fi
    
    backup_files=($(find "$BACKUP_DIR" -name "*.backup_*" -type f | sort -r))
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No backup files found${NC}"
        read -p "Press Enter to continue..." dummy
        manage_backups
        return
    fi
    
    echo "Select a backup to restore:"
    echo ""
    for i in "${!backup_files[@]}"; do
        filename=$(basename "${backup_files[$i]}")
        echo "$((i+1))) $filename"
    done
    echo "0) Cancel"
    
    read -p "Select backup number: " backup_num
    
    if [ "$backup_num" -eq 0 ]; then
        manage_backups
        return
    fi
    
    if [[ ! "$backup_num" =~ ^[0-9]+$ ]] || [ "$backup_num" -lt 1 ] || [ "$backup_num" -gt ${#backup_files[@]} ]; then
        echo -e "${RED}Invalid selection${NC}"
        read -p "Press Enter to continue..." dummy
        restore_from_backup
        return
    fi
    
    selected_backup="${backup_files[$((backup_num-1))]}"
    filename=$(basename "$selected_backup")
    
    # Determine target file based on backup name
    if [[ "$filename" == printer.cfg.backup_* ]]; then
        target_file="${KLIPPER_CONFIG}/printer.cfg"
    elif [[ "$filename" == macros.cfg.backup_* ]]; then
        target_file="${KLIPPER_CONFIG}/macros.cfg"
    else
        # Extract original filename from backup name
        original_name=$(echo "$filename" | sed 's/\.backup_[0-9]*_[0-9]*$//')
        target_file="${KLIPPER_CONFIG}/$original_name"
    fi
    
    echo ""
    echo "This will restore:"
    echo "  From: $filename"
    echo "  To: $(basename "$target_file")"
    echo ""
    read -p "Are you sure? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        cp "$selected_backup" "$target_file"
        echo -e "${GREEN}Backup restored successfully!${NC}"
        echo "Restarting Klipper..."
        sudo systemctl restart $KLIPPER_SERVICE_NAME
    else
        echo "Restore cancelled."
    fi
    
    read -p "Press Enter to continue..." dummy
    manage_backups
}

clean_old_backups() {
    show_header
    echo -e "${BLUE}CLEAN OLD BACKUPS${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}No backup directory found${NC}"
        read -p "Press Enter to continue..." dummy
        manage_backups
        return
    fi
    
    echo "How many days of backups would you like to keep?"
    echo "Backups older than this will be deleted."
    read -p "Days to keep (default: 7): " days_to_keep
    
    # Default to 7 days if no input
    days_to_keep=${days_to_keep:-7}
    
    if [[ ! "$days_to_keep" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid number${NC}"
        read -p "Press Enter to continue..." dummy
        clean_old_backups
        return
    fi
    
    old_backups=($(find "$BACKUP_DIR" -name "*.backup_*" -type f -mtime +$days_to_keep))
    
    if [ ${#old_backups[@]} -eq 0 ]; then
        echo -e "${GREEN}No old backups found to clean${NC}"
    else
        echo "Found ${#old_backups[@]} backup(s) older than $days_to_keep days:"
        echo ""
        for backup in "${old_backups[@]}"; do
            echo "  $(basename "$backup")"
        done
        echo ""
        read -p "Delete these backups? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            for backup in "${old_backups[@]}"; do
                rm "$backup"
            done
            echo -e "${GREEN}Old backups cleaned successfully!${NC}"
        else
            echo "Cleanup cancelled."
        fi
    fi
    
    read -p "Press Enter to continue..." dummy
    manage_backups
}

# Diagnostics menu
diagnostics_menu() {
    show_header
    echo -e "${BLUE}DIAGNOSTICS & TROUBLESHOOTING${NC}"
    echo "1) Check Klipper status"
    echo "2) View Klipper logs"
    echo "3) Verify configuration"
    echo "4) Run full system diagnostics"
    echo "0) Back to main menu"
    echo ""
    read -p "Select an option: " diag_choice
    
    case $diag_choice in
        1) check_klipper_status ;;
        2) view_klipper_logs ;;
        3) verify_configuration ;;
        4) run_full_diagnostics ;;
        0) show_main_menu ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2; diagnostics_menu ;;
    esac
}

check_klipper_status() {
    show_header
    echo -e "${BLUE}KLIPPER STATUS${NC}"
    
    echo "Checking Klipper service status..."
    sudo systemctl status $KLIPPER_SERVICE_NAME
    
    echo ""
    read -p "Press Enter to continue..." dummy
    diagnostics_menu
}

view_klipper_logs() {
    show_header
    echo -e "${BLUE}KLIPPER LOGS${NC}"
    
    echo "Last 50 log entries from Klipper:"
    sudo journalctl -u $KLIPPER_SERVICE_NAME -n 50 --no-pager
    
    echo ""
    echo "1) View more log entries"
    echo "2) View only errors"
    echo "0) Back to diagnostics menu"
    
    read -p "Select an option: " log_choice
    
    case $log_choice in
        1)
            echo "Last 200 log entries from Klipper:"
            sudo journalctl -u $KLIPPER_SERVICE_NAME -n 200 --no-pager
            ;;
        2)
            echo "Errors from Klipper log:"
            sudo journalctl -u $KLIPPER_SERVICE_NAME -n 500 --no-pager | grep -i error
            ;;
        0)
            diagnostics_menu
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..." dummy
    diagnostics_menu
}

verify_configuration() {
    show_header
    echo -e "${BLUE}CONFIGURATION VERIFICATION${NC}"
    
    local errors=0
    
    # Check that macros.cfg exists
    if [ ! -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
        echo -e "${RED}[ERROR] macros.cfg not found${NC}"
        errors=$((errors+1))
    else
        echo -e "${GREEN}[OK] macros.cfg exists${NC}"
    fi
    
    # Check that printer.cfg includes macros.cfg
    if [ -f "${KLIPPER_CONFIG}/printer.cfg" ]; then
        if ! grep -q '^\[include macros\.cfg\]' "${KLIPPER_CONFIG}/printer.cfg"; then
            echo -e "${YELLOW}[WARNING] printer.cfg does not include macros.cfg${NC}"
            errors=$((errors+1))
        else
            echo -e "${GREEN}[OK] printer.cfg includes macros.cfg${NC}"
        fi
    else
        echo -e "${RED}[ERROR] printer.cfg not found${NC}"
        errors=$((errors+1))
    fi
    
    # Check Klipper service status
    if ! systemctl is-active --quiet $KLIPPER_SERVICE_NAME; then
        echo -e "${RED}[ERROR] Klipper service not running${NC}"
        errors=$((errors+1))
    else
        echo -e "${GREEN}[OK] Klipper service is running${NC}"
    fi
    
    echo ""
    echo "Checking for required includes..."
    
    # Check for mandatory includes
    if [ -f "${KLIPPER_CONFIG}/printer.cfg" ]; then
        for include in "macros.cfg"; do
            if grep -q "^\[include $include\]" "${KLIPPER_CONFIG}/printer.cfg"; then
                echo -e "${GREEN}[OK] Found include for $include${NC}"
            else
                echo -e "${YELLOW}[WARNING] Missing include for $include${NC}"
            fi
        done
    fi
    
    echo ""
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[SUCCESS] All checks passed! Configuration appears to be working correctly.${NC}"
    else
        echo -e "${YELLOW}[WARNING] Found $errors potential issue(s) with your installation.${NC}"
    fi
    
    read -p "Press Enter to continue..." dummy
    diagnostics_menu
}

run_full_diagnostics() {
    show_header
    echo -e "${BLUE}FULL SYSTEM DIAGNOSTICS${NC}"
    
    echo "This will perform a comprehensive check of your system."
    echo "It may take a few moments to complete."
    echo ""
    read -p "Press Enter to start diagnostics..." dummy
    
    echo -e "\n${CYAN}SYSTEM INFORMATION${NC}"
    echo "----------------------"
    uname -a
    
    echo -e "\n${CYAN}DISK SPACE${NC}"
    echo "-----------"
    df -h /
    
    echo -e "\n${CYAN}MEMORY USAGE${NC}"
    echo "------------"
    free -h
    
    echo -e "\n${CYAN}KLIPPER SERVICE STATUS${NC}"
    echo "---------------------"
    systemctl status $KLIPPER_SERVICE_NAME --no-pager
    
    echo -e "\n${CYAN}CONFIGURATION FILES${NC}"
    echo "------------------"
    find "$KLIPPER_CONFIG" -maxdepth 1 -name "*.cfg" | sort
    
    echo -e "\n${CYAN}CONFIG INCLUDES${NC}"
    echo "---------------"
    if [ -f "${KLIPPER_CONFIG}/printer.cfg" ]; then
        grep "^\[include" "${KLIPPER_CONFIG}/printer.cfg"
    else
        echo "printer.cfg not found"
    fi
    
    echo -e "\n${CYAN}AVAILABLE MACROS${NC}"
    echo "----------------"
    if [ -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
        grep -n "\[gcode_macro" "${KLIPPER_CONFIG}/macros.cfg" | cut -d[ -f2 | cut -d] -f1 | sort
    else
        echo "macros.cfg not found"
    fi
    
    echo -e "\n${CYAN}RECENT ERRORS${NC}"
    echo "-------------"
    sudo journalctl -u $KLIPPER_SERVICE_NAME -n 50 --no-pager | grep -i error
    
    echo -e "\n${GREEN}Diagnostics complete!${NC}"
    read -p "Press Enter to continue..." dummy
    diagnostics_menu
}

# MAIN EXECUTION
verify_ready

if [ $UNINSTALL ]; then
    check_klipper
    create_backup_dir
    stop_klipper
    get_user_macro_files
    restore_backup
    start_klipper
    echo -e "${GREEN}Uninstallation complete! Original configuration has been restored.${NC}"
elif [ $MENU_MODE -eq 1 ]; then
    # Interactive menu mode (default)
    show_main_menu
else
    # Linear installation flow
    check_klipper
    create_backup_dir
    stop_klipper
    get_user_macro_files
    backup_existing_macros
    install_macros
    check_and_update_printer_cfg
    install_web_interface_config
    add_force_move
    start_klipper
    echo -e "${GREEN}Installation complete! Please check your printer's web interface to verify the changes.${NC}"

    echo ""
    echo "Would you like to install A Better Print_Start Macro?"
    echo "Note: This will also install KAMP, which needs to be configured per KAMP documentation."
    echo "More information can be found at: https://github.com/ss1gohan13/A-better-print_start-macro"
    read -p "Install Print_Start macro and KAMP? (y/N): " install_print_start
    
    if [[ "$install_print_start" =~ ^[Yy]$ ]]; then
        echo "Installing KAMP and A Better Print_Start Macro..."
        install_kamp
        curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-better-print_start-macro/main/install_start_print.sh | bash
        echo ""
        echo -e "${GREEN}Print_Start macro and KAMP have been installed!${NC}"
        echo "Please visit https://github.com/ss1gohan13/A-better-print_start-macro for instructions on configuring your slicer settings."
        
        # Add numpy installation for ADXL resonance measurements
        echo ""
        echo "Would you like to install numpy for ADXL resonance measurements?"
        echo "This is recommended if you plan to use input shaping with an ADXL345 accelerometer."
        read -p "Install numpy? (y/N): " install_numpy
        
        if [[ "$install_numpy" =~ ^[Yy]$ ]]; then
            install_numpy_for_adxl
        fi
    fi

    echo ""
    echo "Would you like to install A Better End Print Macro?"
    echo "Note: This requires additional changes to your slicer settings."
    echo "More information can be found at: https://github.com/ss1gohan13/A-Better-End-Print-Macro"
    read -p "Install End Print macro? (y/N): " install_end_print
    
    if [[ "$install_end_print" =~ ^[Yy]$ ]]; then
        echo "Installing A Better End Print Macro..."
        cd ~
        curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-Better-End-Print-Macro/main/direct_install.sh | bash
        echo ""
        echo -e "${GREEN}End Print macro has been installed!${NC}"
        echo "Please visit https://github.com/ss1gohan13/A-Better-End-Print-Macro for instructions on configuring your slicer settings."
    fi
    
    echo ""
    echo -e "${CYAN}TIP: If you prefer the menu-driven interface, just run this script without the -l flag!${NC}"
fi
