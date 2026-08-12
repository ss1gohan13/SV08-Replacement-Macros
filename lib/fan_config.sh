# Fan configuration support for SV08 Replacement Macros Installer
#
# This module migrates known SV08 part-cooling fan layouts to the
# [fan_generic fan] layout required by the replacement M106/M107 macros.
# Unknown/custom layouts are handled interactively so the user can reuse an
# existing fan section, enter a pin manually, or skip the change.

# Return success when an exact Klipper section exists.
# Example: _fan_section_exists printer.cfg "fan_generic fan"
_fan_section_exists() {
    local cfg="$1"
    local wanted="$2"

    awk -v wanted="$wanted" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*\[/ {
            line = $0
            sub(/^[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            if (trim(line) == wanted) {
                found = 1
                exit
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$cfg"
}

# Read a setting from an exact Klipper section.
# Example: _fan_get_section_value printer.cfg "fan" "pin"
_fan_get_section_value() {
    local cfg="$1"
    local wanted="$2"
    local key="$3"

    awk -v wanted="$wanted" -v key="$key" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*\[/ {
            line = $0
            sub(/^[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            in_section = (trim(line) == wanted)
            next
        }
        in_section {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            if (line ~ "^[[:space:]]*" key "[[:space:]]*:") {
                sub("^[[:space:]]*" key "[[:space:]]*:[[:space:]]*", "", line)
                print trim(line)
                exit
            }
        }
    ' "$cfg"
}

# Rename one exact Klipper section while preserving indentation and any
# trailing inline comment on the header.
_fan_rename_section() {
    local cfg="$1"
    local old_name="$2"
    local new_name="$3"
    local tmp_file

    tmp_file=$(mktemp)

    awk -v old_name="$old_name" -v new_name="$new_name" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        {
            if ($0 ~ /^[[:space:]]*\[/) {
                original = $0
                name = original
                sub(/^[[:space:]]*\[/, "", name)
                sub(/\].*$/, "", name)

                if (trim(name) == old_name) {
                    match(original, /^[[:space:]]*/)
                    leading = substr(original, RSTART, RLENGTH)
                    close_pos = index(original, "]")
                    suffix = substr(original, close_pos + 1)
                    print leading "[" new_name "]" suffix
                    next
                }
            }
            print
        }
    ' "$cfg" > "$tmp_file"

    mv "$tmp_file" "$cfg"
}

# Remove one exact Klipper section and its body.
_fan_remove_section() {
    local cfg="$1"
    local wanted="$2"
    local tmp_file

    tmp_file=$(mktemp)

    awk -v wanted="$wanted" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*\[/ {
            line = $0
            sub(/^[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            name = trim(line)

            if (name == wanted) {
                skip = 1
                next
            }

            if (skip) {
                skip = 0
            }
        }
        !skip { print }
    ' "$cfg" > "$tmp_file"

    mv "$tmp_file" "$cfg"
}

# Return normalized active configuration lines for a section, excluding pin:.
# This is used to verify that stock fan0/fan1 control settings are compatible
# before combining the two physical outputs under one logical fan.
_fan_section_settings_signature() {
    local cfg="$1"
    local wanted="$2"

    awk -v wanted="$wanted" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*\[/ {
            line = $0
            sub(/^[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            in_section = (trim(line) == wanted)
            next
        }
        in_section {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            line = trim(line)

            if (line == "" || line ~ /^pin[[:space:]]*:/) {
                next
            }

            gsub(/[[:space:]]*:[[:space:]]*/, ":", line)
            print line
        }
    ' "$cfg" | sort
}

# Return active config lines from a section except pin:. These lines can be
# reused on a newly-created combined [fan_generic fan] section.
_fan_section_config_lines_without_pin() {
    local cfg="$1"
    local wanted="$2"

    awk -v wanted="$wanted" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*\[/ {
            line = $0
            sub(/^[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            in_section = (trim(line) == wanted)
            next
        }
        in_section {
            check = $0
            sub(/[[:space:]]*#.*/, "", check)
            check = trim(check)

            if (check == "" || check ~ /^pin[[:space:]]*:/) {
                next
            }

            print $0
        }
    ' "$cfg"
}

# Insert a prepared config block above Klipper's SAVE_CONFIG marker. If the
# marker does not exist, append the block to the end of the file.
_fan_insert_block_before_save_config() {
    local cfg="$1"
    local block_file="$2"
    local tmp_file
    local save_line

    tmp_file=$(mktemp)
    save_line=$(grep -nF '#*# <---------------------- SAVE_CONFIG' "$cfg" | head -n 1 | cut -d: -f1 || true)

    if [ -n "$save_line" ]; then
        {
            if [ "$save_line" -gt 1 ]; then
                head -n $((save_line - 1)) "$cfg"
            fi
            echo ""
            cat "$block_file"
            echo ""
            tail -n +"$save_line" "$cfg"
        } > "$tmp_file"
    else
        {
            cat "$cfg"
            echo ""
            cat "$block_file"
            echo ""
        } > "$tmp_file"
    fi

    mv "$tmp_file" "$cfg"
}

# Add pin: directly below an existing [fan_generic fan] header.
_fan_add_pin_to_target_section() {
    local cfg="$1"
    local pin="$2"
    local tmp_file

    tmp_file=$(mktemp)

    awk -v pin="$pin" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        {
            print

            if (!added && $0 ~ /^[[:space:]]*\[/) {
                line = $0
                sub(/^[[:space:]]*\[/, "", line)
                sub(/\].*$/, "", line)

                if (trim(line) == "fan_generic fan") {
                    print "pin: " pin
                    added = 1
                }
            }
        }
    ' "$cfg" > "$tmp_file"

    mv "$tmp_file" "$cfg"
}

# List existing standard/generic fan sections that have a pin configured.
# Output format: section-name<TAB>pin
_fan_list_candidate_sections() {
    local cfg="$1"

    awk '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        function emit() {
            if (candidate && section != "fan_generic fan" && pin != "") {
                print section "\t" pin
            }
        }
        /^[[:space:]]*\[/ {
            emit()

            line = $0
            sub(/^[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            section = trim(line)
            pin = ""
            candidate = (section == "fan" || section ~ /^fan_generic[[:space:]]+/)
            next
        }
        candidate {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)
            if (line ~ /^[[:space:]]*pin[[:space:]]*:/) {
                sub(/^[[:space:]]*pin[[:space:]]*:[[:space:]]*/, "", line)
                pin = trim(line)
            }
        }
        END { emit() }
    ' "$cfg"
}

# Show active config locations that already reference a physical or virtual pin.
# This checks both pin: and comma-separated pins: entries.
_fan_find_pin_references() {
    local cfg="$1"
    local wanted_pin="$2"

    awk -v wanted_pin="$wanted_pin" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            return s
        }
        /^[[:space:]]*\[/ {
            line = $0
            sub(/^[[:space:]]*\[/, "", line)
            sub(/\].*$/, "", line)
            section = trim(line)
            next
        }
        /^[[:space:]]*#/ { next }
        {
            line = $0
            sub(/[[:space:]]*#.*/, "", line)

            if (line ~ /^[[:space:]]*pin[[:space:]]*:/) {
                value = line
                sub(/^[[:space:]]*pin[[:space:]]*:[[:space:]]*/, "", value)
                if (trim(value) == wanted_pin) {
                    print "[" section "] -> pin: " trim(value)
                }
            } else if (line ~ /^[[:space:]]*pins[[:space:]]*:/) {
                value = line
                sub(/^[[:space:]]*pins[[:space:]]*:[[:space:]]*/, "", value)
                count = split(value, values, ",")
                for (i = 1; i <= count; i++) {
                    if (trim(values[i]) == wanted_pin) {
                        print "[" section "] -> pins: " trim(values[i])
                    }
                }
            }
        }
    ' "$cfg"
}

# Ask for a manual pin and create/repair [fan_generic fan].
# Mode is either "add" or "repair".
_fan_prompt_manual_pin() {
    local cfg="$1"
    local mode="$2"
    local fan_pin
    local references
    local confirm
    local block_file

    while true; do
        echo ""
        read -r -p "Enter the Klipper pin for your part cooling fan (or 0 to go back): " fan_pin

        # Trim leading/trailing whitespace without restricting valid Klipper syntax.
        fan_pin=$(printf '%s' "$fan_pin" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ "$fan_pin" = "0" ]; then
            return 1
        fi

        if [ -z "$fan_pin" ]; then
            echo -e "${YELLOW}[WARNING] No pin was entered.${NC}"
            continue
        fi

        references=$(_fan_find_pin_references "$cfg" "$fan_pin")
        if [ -n "$references" ]; then
            echo ""
            echo -e "${YELLOW}[WARNING] The pin '${fan_pin}' is already referenced in this configuration:${NC}"
            echo "$references"
            echo ""
            echo "Adding the same pin to another active section may cause a Klipper"
            echo "'pin used multiple times' configuration error."
            read -r -p "Use this pin anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi

        echo ""
        if [ "$mode" = "repair" ]; then
            echo "The existing [fan_generic fan] section will be updated with:"
        else
            echo "The following configuration will be added:"
        fi
        echo ""
        echo "    [fan_generic fan]"
        echo "    pin: ${fan_pin}"
        echo ""
        read -r -p "Continue? (Y/n): " confirm

        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            continue
        fi

        if [ "$mode" = "repair" ]; then
            _fan_add_pin_to_target_section "$cfg" "$fan_pin"
        else
            block_file=$(mktemp)
            cat > "$block_file" <<BLOCK
# Part cooling fan
# Added by SV08 Replacement Macros
[fan_generic fan]
pin: ${fan_pin}
BLOCK
            _fan_insert_block_before_save_config "$cfg" "$block_file"
            rm -f "$block_file"
        fi

        echo -e "${GREEN}[OK] [fan_generic fan] configured with pin: ${fan_pin}${NC}"
        return 0
    done
}

# Convert the stock Sovol fan0/fan1 layout when both physical outputs and their
# control settings can be safely combined.
_fan_migrate_stock_dual_fans() {
    local cfg="$1"
    local fan0_pin
    local fan1_pin
    local fan0_signature
    local fan1_signature
    local block_file
    local settings_file

    fan0_pin=$(_fan_get_section_value "$cfg" "fan_generic fan0" "pin")
    fan1_pin=$(_fan_get_section_value "$cfg" "fan_generic fan1" "pin")

    if [ -z "$fan0_pin" ] || [ -z "$fan1_pin" ]; then
        echo -e "${YELLOW}[WARNING] Stock-style fan0/fan1 sections were found, but one or both pins are missing.${NC}"
        return 1
    fi

    # Do not overwrite an existing multi_pin section with the name we use.
    if _fan_section_exists "$cfg" "multi_pin print_cooling_fan_pins"; then
        echo -e "${YELLOW}[WARNING] fan0/fan1 were found, but [multi_pin print_cooling_fan_pins] already exists.${NC}"
        echo "Automatic stock fan migration was skipped to avoid overwriting a custom configuration."
        return 1
    fi

    fan0_signature=$(_fan_section_settings_signature "$cfg" "fan_generic fan0")
    fan1_signature=$(_fan_section_settings_signature "$cfg" "fan_generic fan1")

    if [ "$fan0_signature" != "$fan1_signature" ]; then
        echo -e "${YELLOW}[WARNING] fan0 and fan1 use different control settings.${NC}"
        echo "Automatic stock fan migration was skipped so custom fan behavior is not lost."
        return 1
    fi

    echo "Detected stock Sovol dual part-cooling fan layout:"
    echo "  fan0: ${fan0_pin}"
    echo "  fan1: ${fan1_pin}"
    echo "Combining both outputs under [fan_generic fan]..."

    settings_file=$(mktemp)
    _fan_section_config_lines_without_pin "$cfg" "fan_generic fan0" > "$settings_file"

    _fan_remove_section "$cfg" "fan_generic fan0"
    _fan_remove_section "$cfg" "fan_generic fan1"

    block_file=$(mktemp)
    {
        echo "# Combined SV08 part cooling fan outputs"
        echo "[multi_pin print_cooling_fan_pins]"
        echo "pins: ${fan0_pin}, ${fan1_pin}"
        echo ""
        echo "[fan_generic fan]"
        echo "pin: multi_pin:print_cooling_fan_pins"
        cat "$settings_file"
    } > "$block_file"

    _fan_insert_block_before_save_config "$cfg" "$block_file"

    rm -f "$settings_file" "$block_file"

    echo -e "${GREEN}[OK] Stock fan0/fan1 converted to [fan_generic fan].${NC}"
    return 0
}

# Interactive fallback for unknown/custom layouts.
_fan_prompt_custom_configuration() {
    local cfg="$1"
    local -a sections=()
    local -a pins=()
    local section
    local pin
    local choice
    local manual_option
    local skip_option
    local index
    local confirm

    while IFS=$'\t' read -r section pin; do
        [ -z "$section" ] && continue
        sections+=("$section")
        pins+=("$pin")
    done < <(_fan_list_candidate_sections "$cfg")

    while true; do
        echo ""
        echo -e "${YELLOW}The installer could not confidently identify a known SV08 part-cooling fan layout.${NC}"
        echo "SV08 Replacement Macros expects a part cooling fan named [fan_generic fan]."
        echo ""

        if [ ${#sections[@]} -gt 0 ]; then
            echo "Existing standard/generic fan sections were found:"
            echo ""
            for ((index = 0; index < ${#sections[@]}; index++)); do
                printf "  %d) [%s]\n" "$((index + 1))" "${sections[$index]}"
                printf "     pin: %s\n" "${pins[$index]}"
            done
            echo ""
            echo "Selecting one of these will rename that entire section to"
            echo "[fan_generic fan] and preserve its existing settings."
            echo ""
        else
            echo "No existing [fan] or [fan_generic ...] section with a pin was found."
            echo ""
        fi

        manual_option=$((${#sections[@]} + 1))
        skip_option=$((${#sections[@]} + 2))

        echo "  ${manual_option}) Enter a part-cooling fan pin manually"
        echo "  ${skip_option}) Skip fan configuration"
        echo ""
        read -r -p "Select an option: " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#sections[@]} ]; then
            index=$((choice - 1))
            section="${sections[$index]}"
            pin="${pins[$index]}"

            echo ""
            echo "Selected:"
            echo "    [${section}]"
            echo "    pin: ${pin}"
            echo ""
            read -r -p "Reuse this entire section as [fan_generic fan]? (Y/n): " confirm

            if [[ "$confirm" =~ ^[Nn]$ ]]; then
                continue
            fi

            _fan_rename_section "$cfg" "$section" "fan_generic fan"
            echo -e "${GREEN}[OK] [${section}] renamed to [fan_generic fan].${NC}"
            return 0

        elif [ "$choice" = "$manual_option" ]; then
            if _fan_prompt_manual_pin "$cfg" "add"; then
                return 0
            fi

        elif [ "$choice" = "$skip_option" ]; then
            echo ""
            echo -e "${YELLOW}[WARNING] Part cooling fan configuration was skipped.${NC}"
            echo "Before using the replacement M106/M107 macros, configure:"
            echo ""
            echo "    [fan_generic fan]"
            echo "    pin: <your part cooling fan pin>"
            return 0

        else
            echo -e "${YELLOW}[WARNING] Invalid selection.${NC}"
        fi
    done
}

# Public entry point.
configure_part_cooling_fan() {
    local cfg="$1"
    local target_pin
    local rappetor_pin
    local target_choice

    echo ""
    echo -e "${CYAN}Checking part cooling fan configuration...${NC}"

    if [ ! -f "$cfg" ]; then
        echo -e "${YELLOW}[WARNING] Fan configuration check skipped: ${cfg} was not found.${NC}"
        return 0
    fi

    # STATE 1: Already using the required target section.
    if _fan_section_exists "$cfg" "fan_generic fan"; then
        target_pin=$(_fan_get_section_value "$cfg" "fan_generic fan" "pin")

        if [ -n "$target_pin" ]; then
            echo -e "${GREEN}[OK] Found [fan_generic fan] using pin: ${target_pin}${NC}"
            echo "Part cooling fan configuration is already compatible."
            return 0
        fi

        echo -e "${YELLOW}[WARNING] Found [fan_generic fan], but it does not contain a pin setting.${NC}"
        echo "A pin is required before this fan can be used."

        while true; do
            echo ""
            echo "  1) Add the missing pin now"
            echo "  2) Skip fan configuration"
            echo ""
            read -r -p "Select an option: " target_choice

            case "$target_choice" in
                1)
                    if _fan_prompt_manual_pin "$cfg" "repair"; then
                        return 0
                    fi
                    ;;
                2)
                    echo -e "${YELLOW}[WARNING] Incomplete [fan_generic fan] section left unchanged.${NC}"
                    return 0
                    ;;
                *)
                    echo -e "${YELLOW}[WARNING] Invalid selection.${NC}"
                    ;;
            esac
        done
    fi

    # STATE 2: Rappetor/Mainline layout. Only rename [fan] when its own pin
    # specifically references the known print_cooling_fan_pins multi_pin.
    if _fan_section_exists "$cfg" "multi_pin print_cooling_fan_pins" && \
       _fan_section_exists "$cfg" "fan"; then
        rappetor_pin=$(_fan_get_section_value "$cfg" "fan" "pin")

        if [ "$rappetor_pin" = "multi_pin:print_cooling_fan_pins" ]; then
            echo "Detected Rappetor/Mainline part-cooling fan layout."
            _fan_rename_section "$cfg" "fan" "fan_generic fan"
            echo -e "${GREEN}[OK] [fan] converted to [fan_generic fan].${NC}"
            return 0
        fi
    fi

    # STATE 3: Stock Sovol dual fan0/fan1 layout.
    if _fan_section_exists "$cfg" "fan_generic fan0" && \
       _fan_section_exists "$cfg" "fan_generic fan1"; then
        if _fan_migrate_stock_dual_fans "$cfg"; then
            return 0
        fi
        echo "Falling back to interactive fan setup."
    fi

    # STATE 4: Unknown/custom configuration. Allow the user to reuse a whole
    # existing fan section, enter a pin manually, or skip the change.
    _fan_prompt_custom_configuration "$cfg"
    return 0
}
