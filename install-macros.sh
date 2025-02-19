#!/bin/bash
# Force script to exit if an error occurs
set -e

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

# Backup existing macros.cfg if it exists
backup_existing_macros() {
    if [ -f "${KLIPPER_CONFIG}/macros.cfg" ]; then
        echo "Creating backup of existing macros.cfg..."
        cp "${KLIPPER_CONFIG}/macros.cfg" "${BACKUP_DIR}/macros.cfg.backup_${CURRENT_DATE}"
        echo "Backup created at ${BACKUP_DIR}/macros.cfg.backup_${CURRENT_DATE}"
    fi
}

# Install new macros.cfg
install_macros() {
    echo -n "Installing new macros.cfg... "
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Add installation metadata as a comment
    echo "# Installed by: $CURRENT_USER" > "$TEMP_FILE"
    echo "# Installation Date: $INSTALL_DATE UTC" >> "$TEMP_FILE"
    echo "# Version: 1.0.0" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    
    # Add the PRINT_START macro
    cat >> "$TEMP_FILE" << 'EOF'
[gcode_macro PRINT_START]
gcode:
    {% set BED_TEMP = params.BED_TEMP|default(60)|float %}
    {% set EXTRUDER_TEMP = params.EXTRUDER_TEMP|default(200)|float %}
    {% set CHAMBER_TEMP = params.CHAMBER_TEMP|default(0)|float %}
    {% set Z_SIZE = params.Z_SIZE|default(0)|float %}
    {% set PROBE = params.PROBE|default(true)|lower %}

    # Reset the G-Code reference position to the current position
    G92.1

    # Clear any paused states in case the printer is in one
    CLEAR_PAUSE

    # Ensure all axes are homed
    G28

    # If probe is requested and not triggered, perform bed mesh calibration
    {% if PROBE == 'true' %}
        BED_MESH_CALIBRATE
    {% endif %}

    # Start bed heating
    M140 S{BED_TEMP}

    # Wait for bed to reach 90% of target temperature
    M190 S{BED_TEMP * 0.9}

    # Move to Z50 for nozzle heating
    G1 Z50 F240

    # Heat nozzle to target temperature
    M104 S{EXTRUDER_TEMP}

    # Wait for nozzle to reach temperature
    M109 S{EXTRUDER_TEMP}

    # Wait for bed to reach final target temperature
    M190 S{BED_TEMP}

    # If chamber temperature is specified, wait for it
    {% if CHAMBER_TEMP > 0 %}
        SET_CHAMBER_TEMP T={CHAMBER_TEMP}
        WAIT_CHAMBER_TEMP T={CHAMBER_TEMP} MARGIN=2
    {% endif %}

    # Home Z again to account for any thermal expansion
    G28 Z

    # Reset the G-Code reference position to the current position
    G92.1

    # Reset extruder
    G92 E0

    # Move Z to size if specified
    {% if Z_SIZE > 0 %}
        G1 Z{Z_SIZE} F240
    {% endif %}

    # Prime line
    G1 Y5 F3000                  ; go to Y5
    G1 Z0.3 F240                 ; go to Z0.3
    G1 X40 E25 F1500.0          ; intro line 1
    G1 X80 E25 F1500.0          ; intro line 2
    G92 E0                       ; reset extruder
    G1 Z2.0 F3000               ; move Z up
EOF

    # Copy the temporary file to final location
    cp "$TEMP_FILE" "${KLIPPER_CONFIG}/macros.cfg"
    rm "$TEMP_FILE"
    echo "[OK]"
}

# Check if include exists in printer.cfg
check_include() {
    if [ -f "${KLIPPER_CONFIG}/printer.cfg" ]; then
        if grep -q "^[include macros.cfg]" "${KLIPPER_CONFIG}/printer.cfg" || \
           grep -q "^\[include macros.cfg\]" "${KLIPPER_CONFIG}/printer.cfg"; then
            echo "Include statement for macros.cfg already exists in printer.cfg"
            return 0
        fi
        return 1
    else
        echo "[ERROR] printer.cfg not found at ${KLIPPER_CONFIG}/printer.cfg"
        exit -1
    fi
}

# Add include statement to printer.cfg
add_include() {
    if ! check_include; then
        echo "Adding include statement to printer.cfg..."
        echo -e "\n[include macros.cfg]" >> "${KLIPPER_CONFIG}/printer.cfg"
        echo "[OK] Added include statement"
    fi
}

# Remove include statement from printer.cfg
remove_include() {
    if [ -f "${KLIPPER_CONFIG}/printer.cfg" ]; then
        echo "Removing include statement from printer.cfg..."
        sed -i '/^\[include macros\.cfg\]/d' "${KLIPPER_CONFIG}/printer.cfg"
        echo "[OK] Removed include statement"
    fi
}

# Restore backup if it exists
restore_backup() {
    local latest_backup=$(ls -t ${BACKUP_DIR}/macros.cfg.backup_* 2>/dev/null | head -n1)
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
    echo "Installing Enhanced Print Start Macro..."
    backup_existing_macros
    install_macros
    add_include
    start_klipper
    echo "Installation complete! Please check your printer's web interface to verify the changes."
else
    echo "Uninstalling Enhanced Print Start Macro..."
    restore_backup
    remove_include
    start_klipper
    echo "Uninstallation complete! Original configuration has been restored."
fi
