#!/usr/bin/env bash
CURRENT_DEPLOY_DIR=""

check_dependencies() {
    local missing=0

if command -v python3 >/dev/null; then
    echo "python3 is  installed $(python3 --version)"
else 
    echo "python3 is not installed"
fi

if command -v zip >/dev/null; then
    echo "zip is installed$(zip -v |head -n 2 |tail -n 1)"
else
    
    echo "zip is not installed"
fi

}

# ------------------------------------------------------------------------------
# Signal Trap Handler (Ctrl+C / SIGINT & Ctrl+Z / SIGTSTP)
# ------------------------------------------------------------------------------
handle_interrupt() {
    echo -e "\n\n[!] Deployment process interrupted by signal (Ctrl+C / Ctrl+Z)!"
    if [ -n "$CURRENT_DEPLOY_DIR" ] && [ -d "$CURRENT_DEPLOY_DIR" ]; then
        ARCHIVE_NAME="${CURRENT_DEPLOY_DIR}_archive.zip"
        echo "[*] Archiving incomplete deployment folder '$CURRENT_DEPLOY_DIR'..."
        
        # Compress incomplete directory into .zip archive
        zip -r "$ARCHIVE_NAME" "$CURRENT_DEPLOY_DIR" > /dev/null 2>&1
        echo "[+] Incomplete deployment successfully zipped into: $ARCHIVE_NAME"
    else
        echo "[*] No active deployment directory to archive."
    fi
    echo "[*] Exiting cleanly."
    exit 130
}

# ------------------------------------------------------------------------------
# Feature 1: Deploy Application
# ------------------------------------------------------------------------------
deploy_app() {
    check_dependencies
    
    # Enable signal trap during deployment phase
    trap 'handle_interrupt' SIGINT SIGTSTP

    echo -e "\n========================================="
    echo "       FEATURE 1: DEPLOY APPLICATION      "
    echo "========================================="

    # Step A: Prompt for directory suffix
    read -p "Enter directory name: " DIR_INPUT
    if [ -z "$DIR_INPUT" ]; then
        DIR_INPUT="v1"
        echo "[*] Defaulting suffix to 'v1'"
    fi

    TARGET_DIR="attendance_tracker_${DIR_INPUT}"
    CURRENT_DEPLOY_DIR="$TARGET_DIR"

    # Overwrite safety check
    if [ -d "$TARGET_DIR" ]; then
        echo -e "\n[!] Warning: Directory '$TARGET_DIR' already exists."
        read -rp "Do you want to overwrite it? (y/N): " OVERWRITE_CHOICE
        case "$OVERWRITE_CHOICE" in
            [yY][eE][sS]|[yY])
                echo "[*] Overwriting existing directory '$TARGET_DIR'..."
                rm -rf "$TARGET_DIR"
                ;;
            *)
                echo "[*] Deployment aborted by user."
                trap - SIGINT SIGTSTP
                CURRENT_DEPLOY_DIR=""
                return
                ;;
        esac
    fi

    # Step B: Construct Directory Structure
    echo "[*] Creating project directory structure..."
    mkdir -p "$TARGET_DIR/Helpers"
    mkdir -p "$TARGET_DIR/reports"
    mkdir -p "$TARGET_DIR/archives/attendance"
    mkdir -p "$TARGET_DIR/archives/absent"

    # Check for template files
    if [ ! -f "templates/attendance_checker.py" ] || [ ! -f "templates/config.json" ] || [ ! -f "templates/assets.csv" ]; then
        echo "Error: Required template files missing in 'templates/' directory." >&2
        rm -rf "$TARGET_DIR"
        trap - SIGINT SIGTSTP
        CURRENT_DEPLOY_DIR=""
        exit 1
    fi

    # Step C: Populate Files
    echo "[*] Deploying base code and default configuration..."
    cp "templates/attendance_checker.py" "$TARGET_DIR/attendance_checker.py"
    cp "templates/config.json" "$TARGET_DIR/Helpers/config.json"

    echo -e "\nSelect Roster Generation Path:"
    echo "  1) Option A: Copy roster from sample template (templates/assets.csv)"
    echo "  2) Option B: Generate fresh roster with 0 prior attendance/absence"
    read -rp "Enter choice (1 or 2): " ROSTER_OPTION

    if [ "$ROSTER_OPTION" -eq 1 ]; then
        read -rp "How many students to copy from template (1-10)? [Default 10]: " STUDENT_COUNT
        STUDENT_COUNT=${STUDENT_COUNT:-10}
        
        # Copy header + student rows
        head -n 1 "templates/assets.csv" > "$TARGET_DIR/Helpers/assets.csv"
        tail -n +2 "templates/assets.csv" | head -n "$STUDENT_COUNT" >> "$TARGET_DIR/Helpers/assets.csv"
        
        # Template roster has 4 prior sessions -> total_sessions: 5
        sed -i "s/\"total_sessions\": [1, 2, 4-7, 10-12]*/\"total_sessions\": 5/" "$TARGET_DIR/Helpers/config.json"
        echo "[+] Roster created with $STUDENT_COUNT student(s) from template. Config set to total_sessions=5."

    else
        read -rp "How many fresh students to generate? [Default 5]: " FRESH_COUNT
        FRESH_COUNT=${FRESH_COUNT:-5}

        echo "Email,Names,Attendance Count,Absence Count" > "$TARGET_DIR/Helpers/assets.csv"
        
        SAMPLE_NAMES=("Alex Rivera" "Beatriz Santos" "Chen Wei" "David Okon" "Elena Rostova" "Farhan Ali" "Grace Hopper" "Hassan Mahmoud" "Isabella Cruz" "Joseph Kim")
        SAMPLE_EMAILS=("alex@example.com" "beatriz@example.com" "chen@example.com" "david@example.com" "elena@example.com" "farhan@example.com" "grace@example.com" "hassan@example.com" "isabella@example.com" "joseph@example.com")

        for ((i=0; i<FRESH_COUNT; i++)); do
            idx=$((i % 10))
            name="${SAMPLE_NAMES[$idx]}"
            email="student$((i+1))_${SAMPLE_EMAILS[$idx]}"
            echo "$email,$name,0,0" >> "$TARGET_DIR/Helpers/assets.csv"
        done

        # Fresh roster -> total_sessions: 1
        sed -i "s/\"total_sessions\": [1, 2, 4-7, 10-12]*/\"total_sessions\": 1/" "$TARGET_DIR/Helpers/config.json"
        echo "[+] Fresh roster created with $FRESH_COUNT student(s). Config set to total_sessions=1."
    fi

    # Step D: File Permissions
    echo "[*] Enforcing security permissions..."
    chmod +x "$TARGET_DIR/attendance_checker.py"
    chmod 600 "$TARGET_DIR/Helpers/config.json"
    
    echo -e "\n[+] Permission Confirmation:"
    echo "    - $TARGET_DIR/attendance_checker.py -> Executable (chmod +x)"
    echo "    - $TARGET_DIR/Helpers/config.json    -> Owner Read/Write Only (chmod 600)"

    # Step E: Offer Threshold Updates
    echo -e "\nDefault Alert Thresholds in config.json: Warning = 75%, Failure = 50%"
    read -rp "Do you want to update attendance alert thresholds? (y/N): " UPDATE_THRESH
    if [[ "$UPDATE_THRESH" =~ ^[yY]([eE][sS])?$ ]]; then
        read -rp "Enter new Warning threshold (0-100) : " WARN_VAL
        read -rp "Enter new Failure threshold (0-100) : " FAIL_VAL
        WARN_VAL=${WARN_VAL:-75}
        FAIL_VAL=${FAIL_VAL:-50}

        sed -i "s/\"warning\": [1, 2, 4-7, 10-12]*/\"warning\": $WARN_VAL/" "$TARGET_DIR/Helpers/config.json"
        sed -i "s/\"failure\": [1, 2, 4-7, 10-12]*/\"failure\": $FAIL_VAL/" "$TARGET_DIR/Helpers/config.json"
        echo "[+] Updated thresholds in $TARGET_DIR/Helpers/config.json (Warning: $WARN_VAL%, Failure: $FAIL_VAL%)"
    fi

    # Disable signal trap on successful completion
    trap - SIGINT SIGTSTP
    CURRENT_DEPLOY_DIR=""

    echo -e "\n[+] Deployment successfully completed in '$TARGET_DIR'."

    # Step F: Verify deployment by running app
    echo -e "\n[*] Verifying deployment structure by launching application (Feature 2)..."
    run_app_in_dir "$TARGET_DIR"
}

# ------------------------------------------------------------------------------
# Feature 2: Run Application
# ------------------------------------------------------------------------------
run_app_in_dir() {
    local target="$TARGET_DIR"

    if [ -z "$target" ]; then
        read -rp "Enter deployed directory: " target
    fi

    if [ ! -d "$target" ]; then
        echo "Error: Directory '$target' does not exist." >&2
        return 1
    fi

    if [ ! -f "$target/attendance_checker.py" ]; then
        echo "Error: '$target/attendance_checker.py' not found." >&2
        return 1
    fi

    echo -e "\n========================================="
    echo "        FEATURE 2: RUN APPLICATION       "
    echo "========================================="
    echo "[*] Launching interactive Attendance Tracker in '$target'..."

    (
        cd "$target" || exit 1
        python3 attendance_checker.py
    )
}

run_app() {
    run_app_in_dir ""
}

# ------------------------------------------------------------------------------
# Feature 3: Archive Log Files
# ------------------------------------------------------------------------------
archive_logs() {
    echo -e "\n========================================="
    echo "       FEATURE 3: ARCHIVE LOG FILES       "
    echo "========================================="

    read -rp "Enter deployed project directory name (e.g., attendance_tracker_v1): " LOG_DIR

    if [ ! -d "$LOG_DIR" ]; then
        echo "Error: Directory '$LOG_DIR' does not exist." >&2
        return 1
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    ATT_LOG="$LOG_DIR/reports/attendance.log"
    ABS_LOG="$LOG_DIR/reports/absent.log"

    ATT_ARCHIVE_DIR="$LOG_DIR/archives/attendance"
    ABS_ARCHIVE_DIR="$LOG_DIR/archives/absent"

    mkdir -p "$ATT_ARCHIVE_DIR"
    mkdir -p "$ABS_ARCHIVE_DIR"

    archived_any=0

    # Archive attendance log
    if [ -f "$ATT_LOG" ]; then
        DEST_ATT="$ATT_ARCHIVE_DIR/attendance_${TIMESTAMP}.log"
        cp "$ATT_LOG" "$DEST_ATT"
        echo "[+] Archived attendance log:"
        echo "    Source: $ATT_LOG"
        echo "    Target: $DEST_ATT"
        archived_any=1
    else
        echo "[!] Notice: '$ATT_LOG' does not exist. Skipping attendance log archive."
    fi

    # Archive absent log
    if [ -f "$ABS_LOG" ]; then
        DEST_ABS="$ABS_ARCHIVE_DIR/absent_${TIMESTAMP}.log"
        cp "$ABS_LOG" "$DEST_ABS"
        echo "[+] Archived absent log:"
        echo "    Source: $ABS_LOG"
        echo "    Target: $DEST_ABS"
        archived_any=1
    else
        echo "[!] Notice: '$ABS_LOG' does not exist. Skipping absent log archive."
    fi

    if [ "$archived_any" -eq 1 ]; then
        echo "[+] Log archiving operation completed successfully."
    else
        echo "[*] No operational logs found to archive in '$LOG_DIR/reports'."
    fi
}

# ------------------------------------------------------------------------------
# Interactive Menu Loop
# ------------------------------------------------------------------------------
show_menu() {
    while true; do
        echo -e "\n================================================="
        echo "  STUDENT ATTENDANCE TRACKER - DEPLOY AGENT MENU "
        echo "================================================="
        echo "  1) Feature 1: Deploy Application"
        echo "  2) Feature 2: Run Application"
        echo "  3) Feature 3: Archive Operational Logs"
        echo "  4) Exit"
        echo "================================================="
        read -rp "Select an option [1, 2, 3, 4]: " CHOICE

        case "$CHOICE" in
            1) deploy_app ;;
            2) run_app ;;
            3) archive_logs ;;
            4)
                echo "Exiting Deploy Agent. Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid selection. Please enter 1, 2, 3, or 4."
                ;;
        esac
    done
}


case "$1" in
    --deploy|-d)
        deploy_app
        ;;
    --run|-r)
        run_app
        ;;
    --archive|-a)
        archive_logs
        ;;
    *)
        show_menu
        ;;
esac
