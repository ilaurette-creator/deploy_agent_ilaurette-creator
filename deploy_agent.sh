#!/usr/bin/env bash
# Signal Trap Handler (Ctrl+C / Ctrl+Z)
handle_interrupt() {
    echo -e "\n\n[!] Deployment interrupted by user signal (Ctrl+C / Ctrl+Z)!"
    if [ -n "$CURRENT_DEPLOY_DIR" ] && [ -d "$CURRENT_DEPLOY_DIR" ]; then
        ARCHIVE_NAME="${CURRENT_DEPLOY_DIR}_archive.zip"
        echo "[*] Archiving incomplete deployment folder '$CURRENT_DEPLOY_DIR'..."
        zip -r "$ARCHIVE_NAME" "$CURRENT_DEPLOY_DIR" > /dev/null
        echo " Incomplete deployment zipped to: $ARCHIVE_NAME"
    fi
    exit 130
}

# Feature 1: Deploy Application
deploy_app() {
    check_dependencies
    trap 'handle_interrupt' SIGINT SIGTSTP

    echo "========================================="
    echo "       FEATURE 1: DEPLOY APPLICATION      "
    echo "========================================="

    read -rp "Enter directory suffix/name: " DIR_INPUT
    DIR_INPUT=${DIR_INPUT:-v1}
    TARGET_DIR="attendance_tracker_${DIR_INPUT}"
    CURRENT_DEPLOY_DIR="$TARGET_DIR"

    if [ -d "$TARGET_DIR" ]; then
        read -rp "Directory '$TARGET_DIR' exists. Overwrite? (y/N): " OVERWRITE
        if [[ "$OVERWRITE" =~ ^[yY]$ ]]; then
            rm -rf "$TARGET_DIR"
        else
            echo "Deployment canceled."
            trap - SIGINT SIGTSTP
            return
        fi
    fi

    # Create directory structure
    mkdir -p "$TARGET_DIR/Helpers"
    mkdir -p "$TARGET_DIR/reports"
    mkdir -p "$TARGET_DIR/archives/attendance"
    mkdir -p "$TARGET_DIR/archives/absent"

    # Copy core application and config
    cp "templates/attendance_checker.py" "$TARGET_DIR/attendance_checker.py"
    cp "templates/config.json" "$TARGET_DIR/Helpers/config.json"

    echo "Select Roster Generation Option:"
    echo "  1) Option A: Copy from template (templates/assets.csv)"
    echo "  2) Option B: Generate fresh roster (0 attendance/absence)"
    read -rp "Choice (1 or 2): " ROSTER_OPT

    if [ "$ROSTER_OPT" -eq 1 ]; then
        read -rp "How many students from template (1-5)? [Default 5]: " COUNT
        COUNT=${COUNT:-5}
        head -n 1 "templates/assets.csv" > "$TARGET_DIR/Helpers/assets.csv"
        tail -n +2 "templates/assets.csv" | head -n "$COUNT" >> "$TARGET_DIR/Helpers/assets.csv"
        sed -i 's/"total_sessions":*/"total_sessions": 5/' "$TARGET_DIR/Helpers/config.json"
    else
        read -rp "How many fresh students to generate? [Default 3]: " COUNT
        COUNT=${COUNT:-3}
        echo "Email,Names,Attendance Count,Absence Count" > "$TARGET_DIR/Helpers/assets.csv"
        for ((i=1; i<=COUNT; i++)); do
            echo "student${i}@example.com,Student ${i},0,0" >> "$TARGET_DIR/Helpers/assets.csv"
        done
        sed -i 's/"total_sessions":*/"total_sessions": 1/' "$TARGET_DIR/Helpers/config.json"
    fi

    # Enforce Security Permissions
    chmod +x "$TARGET_DIR/attendance_checker.py"
    chmod 600 "$TARGET_DIR/Helpers/config.json"
    echo "[+] Set executable permissions (chmod +x) on attendance_checker.py"
    echo "[+] Restricted Helpers/config.json to owner access (chmod 600)"

    # Update Alert Thresholds via sed
    read -rp "Update alert thresholds? (y/N): " UPDATE_T
    if [[ "$UPDATE_T" =~ ^[yY]$ ]]; then
        read -rp "Enter Warning threshold (0-100) [75]: " WARN_V
        read -rp "Enter Failure threshold (0-100) [50]: " FAIL_V
        WARN_V=${WARN_V:-75}
        FAIL_V=${FAIL_V:-50}
        sed -i "s/\"warning\":*/\"warning\": $WARN_V/" "$TARGET_DIR/Helpers/config.json"
        sed -i "s/\"failure\":*/\"failure\": $FAIL_V/" "$TARGET_DIR/Helpers/config.json"
        echo "[+] Updated thresholds in config.json"
    fi

    trap - SIGINT SIGTSTP
    CURRENT_DEPLOY_DIR=""
    echo "[+] Deployment completed in '$TARGET_DIR'."
}
