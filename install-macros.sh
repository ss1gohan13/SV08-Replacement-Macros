#!/bin/bash
# SV08 Replacement Macros Installer - Modular Version
# This script manages the installation, configuration, and maintenance of SV08 replacement macros
#
# Author: ss1gohan13
# Version: 1.3.0
# Last Updated: 2025-12-13
#
# This is the main entry point for the modular installer.
# Core functionality is split into separate modules in the lib/ directory:
#   - lib/functions.sh: Core utility functions
#   - lib/installers.sh: Installation and update functions
#   - lib/menus.sh: Interactive menu system
#   - lib/hardware.sh: Hardware configuration utilities
#   - lib/diagnostics.sh: Diagnostic and troubleshooting tools

# Force script to exit if an error occurs
set -e

# ==============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
# ==============================================================================

# Version and metadata
VERSION="1.3.0"

# Path configuration
KLIPPER_CONFIG="${HOME}/printer_data/config"
KLIPPER_PATH="${HOME}/klipper"
KLIPPER_SERVICE_NAME=klipper
BACKUP_DIR="${KLIPPER_CONFIG}/backup"
CURRENT_DATE=$(date +%Y%m%d_%H%M%S)

# Operational modes
MENU_MODE=1      # Default to interactive menu mode
UNINSTALL=0      # Uninstall flag

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'     # No Color

# ==============================================================================
# COMMAND-LINE ARGUMENT PARSING
# ==============================================================================

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

# Update backup directory path in case custom config was specified
BACKUP_DIR="${KLIPPER_CONFIG}/backup"

# ==============================================================================
# MODULE LOADING
# ==============================================================================

# Determine script directory for relative module loading
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library modules
echo "Loading modular components..."
source "${SCRIPT_DIR}/lib/functions.sh"
source "${SCRIPT_DIR}/lib/installers.sh"
source "${SCRIPT_DIR}/lib/menus.sh"
source "${SCRIPT_DIR}/lib/hardware.sh"
source "${SCRIPT_DIR}/lib/diagnostics.sh"
echo "All modules loaded successfully."
echo ""

# ==============================================================================
# MAIN EXECUTION LOGIC
# ==============================================================================

# Verify script is not run as root
verify_ready

# Execute based on operational mode
if [ $UNINSTALL -eq 1 ]; then
    # Uninstall mode: restore from backup
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
    # Linear installation flow (non-interactive)
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
