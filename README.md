# Student Attendance Tracker - Deploy Agent

DEPLOY_AGENT.SH is a script that sets up the Student Attendance Tracker for you, runs it, and saves its log files.

## What the script can do


 1) Deploy the application-------> Creates a new project folder with everything inside it, then starts the app to check that it works 
 2) Run the application------> Starts the attendance tracker in a project you already deployed 
 3) Archive the log files------> Saves a dated copy of the attendance and absent logs 
 4) Exit------>  Closes the script 

## What you need first

- A Linux terminal
- python3 installed
- zip installed

The script checks for python3 and zip by itself. If one is missing, it tells you and stops.

## Before you start: the folder

Put these in the same folder:


my_project/
├── deploy_agent.sh
└── templates/
    ├── attendance_checker.py
    ├── config.json
    └── assets.csv

## Step 1: Start the script

Open the terminal, go into your folder, and run the script:

```bash
cd my_project
bash deploy_agent.sh
```

A menu appears. Type a number (1 to 4) and press Enter.

## Step 2: Deploy the application (choice 1)

The script asks you some questions. Type your answer and press Enter each time.

1. **Project name.** Type a name such as `v1`. The script creates a folder called `attendance_tracker_v1`. Use only letters, numbers, `-` and `_`.
2. **Folder already exists?** If the folder is already there, the script asks if you want to overwrite it. Type `y` for yes, or anything else to cancel.
3. **Student list.** Choose how to build the class list:
   - **1** copies students from the sample list in `templates/assets.csv`. You say how many (1 to 10).
   - **2** creates new students with 0 attendance and 0 absences. You say how many.
4. **Alert thresholds.** The defaults are Warning = 75% and Failure = 50%. Type `y` to change them, or `n` to keep them.
5. The script then starts the application so you can check that everything works.

### What gets created

```
attendance_tracker_v1/
├── attendance_checker.py     (the program)
├── Helpers/
│   ├── assets.csv            (the student list)
│   └── config.json           (the settings)
├── reports/                  (starts empty; the app creates the logs here)
└── archives/
    ├── attendance/           (saved attendance logs)
    └── absent/               (saved absent logs)
```

### File permissions

The script sets two permissions and prints a confirmation:

- `attendance_checker.py` can be run as a program (`chmod +x`)
- `config.json` can be read and edited only by you (`chmod 600`), because it holds the alert settings

### The `total_sessions` setting

`total_sessions` in `config.json` is the number of sessions including today's. It must always be one more than the sessions already recorded in the student list.

- **Option 1 (copy from template):** the sample students already have 4 sessions each, so `total_sessions` is **5**.
- **Option 2 (new students):** nobody has any sessions yet, so `total_sessions` is **1**. The script sets this for you.

## Step 3: Run the application (choice 2)

1. Choose **2** in the menu.
2. Type the project name (for example `v1`).
3. The app asks you to mark each student present or absent. Follow the questions on the screen.

The app updates the student list and writes the logs `reports/attendance.log` and `reports/absent.log`. If nobody was absent, `absent.log` may not exist. That is normal.

## Step 4: Archive the logs (choice 3)

1. Choose **3** in the menu.
2. Type the project name (for example `v1`).

The script copies each log into its own archive folder with the date and time in the name:

```
archives/attendance/attendance_20261013_143022.log
archives/absent/absent_20261013_143022.log
```

If a log does not exist, the script says so and skips it. It does not crash.

## What if I press Ctrl+C or Ctrl+Z while deploying?

The script stops safely. It prints a message, saves whatever was created so far into `attendance_tracker_v1_archive.zip`, removes the unfinished folder, and exits.

## Common problems

| Problem | What to do |
|---|---|
| `templates/attendance_checker.py is missing` | Make sure `deploy_agent.sh` and the `templates` folder are in the same folder, and the three files are inside `templates` |
| `python3 is not installed` or `zip is not installed` | Install the missing program, then run the script again |
| `Permission denied` when running `./deploy_agent.sh` | Run it with `bash deploy_agent.sh` instead |
| `The folder ... was not found` | Check the project name. Type only the part after `attendance_tracker_` (for example `v1`) |

LINK TO A RUN THROUGH VIDEO: https://youtu.be/yjI6oekJaT8
