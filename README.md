### Step-by-Step Explanation for Beginners

Here is what each part of the project does in simple terms:

1. **The Core Python App (`[suspicious link removed]`)**: This is the application that asks the teacher if a student is present or absent [6, 18]. It calculates their attendance percentage, warns if they are falling behind, and writes logs [14, 19, 20]. You do **not** edit this file [1].
2. **The Deployment Script (`[suspicious link removed]`)**: This is the master manager script you write [1]. Instead of manually creating folders and moving files, this script builds the entire project folder automatically in 2 seconds [3, 7].
3. **Permissions (`chmod`)**:
   * `chmod +x [suspicious link removed]` gives Linux permission to execute the Python script as a program [10].
   * `chmod 600 Helpers/config.json` locks the configuration file so only the file owner can read or write to it, protecting grade settings from unauthorized edits [10].
4. **Updating Thresholds (`sed`)**: `sed` is a stream editor in Linux that searches for text inside a file and replaces it directly (in-place) without opening a text editor [10].
5. **Archiving Logs**: Every time attendance is marked, log files are saved in `reports/` [4, 6]. Feature 3 copies those logs into `archives/` and adds the exact date and time (timestamp) to the file name so you have a permanent historical record [15].
6. **Signal Handling (`trap`)**: If someone cancels the setup midway by pressing `Ctrl+C`, `trap` intercepts that stop command, packs whatever folders were created into a `.zip` archive, and exits cleanly so your system stays tidy [16].
