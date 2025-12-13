# Menu system for SV08 Replacement Macros Installer
# This module contains all interactive menu functions

# Main menu
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

# Install core macros menu
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

# Additional features menu - WITH NEW GCODE_SHELL_COMMAND OPTION
additional_features_menu() {
    show_header
    echo -e "${BLUE}ADDITIONAL FEATURES & EXTENSIONS${NC}"
    echo "1) Install Print Start Macro"
    echo "2) Install End Print Macro"
    echo "3) Install KAMP"
    echo "4) Install gcode_shell_command extension"
    echo "5) Enable Eddy NG tap start print function"
    echo "6) Install Numpy for ADXL Resonance Measurements"
    echo "7) Install Crowsnest (webcam streaming)"
    echo "8) Install Moonraker-Timelapse"
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
        4)  # NEW CASE FOR GCODE_SHELL_COMMAND
            install_gcode_shell_command
            echo ""
            echo -e "${YELLOW}Note: Klipper must be restarted for the extension to take effect.${NC}"
            read -p "Restart Klipper now? (y/N): " restart_now
            if [[ "$restart_now" =~ ^[Yy]$ ]]; then
                stop_klipper
                start_klipper
                echo -e "${GREEN}Klipper restarted!${NC}"
            fi
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        5)  # Renumbered from 4
            check_klipper
            create_backup_dir
            stop_klipper
            configure_eddy_ng_tap
            start_klipper
            echo -e "${GREEN}Eddy NG tap start print function enabled successfully!${NC}"
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        6)  # Renumbered from 5
            install_numpy_for_adxl
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        7)  # Renumbered from 6
            echo "Installing Crowsnest..."
            cd ~
            git clone https://github.com/mainsail-crew/crowsnest.git
            cd crowsnest
            sudo bash ./tools/install.sh
            echo -e "${GREEN}Crowsnest installation complete!${NC}"
            read -p "Press Enter to continue..." dummy
            additional_features_menu
            ;;
        8)  # Renumbered from 7
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

# List all backups
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

# Restore from backup (interactive)
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

# Clean old backups
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
