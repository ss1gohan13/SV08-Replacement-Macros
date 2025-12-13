# Diagnostic and troubleshooting tools for SV08 Replacement Macros Installer
# This module contains all diagnostic and system checking functions

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

# Check Klipper service status
check_klipper_status() {
    show_header
    echo -e "${BLUE}KLIPPER STATUS${NC}"
    
    echo "Checking Klipper service status..."
    sudo systemctl status $KLIPPER_SERVICE_NAME
    
    echo ""
    read -p "Press Enter to continue..." dummy
    diagnostics_menu
}

# View Klipper logs
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

# Verify installation configuration
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

# Run comprehensive system diagnostics
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
