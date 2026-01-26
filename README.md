# System Info Extractor

A comprehensive, interactive Bash script to gather and display system information on Linux.

## Features

This script provides an interactive menu to view various system details:

1.  **System Overview**: Hostname, uptime, OS info, kernel version, architecture, and logged-in users.
2.  **CPU & Memory**: CPU model, cores, frequency, memory usage, and top memory-consuming processes.
3.  **Storage & Filesystems**: Block devices, disk usage, and mounted filesystems.
4.  **Hardware Devices**: PCI and USB devices, input devices.
5.  **Network Information**: IP addresses, routing table, DNS config, listening ports, and Network Manager status.
6.  **Low-Level / Kernel Info**: Loaded modules, interrupts, and boot parameters.
7.  **Container Information**: Status of Docker and Podman containers.
8.  **Failed System Services**: List of failed systemd units.
9.  **Package Updates**: Check for available updates (supports dnf, apt, pacman).
10. **Generate Full Report**: Save all information to a text file.
11. **Export to JSON**: Export key metrics to a JSON file for programmatic use.
12. **Live Dashboard (TUI)**: A real-time, visual dashboard with CPU/RAM/Disk bars and network stats.
13. **Tech Glossary**: A built-in cheat sheet explaining common terms (GiB vs GB, x64, PID, etc.).

## Visual & Usability Improvements
-   **Dynamic Colors**: Dashboard bars change color (Green/Yellow/Red) based on usage.
-   **Readable Processes**: Process lists are formatted with aligned columns and a clear legend.
-   **Zero Dependencies**: All new features run on standard Bash.

## Pure Bash TUI Dashboard (New!)
We now offer a modern, visual Terminal User Interface (TUI) built entirely in **Bash**. No dependencies required!

### Usage
1.  Run the main script: `./gather_sys_info.sh`
2.  Select option **12**.
3.  Or run directly: `./dashboard.sh`

## Features
-   **Real-time Graphs**: Visual bars for CPU, RAM, and Disk usage.
-   **Zero Dependencies**: Works on any standard Linux system with Bash.
-   **Fast**: Instant startup and low resource usage.

## Installation

1.  **Download the script**:
    ```bash
    git clone https://github.com/TinorNoah/system-info-extractor.git
    cd system-info-extractor
    ```

2.  **Make it executable**:
    ```bash
    chmod +x gather_sys_info.sh dashboard.sh
    ```

3.  **Run the script**:
    ```bash
    ./gather_sys_info.sh
    ```

## Requirements

-   Bash
-   Standard Linux utilities: `grep`, `sed`, `awk`, `cut`, `head`, `column`
-   System tools (optional but recommended): `lscpu`, `lsblk`, `lspci`, `lsusb`, `ip`, `ss`, `nmcli`, `docker`, `podman`, `systemctl`

## License

MIT License
