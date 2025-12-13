# Installation functions for SV08 Replacement Macros Installer
# This module contains all installation, backup, and update functions

# Declare global array for backup files
declare -a BACKUP_FILES

# Interactive macro file detection
get_user_macro_files() {
    echo "Looking for macro files in $KLIPPER_CONFIG..."
    echo "Found these potential macro files:"
    find "$KLIPPER_CONFIG" -maxdepth 1 -type f -name "*.cfg" | sort | while read -r file; do
        if [[ ! "$(basename "$file")" =~ (backup|[0-9]{8}_[0-9]{6})\.cfg$ ]]; then
            echo "  - $(basename "$file")"
        fi
    done

    echo ""
    read -p "Do you have a custom macro.cfg installed? (y/N): " has_custom_macro
    if [[ ! "$has_custom_macro" =~ ^[Yy]$ ]]; then
        echo "No custom macro.cfg detected. Will use default 'macros.cfg'."
        MACRO_FILES=("macros.cfg")
        echo "Will download new macros to: macros.cfg"
        return
    fi
    
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

# Backup existing macro configurations
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

# NEW FUNCTION: Install gcode_shell_command extension
install_gcode_shell_command() {
    # Check if already installed
    if [ -f "${KLIPPER_PATH}/klippy/extras/gcode_shell_command.py" ]; then
        echo -e "${GREEN}gcode_shell_command already installed${NC}"
        return 0
    fi
    
    echo "Installing gcode_shell_command extension..."
    echo "This extension allows shell commands to be executed from Klipper macros."
    echo ""
    
    # Download the Python file directly from KIAUH repository
    if curl -fsSL -o "${KLIPPER_PATH}/klippy/extras/gcode_shell_command.py" \
        https://raw.githubusercontent.com/dw-0/kiauh/master/kiauh/extensions/gcode_shell_cmd/assets/gcode_shell_command.py; then
        echo -e "${GREEN}gcode_shell_command installed successfully!${NC}"
        echo "Extension ready - Klipper will load it on next restart."
        return 0
    else
        echo -e "${RED}Failed to install gcode_shell_command${NC}"
        echo "You may need to install it manually through KIAUH."
        return 1
    fi
}

# Download and install SV08 macros
install_macros() {
    echo "Downloading and installing new macros to macros.cfg..."
    curl -L https://raw.githubusercontent.com/ss1gohan13/SV08-Replacement-Macros/main/printer_data/config/macros.cfg -o "${KLIPPER_CONFIG}/macros.cfg"
    
    # Verify download was successful
    if [ -s "${KLIPPER_CONFIG}/macros.cfg" ]; then
        echo -e "${GREEN}[OK]${NC} Macros file downloaded successfully"
        echo "First few lines of downloaded file:"
        head -n 3 "${KLIPPER_CONFIG}/macros.cfg"
    else
        echo -e "${RED}[ERROR] Failed to download macros file. Please check your internet connection.${NC}"
        exit 1
    fi
    
    # AUTO-INSTALL gcode_shell_command (required dependency)
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Installing Required Dependency: gcode_shell_command${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo "Your macros include shell script commands that require the"
    echo "gcode_shell_command extension. Installing automatically..."
    echo ""
    install_gcode_shell_command
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
}

# Update printer.cfg with proper includes
check_and_update_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    
    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        echo "You will need to manually add: [include macros.cfg] to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    echo "Created backup of printer.cfg at ${BACKUP_DIR}/printer.cfg.backup_${CURRENT_DATE}"
    
    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.working_${CURRENT_DATE}"
    
    echo "Processing printer.cfg file..."

    # Comment out the hardcoded Macro.cfg (existing behavior)
    sed -i 's/^\[include Macro\.cfg\]/# [include Macro.cfg]/' "$working_cfg"
    
    # NEW: Comment out user-specified macro files
    if [ -n "$USER_MACRO_FILES" ]; then
        read -ra USER_FILES <<< "$USER_MACRO_FILES"
        for file_name in "${USER_FILES[@]}"; do
            # Remove any path and get just the filename
            base_name=$(basename "$file_name")
            # Escape dots for sed regex
            escaped_name=$(echo "$base_name" | sed 's/\./\\./g')
            # Comment out this include line
            sed -i "s/^\[include ${escaped_name}\]/# [include ${base_name}]/" "$working_cfg"
            echo "Commented out [include ${base_name}]"
        done
    fi
    
    # Also comment out any files in BACKUP_FILES array
    if [ -n "${BACKUP_FILES}" ]; then
        for file_name in "${BACKUP_FILES[@]}"; do
            # Remove any path and get just the filename
            base_name=$(basename "$file_name")
            # Skip if it's macros.cfg since we want that to remain active
            if [ "$base_name" != "macros.cfg" ]; then
                # Escape dots for sed regex
                escaped_name=$(echo "$base_name" | sed 's/\./\\./g')
                # Comment out this include line
                sed -i "s/^\[include ${escaped_name}\]/# [include ${base_name}]/" "$working_cfg"
                echo "Commented out [include ${base_name}]"
            fi
        done
    fi
    
    # Check if macros.cfg include already exists (existing behavior)
    if grep -q '^\[include macros\.cfg\]' "$working_cfg"; then
        echo "Found existing [include macros.cfg]. No need to add another."
    else
        sed -i '1i[include macros.cfg]\n' "$working_cfg"
        echo "Added [include macros.cfg] to the top of printer.cfg"
    fi

    # Remove any commented duplicate macros.cfg lines (existing behavior)
    sed -i 's/^# \[include macros\.cfg\]//' "$working_cfg"

    mv "$working_cfg" "$printer_cfg"
    echo "Updated printer.cfg successfully"
}

# Restore from backup
restore_backup() {
    local latest_macros_backup=$(ls -t ${BACKUP_DIR}/macros.cfg.backup_* 2>/dev/null | head -n1)
    if [ -n "$latest_macros_backup" ]; then
        echo "Restoring from backup: $latest_macros_backup"
        cp "$latest_macros_backup" "${KLIPPER_CONFIG}/macros.cfg"
        echo -e "${GREEN}[OK]${NC}"
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
                    echo -e "${GREEN}[OK]${NC}"
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
            echo -e "${GREEN}[OK]${NC}"
        fi
    fi
}

# Install web interface configuration
install_web_interface_config() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
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

# Install KAMP
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
    echo -e "${GREEN}KAMP installation complete!${NC}"
    
    # Automatically add firmware retraction after KAMP installation
    echo "Adding firmware retraction configuration..."
    add_firmware_retraction_to_printer_cfg
}

# Add firmware retraction to printer.cfg
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
unretract_speed: 60
#   The speed of unretraction, in mm/s. The default is 10 mm/s.
"

    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        echo "You will need to manually add the firmware retraction block to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "$working_cfg"
    echo "Created backup of printer.cfg at ${working_cfg}"

    if grep -q '^\[firmware_retraction\]' "$working_cfg"; then
        echo -e "${GREEN}Firmware retraction section already exists. Skipping addition.${NC}"
        rm "$working_cfg"
        return
    fi

    # Look for the SAVE_CONFIG comment marker instead of [save_config]
    local save_config_line=$(grep -n '#\*# <---------------------- SAVE_CONFIG ---------------------->' "$working_cfg" | cut -d: -f1 | head -n 1)
    
    if [ -n "$save_config_line" ]; then
        # Insert firmware retraction just before SAVE_CONFIG marker
        awk -v block="$firmware_retraction_block" -v line="$save_config_line" '
            NR==line {print block}
            {print}
        ' "$working_cfg" > "${working_cfg}.new"
        mv "${working_cfg}.new" "$printer_cfg"
        echo -e "${GREEN}Added firmware retraction above SAVE_CONFIG section in printer.cfg${NC}"
    else
        # No SAVE_CONFIG marker found, append to end
        echo "$firmware_retraction_block" >> "$working_cfg"
        mv "$working_cfg" "$printer_cfg"
        echo -e "${GREEN}Appended firmware retraction to end of printer.cfg${NC}"
    fi
}

# Add extruder settings to printer.cfg
add_extruder_settings_to_printer_cfg() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    local working_cfg="${BACKUP_DIR}/printer.cfg.extruder_settings_${CURRENT_DATE}"

    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        echo "You will need to manually add the extruder settings to your printer.cfg"
        return
    fi

    cp "$printer_cfg" "$working_cfg"
    echo "Created backup of printer.cfg at ${working_cfg}"

    # Check if extruder section exists
    if ! grep -q '^\[extruder\]' "$working_cfg"; then
        echo -e "${YELLOW}[WARNING] No [extruder] section found in printer.cfg${NC}"
        echo "You will need to manually add the extruder settings to your printer.cfg"
        rm "$working_cfg"
        return
    fi

    # Check if max_extrude_cross_section already exists
    if grep -q '^max_extrude_cross_section:' "$working_cfg"; then
        echo -e "${GREEN}Extruder settings already exist. Skipping addition.${NC}"
        rm "$working_cfg"
        return
    fi

    # Add the three extruder settings at the end of the [extruder] section
    awk '
        /^\[extruder\]/ { 
            extruder_section = 1
            print
            next
        }
        /^\[/ && extruder_section {
            # We found the start of the next section, add our settings before it
            print "max_extrude_cross_section: 10"
            print "max_extrude_only_distance: 500"
            print "max_extrude_only_velocity: 120"
            print ""
            extruder_section = 0
            print
            next
        }
        { print }
        END {
            # If we never found another section after [extruder], add settings at the end
            if (extruder_section) {
                print "max_extrude_cross_section: 10"
                print "max_extrude_only_distance: 500"
                print "max_extrude_only_velocity: 120"
            }
        }
    ' "$working_cfg" > "${working_cfg}.new"
    
    mv "${working_cfg}.new" "$printer_cfg"
    echo -e "${GREEN}Added extruder settings to printer.cfg${NC}"
    echo "Added: max_extrude_cross_section: 10"
    echo "Added: max_extrude_only_distance: 500"
    echo "Added: max_extrude_only_velocity: 120"
}

# Configure Eddy NG Tap
configure_eddy_ng_tap() {
    echo ""
    echo "Do you have Eddy NG installed?"
    echo "This will enable 'Tappy Tap' functionality, rapid bed mesh scanning, and enhanced gantry leveling."
    read -p "Enable Eddy NG features? (y/N): " enable_eddy_ng
    
    if [[ "$enable_eddy_ng" =~ ^[Yy]$ ]]; then
        echo "Enabling Eddy NG features in your configuration..."
        
        # Find the start print macro file
        local start_print_file="${KLIPPER_CONFIG}/print_start_macro.cfg"
        local macros_file="${KLIPPER_CONFIG}/macros.cfg"
        
        # --- Configure Start Print Macro ---
        if [ ! -f "$start_print_file" ]; then
            # Try to find the file that might contain the START_PRINT macro
            for potential_file in "${KLIPPER_CONFIG}"/*.cfg; do
                if grep -q "\[gcode_macro START_PRINT\]" "$potential_file"; then
                    start_print_file="$potential_file"
                    echo "Found START_PRINT macro in: $start_print_file"
                    break
                fi
            done
        fi
        
        if [ -f "$start_print_file" ]; then
            # Create a backup of the file
            cp "$start_print_file" "${BACKUP_DIR}/$(basename "$start_print_file").backup_${CURRENT_DATE}"
            
            # Uncomment the Eddy NG tapping lines
            sed -i 's/^#STATUS_CALIBRATING_Z/STATUS_CALIBRATING_Z/' "$start_print_file"
            sed -i 's/^#M117 Tappy Tap.../M117 Tappy Tap.../' "$start_print_file"
            sed -i 's/^#PROBE_EDDY_NG_TAP.*/PROBE_EDDY_NG_TAP/' "$start_print_file"
            
            # Uncomment the Method=rapid_scan for bed mesh
            sed -i 's/BED_MESH_CALIBRATE ADAPTIVE=1 #Method=rapid_scan/BED_MESH_CALIBRATE ADAPTIVE=1 Method=rapid_scan/' "$start_print_file"
            
            echo -e "${GREEN}Eddy NG tapping and rapid bed mesh scanning have been enabled in your start print macro.${NC}"
        else
            echo -e "${YELLOW}[WARNING] Could not find the START_PRINT macro file.${NC}"
            echo "You will need to manually uncomment the Eddy NG features in your start print macro."
        fi
        
        # --- Configure GANTRY_LEVELING Macro ---
        if [ -f "$macros_file" ]; then
            # Create a backup of the macros file
            cp "$macros_file" "${BACKUP_DIR}/macros.cfg.backup_eddy_${CURRENT_DATE}"
            
            # Uncomment retry_tolerance parameters for QGL and Z_TILT
            sed -i 's/QUAD_GANTRY_LEVEL horizontal_move_z=5 #retry_tolerance=1/QUAD_GANTRY_LEVEL horizontal_move_z=5 retry_tolerance=1/' "$macros_file"
            sed -i 's/Z_TILT_ADJUST horizontal_move_z=5 #RETRY_TOLERANCE=1/Z_TILT_ADJUST horizontal_move_z=5 RETRY_TOLERANCE=1/' "$macros_file"
            
            # Uncomment second pass fine adjustments
            sed -i 's/^#QUAD_GANTRY_LEVEL horizontal_move_z=2/QUAD_GANTRY_LEVEL horizontal_move_z=2/' "$macros_file"
            sed -i 's/^#Z_TILT_ADJUST horizontal_move_z=2/Z_TILT_ADJUST horizontal_move_z=2/' "$macros_file"
            
            # Also update G29 macro for rapid scanning
            sed -i 's/BED_MESH_CALIBRATE ADAPTIVE=1       # Method=rapid_scan/BED_MESH_CALIBRATE ADAPTIVE=1 Method=rapid_scan       #/' "$macros_file"
            
            echo -e "${GREEN}Eddy NG enhanced gantry leveling has been enabled in your GANTRY_LEVELING macro.${NC}"
            echo "Both QGL and Z_TILT configurations have been updated with retry_tolerance and fine adjustment passes."
        else
            echo -e "${YELLOW}[WARNING] Could not find macros.cfg file.${NC}"
            echo "You will need to manually uncomment the Eddy NG features in your gantry leveling macro."
        fi
        
        echo -e "${GREEN}All Eddy NG features have been enabled in your configuration.${NC}"
        
    else
        echo "Skipping Eddy NG features configuration."
    fi
}

# Add force_move section to printer.cfg
add_force_move() {
    local printer_cfg="${KLIPPER_CONFIG}/printer.cfg"
    if [ ! -f "$printer_cfg" ]; then
        echo -e "${YELLOW}[WARNING] printer.cfg not found at ${printer_cfg}${NC}"
        return
    fi

    cp "$printer_cfg" "${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    local working_cfg="${BACKUP_DIR}/printer.cfg.forcemove_${CURRENT_DATE}"
    
    if grep -q '^\[force_move\]' "$working_cfg"; then
        if grep -q '^\[force_move\]' -A 2 "$working_cfg" | grep -q 'enable_force_move: true'; then
            echo -e "${GREEN}Force move already enabled in printer.cfg${NC}"
            rm "$working_cfg"
            return
        else
            sed -i '/^\[force_move\]/,/^$/s/enable_force_move:.*$/enable_force_move: true/' "$working_cfg"
            if ! grep -q 'enable_force_move: true' "$working_cfg"; then
                sed -i '/^\[force_move\]/a enable_force_move: true' "$working_cfg"
            fi
            echo -e "${GREEN}Updated existing force_move section${NC}"
        fi
    else
        sed -i '1i[force_move]\nenable_force_move: true\n' "$working_cfg"
        echo -e "${GREEN}Added force_move section to printer.cfg${NC}"
    fi
    mv "$working_cfg" "$printer_cfg"
}

# Install Numpy for ADXL resonance measurements
install_numpy_for_adxl() {
    show_header
    echo -e "${BLUE}INSTALL NUMPY FOR ADXL RESONANCE MEASUREMENTS${NC}"
    
    echo "This will install numpy in the Klipper Python environment."
    echo "Numpy is required for processing ADXL345 accelerometer data for input shaping."
    echo "Reference: https://www.klipper3d.org/Measuring_Resonances.html"
    echo ""
    
    # Check if klippy-env exists
    if [ ! -d "${HOME}/klippy-env" ]; then
        echo -e "${RED}Error: Klipper Python environment not found at ~/klippy-env${NC}"
        echo "Please make sure Klipper is properly installed."
        return
    fi
    
    echo "Installing numpy (this may take a few minutes)..."
    ${HOME}/klippy-env/bin/pip install -v numpy
    
    # Verify installation
    if ${HOME}/klippy-env/bin/pip list | grep -q numpy; then
        echo -e "${GREEN}Numpy installed successfully!${NC}"
        echo "You can now use ADXL345-based resonance measurements with your printer."
        echo "For configuration instructions, see: https://www.klipper3d.org/Measuring_Resonances.html"
    else
        echo -e "${RED}Error: Failed to install numpy. Please try again or install manually.${NC}"
    fi
}

# Install KIAUH
install_kiauh() {
    show_header
    echo -e "${BLUE}INSTALL KIAUH${NC}"
    echo "Kiauh is the Klipper Installation And Update Helper"
    echo ""
    
    if [ -d "${HOME}/kiauh" ]; then
        echo "Kiauh is already installed."
        echo "1) Launch Kiauh"
        echo "2) Update Kiauh"
        echo "0) Back to software menu"
        
        read -p "Select option: " kiauh_option
        
        case $kiauh_option in
            1)
                cd ~/kiauh
                ./kiauh.sh
                ;;
            2)
                cd ~/kiauh
                git pull
                echo -e "${GREEN}Kiauh updated successfully!${NC}"
                ;;
            0)
                software_management_menu
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
    else
        echo "Installing Kiauh..."
        cd ~
        git clone https://github.com/th33xitus/kiauh.git
        
        if [ -d "${HOME}/kiauh" ]; then
            echo -e "${GREEN}Kiauh installed successfully!${NC}"
            echo "Would you like to launch Kiauh now?"
            read -p "(y/N): " launch_kiauh
            
            if [[ "$launch_kiauh" =~ ^[Yy]$ ]]; then
                cd ~/kiauh
                ./kiauh.sh
            fi
        else
            echo -e "${RED}Failed to install Kiauh. Please check your internet connection.${NC}"
        fi
    fi
    
    read -p "Press Enter to continue..." dummy
    software_management_menu
}

# Update macros
update_macros() {
    show_header
    echo -e "${BLUE}UPDATE SV08 MACROS${NC}"
    
    echo "This will update your SV08 macros to the latest version."
    echo "Your current macros will be backed up first."
    
    read -p "Continue with update? (y/N): " confirm_update
    
    if [[ "$confirm_update" =~ ^[Yy]$ ]]; then
        check_klipper
        create_backup_dir
        stop_klipper
        backup_existing_macros
        install_macros
        start_klipper
        
        echo -e "${GREEN}SV08 macros updated successfully!${NC}"
    else
        echo "Update cancelled."
    fi
    
    read -p "Press Enter to continue..." dummy
    software_management_menu
}

# Check for system updates
check_system_updates() {
    show_header
    echo -e "${BLUE}CHECK FOR SYSTEM UPDATES${NC}"
    
    echo "Checking for system updates..."
    sudo apt update
    
    echo -e "\n${CYAN}Available Updates:${NC}"
    apt list --upgradable
    
    echo ""
    read -p "Would you like to install available updates? (y/N): " install_updates
    
    if [[ "$install_updates" =~ ^[Yy]$ ]]; then
        echo "Installing updates... This may take a while."
        sudo apt upgrade -y
        echo -e "${GREEN}System updates complete!${NC}"
    else
        echo "Update installation cancelled."
    fi
    
    read -p "Press Enter to continue..." dummy
    software_management_menu
}
