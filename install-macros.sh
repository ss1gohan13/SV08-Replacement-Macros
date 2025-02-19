#!/bin/bash
# Force script to exit if an error occurs
set -e

# Script Info
# Last Updated: 2025-02-19 03:57:59 UTC
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
    "printer-*.cfg"
    "printer_*.cfg"
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
            echo "Creating backup of existing ${file##*/}..."
            cp "$file" "${BACKUP_DIR}/${file##*/}.backup_${CURRENT_DATE}"
            echo "Backup created at ${BACKUP_DIR}/${file##*/}.backup_${CURRENT_DATE}"
            found_macro=1
        done < <(find "$KLIPPER_CONFIG" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
    done

    if [ $found_macro -eq 1 ]; then
        echo "All existing macro configurations have been backed up."
    fi
}

# Install new macros.cfg
install_macros() {
    echo -n "Installing new macros.cfg... "
    cp "${SRCDIR}/printer_data/config/macros.cfg" "${KLIPPER_CONFIG}/macros.cfg"
    echo "[OK]"
}

# Enhanced check and update printer.cfg to include macros
check_and_update_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [ ! -f "$printer_cfg" ]; then
        echo "[WARNING] printer.cfg not found at ${printer_cfg}"
        echo "You will need to manually add: [include macros.cfg] to your printer.cfg"
        return
    }

    # More comprehensive check for existing includes
    local include_found=0
    
    # Check for various possible include formats
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
        if [[ "$line_lower" == "[include macros.cfg]" ]] || \
           [[ "$line_lower" == "[include "./macros.cfg"]" ]] || \
           [[ "$line_lower" == "[include \"macros.cfg\"]" ]] || \
           [[ "$line_lower" == "[include 'macros.cfg']" ]]; then
            include_found=1
            echo "Found existing include for macros.cfg in printer.cfg:"
            echo "  $line"
            break
        fi
    done < "$printer_cfg"

    if [ $include_found -eq 0 ]; then
        # Create backup of printer.cfg
        cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
        echo "Created backup of printer.cfg at ${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"

        # Add include line to printer.cfg
        echo "" >> "$printer_cfg"  # Add blank line for readability
        echo "[include macros.cfg]" >> "$printer_cfg"
        echo "Added [include macros.cfg] to printer.cfg"
        
        # Verify the addition
        if grep -q "^\[include macros\.cfg\]" "$printer_cfg"; then
            echo "Successfully verified the include line was added"
        else
            echo "[WARNING] Failed to verify the include line. Please check printer.cfg manually"
        fi
    fi
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

    # Restore printer.cfg if it was modified
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    local printer_backup=$(ls -t ${BACKUP_DIR}/printer.cfg.backup_* 2>/dev/null | head -n1)
    if [ -n "$printer_backup" ]; then
        echo "Restoring printer.cfg from backup: $printer_backup"
        cp "$printer_backup" "$printer_cfg"
        echo "[OK]"
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
else
    echo "Uninstalling SV08 Replacement Macros..."
    restore_backup
    start_klipper
    echo "Uninstallation complete! Original configuration has been restored."
fi
