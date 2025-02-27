#!/bin/bash
# Force script to exit if an error occurs
set -e

# Script Info
# Last Updated: 2025-02-19 16:19:46 UTC
# Author: ss1gohan13

KLIPPER_CONFIG="${HOME}/printer_data/config"
KLIPPER_SERVICE_NAME=klipper
BACKUP_DIR="${KLIPPER_CONFIG}/backup"
CURRENT_DATE=$(date +%Y%m%d_%H%M%S)

# Add macro patterns array with both hyphenated and underscore variations
MACRO_PATTERNS=(
    "macros.cfg"
    "*macro*.cfg"
    "*-macro*.cfg"
    "*_macro*.cfg"
    "macro-*.cfg"
    "macro_*.cfg"
    "custom-*.cfg"
    "custom_*.cfg"
    "sv08-*.cfg"
    "sv08_*.cfg"
    "sovol-*.cfg"
    "sovol_*.cfg"
)

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

# Modified to check for various macro file patterns
backup_existing_macros() {
    local found_macro=0
    for pattern in "${MACRO_PATTERNS[@]}"; do
        while IFS= read -r -d $'\0' file; do
            if [[ ! "$(basename "$file")" =~ [0-9]{8}_[0-9]{6}\.cfg$ ]]; then
                echo "Creating backup of existing ${file##*/}..."
                cp "$file" "${BACKUP_DIR}/${file##*/}.backup_${CURRENT_DATE}"
                echo "Backup created at ${BACKUP_DIR}/${file##*/}.backup_${CURRENT_DATE}"
                found_macro=1
            fi
        done < <(find "$KLIPPER_CONFIG" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
    done

    if [ $found_macro -eq 1 ]; then
        echo "All existing macro configurations have been backed up."
    fi
}

# Install new macros.cfg
install_macros() {
    echo -n "Downloading and installing new macros.cfg... "
    curl -o "${KLIPPER_CONFIG}/macros.cfg" "https://raw.githubusercontent.com/ss1gohan13/SV08-Replacement-Macros/main/printer_data/config/macros.cfg"
    echo "[OK]"
}

# Check and update printer.cfg to include macros
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

    # Check for various possible include formats
    local include_found=0
    local new_printer_cfg="${BACKUP_DIR}/printer.cfg.new_${CURRENT_DATE}"

    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # Skip if line is empty after trimming
        [ -z "$line" ] && continue
        
        # Skip commented lines
        [[ $line == \#* ]] && continue
        
        # Convert line to lowercase for case-insensitive comparison
        line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
        
        # Check for various include formats
        if [[ "$line_lower" == \[include* ]] && [[ "$line_lower" != "[include macros.cfg]" ]]; then
            echo "Removing old include: $line"
            continue
        fi

        # Write the line to the new printer.cfg
        echo "$line" >> "$new_printer_cfg"
    done < "$printer_cfg"

    if [ $include_found -eq 0 ]; then
        # Add include line to the top of the new printer.cfg
        echo "[include macros.cfg]" > "$new_printer_cfg"
        cat "$printer_cfg" >> "$new_printer_cfg"
        echo "Added [include macros.cfg] to the top of printer.cfg"
    fi

    # Replace the original printer.cfg with the new one
    mv "$new_printer_cfg" "$printer_cfg"
    echo "Updated printer.cfg to include macros.cfg"
}

# Modified to restore latest backup of any macro variant
restore_backup() {
    local latest_backup=$(ls -t ${BACKUP_DIR}/*macro*.cfg.backup_* 2>/dev/null | head -n1)
    if [ -n "$latest_backup" ]; then
        echo "Restoring from backup: $latest_backup"
        cp "$latest_backup" "${KLIPPER_CONFIG}/macros.cfg"
        echo "[OK]"
    else
        echo "No backup found to restore"
        if [ -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
            echo "Removing installed macros.cfg"
            rm "${KLIPPER_CONFIG}/macros.cfg"
        fi
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

# Main installation/uninstallation logic
verify_ready
check_klipper
check_folders
create_backup_dir
stop_klipper

if [ ! $UNINSTALL ]; then
    echo "Installing SV08 Replacement Macros..."
    backup_existing_macros
    install_macros
    check_and_update_printer_cfg
    start_klipper
    echo "Installation complete! Please check your printer's web interface to verify the changes."

    # Prompt for Print_Start macro installation
    echo ""
    echo "Would you like to install A Better Print_Start Macro?"
    echo "Note: This will also install KAMP, which needs to be configured per KAMP documentation."
    echo "More information can be found at: https://github.com/ss1gohan13/A-better-print_start-macro-SV08"
    read -p "Install Print_Start macro and KAMP? (y/N): " install_print_start
    
    if [[ "$install_print_start" =~ ^[Yy]$ ]]; then
        echo "Installing KAMP and A Better Print_Start Macro..."
        install_kamp # Ensure KAMP is installed before the macro
        curl -sSL https://raw.githubusercontent.com/ss1gohan13/A-better-print_start-macro-SV08/main/install_start_print.sh | bash
        echo ""
        echo "Print_Start macro and KAMP have been installed!"
        echo "Please visit https://github.com/ss1gohan13/A-better-print_start-macro-SV08 for instructions on configuring your slicer settings."
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
