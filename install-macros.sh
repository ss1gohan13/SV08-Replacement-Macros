#!/bin/bash
# Force script to exit if an error occurs
set -e

# Script Info
# Last Updated: 2025-07-23 15:14:30 UTC
# Author: ss1gohan13

KLIPPER_CONFIG="${HOME}/printer_data/config"
KLIPPER_SERVICE_NAME=klipper
BACKUP_DIR="${KLIPPER_CONFIG}/backup"
CURRENT_DATE=$(date +%Y%m%d_%H%M%S)

# Parse command line arguments
usage() {
    echo "Usage: $0 [-c <config path>] [-s <klipper service name>] [-u]" 1>&2
    echo "  -c : Specify custom config path (default: ${KLIPPER_CONFIG})" 1>&2
    echo "  -s : Specify Klipper service name (default: klipper)" 1>&2
    echo "  -u : Uninstall" 1>&2
    echo "  -h : Show this help message" 1>&2
    exit 1
}

while getopts "c:s:uh" arg; do
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
        echo "[ERROR] Klipper config directory not found at \"$KLIPPER_CONFIG\". Please verify path or specify with -c."
        exit -1
    fi
    echo "Klipper config directory found at $KLIPPER_CONFIG"
}

# Create backup directory if it doesn't exist
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Creating backup directory at $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
}

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
    # --- NEW PROMPT ---
    read -p "Do you have a custom macro.cfg installed? (y/N): " has_custom_macro
    if [[ ! "$has_custom_macro" =~ ^[Yy]$ ]]; then
        echo "No custom macro.cfg detected. Will use default 'macros.cfg'."
        MACRO_FILES=("macros.cfg")
        echo "Will download new macros to: macros.cfg"
        return
    fi
    # --- END NEW PROMPT ---
    
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
        echo "[OK] Macros file downloaded successfully"
        echo "First few lines of downloaded file:"
        head -n 3 "${KLIPPER_CONFIG}/macros.cfg"
    else
        echo "[ERROR] Failed to download macros file. Please check your internet connection."
        exit 1
    fi
}

# Completely rewritten function to handle printer.cfg properly
check_and_update_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    
    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        echo "You will need to manually add: [include macros.cfg] to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    echo "Created backup of printer.cfg at ${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    
    echo "Processing printer.cfg file..."

    sed -i 's/^\[include Macro\.cfg\]/# [include Macro.cfg]/' "$working_cfg"
    
    if grep -q '^\[include macros\.cfg\]' "$working_cfg"; then
        echo "Found existing [include macros.cfg]. No need to add another."
    else
        sed -i '1i[include macros.cfg]\n' "$working_cfg"
        echo "Added [include macros.cfg] to the top of printer.cfg"
    fi

    sed -i 's/^# \[include macros\.cfg\]//' "$working_cfg"

    mv "$working_cfg" "$printer_cfg"
    echo "Updated printer.cfg successfully"
}

# Function to install web interface configuration
install_web_interface_config() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
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

# Function to add force_move section to printer.cfg
add_force_move() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        return
    fi

    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    
    if grep -q '^\[force_move\]' "$working_cfg"; then
        if grep -q '^\[force_move\]' -A 2 "$working_cfg" | grep -q 'enable_force_move: true'; then
            rm "$working_cfg"
            return
        else
            sed -i '/^\[force_move\]/,/^$/s/enable_force_move:.*$/enable_force_move: true/' "$working_cfg"
            if ! grep -q 'enable_force_move: true' "$working_cfg"; then
                sed -i '/^\[force_move\]/a enable_force_move: true' "$working_cfg"
            fi
        fi
    else
        sed -i '1i[force_move]\nenable_force_move: true\n' "$working_cfg"
    fi
    mv "$working_cfg" "$printer_cfg"
}

# Modified to restore latest backup of specified macro files
restore_backup() {
    local latest_macros_backup=$(ls -t ${BACKUP_DIR}/macros.cfg.backup_* 2>/dev/null | head -n1)
    if [ -n "$latest_macros_backup" ]; then
        echo "Restoring from backup: $latest_macros_backup"
        cp "$latest_macros_backup" "${KLIPPER_CONFIG}/macros.cfg"
        echo "[OK]"
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
                    echo "[OK]"
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
            echo "[OK]"
        fi
    fi
}

# Service management functions
start_klipper() {
    echo -n "Starting Klipper... "
    sudo systemctl start $KLIPPER_SERVICE_NAME
    echo "[OK]"
}

stop_klipper() {
    echo -n "Stopping Klipper... "
    sudo systemctl stop $KLIPPER_SERVICE_NAME
    echo "[OK]"
}

# Verify script is not run as root
verify_ready() {
    if [ "$EUID" -eq 0 ]; then
        echo "[ERROR] This script must not run as root"
        exit -1
    fi
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
    echo "KAMP installation complete!"
}

# Function to add KAMP include to printer.cfg
add_kamp_include_to_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    local working_cfg="${BACKUP_DIR}/printer.cfg.kamp_include_${CURRENT_DATE}"

    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        echo "You will need to manually add: [include KAMP_Settings.cfg] to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "$working_cfg"

    if grep -q '^\[include KAMP_Settings\.cfg\]' "$working_cfg"; then
        echo "Found existing [include KAMP_Settings.cfg]. No need to add another."
    else
        if grep -q '^\[include macros\.cfg\]' "$working_cfg"; then
            sed -i '/\[include macros\.cfg\]/a\[include KAMP_Settings.cfg]' "$working_cfg"
            echo "Added [include KAMP_Settings.cfg] after [include macros.cfg]"
        else
            sed -i '1i[include KAMP_Settings.cfg]\n' "$working_cfg"
            echo "Added [include KAMP_Settings.cfg] to the top of printer.cfg"
        fi
    fi

    mv "$working_cfg" "$printer_cfg"
    echo "Updated printer.cfg with KAMP include"
}

# Function to add firmware retraction to printer.cfg
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
unretract_speed: 10
#   The speed of unretraction, in mm/s. The default is 10 mm/s.
"

    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        echo "You will need to manually add the firmware retraction block to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "$working_cfg"
    echo "Created backup of printer.cfg at ${working_cfg}"

    if grep -q '^\[firmware_retraction\]' "$working_cfg"; then
        echo "Firmware retraction section already exists. Skipping addition."
        mv "$working_cfg" "$printer_cfg"
        return
    fi

    local save_config_line=$(grep -n '^\[save_config\]' "$working_cfg" | cut -d: -f1 | head -n 1)
    if [ -n "$save_config_line" ]; then
        # Insert firmware retraction just before [save_config]
        awk -v block="$firmware_retraction_block" -v line="$save_config_line" '
            NR==line {print block}
            {print}
        ' "$working_cfg" > "${working_cfg}.new"
        mv "${working_cfg}.new" "$printer_cfg"
        echo "Added firmware retraction above [save_config] in printer.cfg"
    else
        # No [save_config] found, append to end
        echo "$firmware_retraction_block" >> "$working_cfg"
        mv "$working_cfg" "$printer_cfg"
        echo "Appended firmware retraction to end of printer.cfg"
    fi
}

# Declare global array for backup files
declare -a BACKUP_FILES

# Main installation/uninstallation logic
verify_ready
check_klipper
check_folders
create_backup_dir
stop_klipper
get_user_macro_files

if [ ! $UNINSTALL ]; then
    echo "Installing SV08 Replacement Macros..."
    backup_existing_macros
    install_macros
    check_and_update_printer_cfg
    install_web_interface_config
    add_force_move
    start_klipper
    echo "Installation complete! Please check your printer's web interface to verify the changes."

    echo ""
    echo "Would you like to install A Better Print_Start Macro?"
    echo "Note: This will also install KAMP, which needs to be configured per KAMP documentation."
    echo "More information can be found at: https://github.com/ss1gohan13/A-better-print_start-macro"
    read -p "Install Print_Start macro and KAMP? (y/N): " install_print_start
    
    if [[ "$install_print_start" =~ ^[Yy]$ ]]; then
        echo "Installing KAMP and A Better Print_Start Macro..."
        install_kamp
        curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-better-print_start-macro/main/install_start_print.sh | bash
        add_kamp_include_to_printer_cfg
        # Add max cross extrude to extruder section here if needed
        # ----YOUR EXISTING EXTRUDER PATCH LOGIC HERE----
        add_firmware_retraction_to_printer_cfg
        echo ""
        echo "Print_Start macro and KAMP have been installed!"
        echo "Please visit https://github.com/ss1gohan13/A-better-print_start-macro for instructions on configuring your slicer settings."
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
        echo "End Print macro has been installed!"
        echo "Please visit https://github.com/ss1gohan13/A-Better-End-Print-Macro for instructions on configuring your slicer settings."
    fi
else
    echo "Uninstalling SV08 Replacement Macros..."
    restore_backup
    start_klipper
    echo "Uninstallation complete! Original configuration has been restored."
fi
