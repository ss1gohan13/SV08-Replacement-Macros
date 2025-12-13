# Core utility functions for SV08 Replacement Macros Installer
# This module contains shared utility functions used across all other modules

# Verify script is not run as root
verify_ready() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}[ERROR] This script must not run as root${NC}"
        exit -1
    fi
}

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

# Display script header with version
show_header() {
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}    SV08 Replacement Macros Installer v${VERSION}${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${YELLOW}Author: ss1gohan13${NC}"
    echo -e "${YELLOW}Last Updated: 2025-12-13${NC}"
    echo ""
}
