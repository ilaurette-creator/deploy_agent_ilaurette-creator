#!/usr/bin/env bash
cd "$(dirname "$0")"  
folder=""
# Check if required tools are installed
check_tools() {
if command -v python3 >/dev/null; then
    echo "python3 is installed"
else 
    echo "python3 is not installed"
fi

if command -v zip >/dev/null; then
    echo "zip is installed"
else
    
    echo "zip is not installed"
fi
}

run_in_folder() {
    ( cd "$1" && python3 attendance_checker.py )
}

# Runs when the user presses Ctrl+C or Ctrl+Z during deployment
stop_deploy() {
    echo
    echo "Deployment was interrupted!"
    if [ -d "$folder" ]; then
        if zip -r "${folder}_archive.zip" "$folder" > /dev/null; then
            rm -rf "$folder"
            echo "The unfinished project was saved in ${folder}_archive.zip"
        else
            echo "Could not create the zip file."
        fi
    fi
    exit 130
}

deploy_app() {
    check_tools || return
    echo "Checks passed: python3 and zip are installed."

    read -p "Enter a name for the project (example: v1): " name
    if [[ ! $name =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "Error: use only letters, numbers, - and _"
        return
    fi
    folder="attendance_tracker_$name"

    for file in attendance_checker.py config.json assets.csv; do
        if [ ! -f "templates/$file" ]; then
            echo "Error: templates/$file is missing."
            return
        fi
    done

    if [ -d "$folder" ]; then
        read -p "$folder already exists. Overwrite it? (y/n): " answer
        if [ "$answer" != "y" ]; then
            echo "Cancelled."
            return
        fi
        rm -rf "$folder"
    fi

    trap stop_deploy SIGINT SIGTSTP

    mkdir -p "$folder/Helpers" "$folder/reports" "$folder/archives/attendance" "$folder/archives/absent"
    cp templates/attendance_checker.py "$folder/"
    cp templates/config.json "$folder/Helpers/"

    echo "1) Copy students from the template"
    echo "2) Create new students (all start at 0)"
    read -p "Choose 1 or 2: " choice

    if [ "$choice" = "1" ]; then
        read -p "How many students to copy (1-10)? " count
        if [[ ! $count =~ ^[1-9][0-9]*$ ]]; then
            count=10
        fi
        head -n 1 templates/assets.csv > "$folder/Helpers/assets.csv"
        tail -n +2 templates/assets.csv | head -n "$count" >> "$folder/Helpers/assets.csv"
    else
        read -p "How many new students? " count
        if [[ ! $count =~ ^[1-9][0-9]*$ ]]; then
            count=5
        fi
        names=("Alex Rivera" "Beatriz Santos" "Chen Wei" "David Okon" "Elena Rostova" "Farhan Ali" "Grace Hopper" "Hassan Mahmoud" "Isabella Cruz" "Joseph Kim")
        emails=(alex beatriz chen david elena farhan grace hassan isabella joseph)

        echo "Email,Names,Attendance Count,Absence Count" > "$folder/Helpers/assets.csv"
        for ((i = 0; i < count; i++)); do
            n=$((i % 10))
            echo "$((i + 1))_${emails[$n]}@example.com,${names[$n]},0,0" >> "$folder/Helpers/assets.csv"
        done
        sed -i "s/\"total_sessions\": [0-9]*/\"total_sessions\": 1/" "$folder/Helpers/config.json"
    fi

    chmod +x "$folder/attendance_checker.py"
    chmod 600 "$folder/Helpers/config.json"
    echo "Permissions set:"
    echo "  attendance_checker.py -> executable"
    echo "  config.json -> owner read/write only"

    read -p "Update the alert thresholds? (y/n): " answer
    if [ "$answer" = "y" ]; then
        read -p "Warning threshold [75]: " warn
        read -p "Failure threshold [50]: " fail
        warn=${warn:-75}
        fail=${fail:-50}
        if [[ $warn =~ ^[0-9]+$ && $fail =~ ^[0-9]+$ ]]; then
            sed -i "s/\"warning\": [0-9]*/\"warning\": $warn/" "$folder/Helpers/config.json"
            sed -i "s/\"failure\": [0-9]*/\"failure\": $fail/" "$folder/Helpers/config.json"
            echo "Thresholds updated."
        else
            echo "Invalid numbers. Thresholds were not changed."
        fi
    fi

    trap - SIGINT SIGTSTP
    echo "Deployment finished. Starting the application to test it..."
    run_in_folder "$folder"
}

run_app() {
    check_tools || return
    read -p "Enter the project name (example: v1): " name
    folder="attendance_tracker_$name"
    if [ ! -f "$folder/attendance_checker.py" ]; then
        echo "Error: $folder was not found."
        return
    fi
    run_in_folder "$folder"
}

archive_logs() {
    read -p "Enter the project name (example: v1): " name
    folder="attendance_tracker_$name"
    if [ ! -d "$folder" ]; then
        echo "Error: $folder was not found."
        return
    fi

    stamp=$(date +%Y%m%d_%H%M%S)
    for kind in attendance absent; do
        log="$folder/reports/$kind.log"
        if [ -f "$log" ]; then
            cp "$log" "$folder/archives/$kind/${kind}_$stamp.log"
            echo "Archived: $folder/archives/$kind/${kind}_$stamp.log"
        else
            echo "No $kind.log found. Skipped."
        fi
    done
}

while true; do
    echo
    echo "===== Attendance Tracker Menu ====="
    echo "1) Deploy the application"
    echo "2) Run the application"
    echo "3) Archive the log files"
    echo "4) Exit"
    read -p "Choose 1-4: " option || exit 0

    case "$option" in
        1) deploy_app ;;
        2) run_app ;;
        3) archive_logs ;;
        4) echo "Goodbye!"; exit 0 ;;
        *) echo "Please choose 1, 2, 3 or 4." ;;
    esac
done

