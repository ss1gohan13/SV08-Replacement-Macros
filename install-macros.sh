#!/bin/bash
# Force script to exit if an error occurs
set -e

# Script Info
# Last Updated: 2025-04-27 18:52:18 UTC
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
        c) KLIPPER_CONFIG=$OPTARG;;
        s) KLIPPER_SERVICE_NAME=$OPTARG;;
        u) UNINSTALL=1;;
        h) usage;;
        ?) usage;;
    esac
done

# Find SRCDIR from the pathname of this script
SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Verify Klipper service exists
check_klipper() {
    if [ "$(sudo systemctl list-units --full -all -t service --no-legend | grep -F "$KLIPPER_SERVICE_NAME.service")" ]; then
        echo "Klipper service found with name \"$KLIPPER_SERVICE_NAME\"."
    else
        echo "[ERROR] Klipper service with name \"$KLIPPER_SERVICE_NAME\" not found, please install Klipper first or specify name with -s."
        exit -1
    fi
}

# Check if config directory exists
check_folders() {
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
    
    # Find files with names that might be macro files and display them
    find "$KLIPPER_CONFIG" -maxdepth 1 -type f -name "*.cfg" | sort | while read -r file; do
        # Skip backup files and timestamp-named files
        if [[ ! "$(basename "$file")" =~ (backup|[0-9]{8}_[0-9]{6})\.cfg$ ]]; then
            echo "  - $(basename "$file")"
        fi
    done
    
    echo ""
    echo "Please enter the filenames of your macro files (space separated)."
    echo "Example: macros.cfg sv08_macros.cfg custom_macros.cfg"
    echo "Press Enter if you have no existing macro files."
    read -p "> " USER_MACRO_FILES
    
    # Always reset to default for reliable downloading
    MACRO_FILES=("macros.cfg")
    
    if [ -n "$USER_MACRO_FILES" ]; then
        # User entered something - this is just for backups
        echo "Will back up the following files: $USER_MACRO_FILES"
        read -ra USER_FILES <<< "$USER_MACRO_FILES"
        
        # Backup the files the user mentioned, but always use macros.cfg as the target
        for file_name in "${USER_FILES[@]}"; do
            if [ -f "${KLIPPER_CONFIG}/${file_name}" ]; then
                echo "Will back up existing ${file_name}"
                # Add to backup list, but don't change the main target file
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
    
    # Check specifically for the main printer.cfg
    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        echo "You will need to manually add: [include macros.cfg] to your printer.cfg"
        return
    fi

    # Always create a backup of the main printer.cfg first
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    echo "Created backup of printer.cfg at ${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    
    # Use sed for direct file manipulation
    # First make a working copy
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    
    echo "Processing printer.cfg file..."
    
    # 1. Comment out existing lines with [include Macro.cfg]
    sed -i 's/^\[include Macro\.cfg\]/# [include Macro.cfg]/' "$working_cfg"
    
    # 2. Look for existing [include macros.cfg] 
    if grep -q '^\[include macros\.cfg\]' "$working_cfg"; then
        echo "Found existing [include macros.cfg]. No need to add another."
    else
        # 3. Add [include macros.cfg] at the top of the file
        sed -i '1i[include macros.cfg]\n' "$working_cfg"
        echo "Added [include macros.cfg] to the top of printer.cfg"
    fi
    
    # 4. Make sure we don't have any commented out [include macros.cfg] lines at the bottom
    # This is to fix the fourth bug where a commented include was appearing at the bottom
    sed -i 's/^# \[include macros\.cfg\]//' "$working_cfg"
    
    # 5. Replace the original file with our modified version
    mv "$working_cfg" "$printer_cfg"
    
    echo "Updated printer.cfg successfully"
}

# Function to install web interface configuration
install_web_interface_config() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    
    # Check if printer.cfg exists
    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        echo "You will need to manually add web interface configuration"
        return
    fi

    # Prompt user to select web interface
    echo ""
    echo "What web interface are you using?"
    echo "1) Fluidd"
    echo "2) Mainsail"
    read -p "Select an option (1/2): " web_interface_choice
    
    # Set the include directive based on user choice
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
    
    # Extract the filename from the include directive for string manipulation
    local config_file=$(echo "$include_directive" | sed -n 's/\[include \(.*\)\]/\1/p')
    
    # Create a working copy
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.webinterface_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.webinterface_${CURRENT_DATE}"
    
    echo "Processing printer.cfg for web interface configuration..."
    
    # Check if the include directive already exists
    if grep -q "^\[include ${config_file}\]" "$working_cfg"; then
        echo "Found existing ${include_directive}. No need to add another."
    else
        # Add the include directive after macros.cfg (if it exists) or at the top
        if grep -q '^\[include macros\.cfg\]' "$working_cfg"; then
            # Insert after macros.cfg
            sed -i "/\[include macros\.cfg\]/a\\${include_directive}" "$working_cfg"
            echo "Added ${include_directive} after [include macros.cfg]"
        else
            # Insert at the top
            sed -i "1i${include_directive}\n" "$working_cfg"
            echo "Added ${include_directive} to the top of printer.cfg"
        fi
    fi
    
    # Remove any commented versions of the include directive
    sed -i "s/^# \[include ${config_file}\]//" "$working_cfg"
    
    # Replace the original file with the modified version
    mv "$working_cfg" "$printer_cfg"
    
    echo "Updated printer.cfg with web interface configuration"
}

# Function to add force_move section to printer.cfg
add_force_move() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    
    # Check if printer.cfg exists
    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        return
    fi

    # Create a working copy
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    
    # Check if force_move section already exists
    if grep -q '^\[force_move\]' "$working_cfg"; then
        # If it exists, check if enable_force_move is set to true
        if grep -q '^\[force_move\]' -A 2 "$working_cfg" | grep -q 'enable_force_move: true'; then
            # Already properly configured, no changes needed
            rm "$working_cfg"
            return
        else
            # Force_move section exists but enable_force_move is not set to true
            # Update the existing section
            sed -i '/^\[force_move\]/,/^$/s/enable_force_move:.*$/enable_force_move: true/' "$working_cfg"
            if ! grep -q 'enable_force_move: true' "$working_cfg"; then
                # If the parameter wasn't found to update, add it to the section
                sed -i '/^\[force_move\]/a enable_force_move: true' "$working_cfg"
            fi
        fi
    else
        # force_move section doesn't exist, add it to the end of the file
        echo -e "\n[force_move]\nenable_force_move: true\n" >> "$working_cfg"
    fi
    
    # Replace the original file with the modified version
    mv "$working_cfg" "$printer_cfg"
}

# Modified to restore latest backup of specified macro files
restore_backup() {
    # Always try to restore macros.cfg
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
    
    # Also restore any additional files specified by the user
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

    # Restore only the main printer.cfg if it was modified
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    # Only restore if it's not a timestamped version
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

    # Prompt for Print_Start macro installation
    echo ""
    echo "Would you like to install A Better Print_Start Macro?"
    echo "Note: This will also install KAMP, which needs to be configured per KAMP documentation."
    echo "More information can be found at: https://github.com/ss1gohan13/A-better-print_start-macro"
    read -p "Install Print_Start macro and KAMP? (y/N): " install_print_start
    
    if [[ "$install_print_start" =~ ^[Yy]$ ]]; then
        echo "Installing KAMP and A Better Print_Start Macro..."
        install_kamp # Ensure KAMP is installed before the macro
        curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-better-print_start-macro/main/install_start_print.sh | bash
        echo ""
        echo "Print_Start macro and KAMP have been installed!"
        echo "Please visit https://github.com/ss1gohan13/A-better-print_start-macro for instructions on configuring your slicer settings."
    fi

    # Prompt for End Print macro installation
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
