# Add these new functions after the install_macros() function:

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

# Remove include statement from printer.cfg during uninstall
remove_include() {
    if [ -f "${KLIPPER_CONFIG}/printer.cfg" ]; then
        echo "Removing include statement from printer.cfg..."
        sed -i '/^\[include macros\.cfg\]/d' "${KLIPPER_CONFIG}/printer.cfg"
        echo "[OK] Removed include statement"
    fi
}

# Then modify the main installation/uninstallation logic section to use these functions:
if [ ! $UNINSTALL ]; then
    echo "Installing SV08 Replacement Macros..."
    backup_existing_macros
    install_macros
    add_include
    start_klipper
    echo "Installation complete! Please check your printer's web interface to verify the changes."
else
    echo "Uninstalling SV08 Replacement Macros..."
    restore_backup
    remove_include
    start_klipper
    echo "Uninstallation complete! Original configuration has been restored."
fi
