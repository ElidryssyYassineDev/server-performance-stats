# Server Performance Stats

A lightweight Bash script for monitoring essential Linux server performance statistics directly from the terminal.

This project was built as part of the roadmap.sh DevOps projects.

## Project Page

[Server Stats — roadmap.sh](https://roadmap.sh/projects/server-stats)

## Features

The script displays the following information:

### System Information
- Operating system and version
- Hostname
- System uptime
- Load averages (1, 5, and 15 minutes)
- Logged-in users

### CPU Usage
- Total CPU utilization percentage
- Calculated using two samples from `/proc/stat` taken one second apart

### Memory Usage
- Total memory
- Used memory and percentage
- Available memory and percentage
- Free memory

### Disk Usage
- Root filesystem capacity
- Used disk space and percentage
- Available disk space

### Top Processes
- Top 5 processes ranked by CPU usage
- Top 5 processes ranked by memory usage

## Requirements

- Linux operating system
- Bash
- Standard Linux utilities:
  - `awk`
  - `ps`
  - `df`
  - `hostname`
  - `who`
  - `sleep`

The script also reads information from Linux system files under `/proc` and `/etc/os-release`.

## Installation

Clone the repository:

```bash
git clone git@github.com:ElidryssyYassineDev/server-performance-stats.git
```

Navigate into the project directory:

```bash
cd server-performance-stats
```

Make the script executable:

```bash
chmod +x server-stats.sh
```

## Usage

Run the script:

```bash
./server-stats.sh
```

No root privileges are required for normal execution.

## Implementation Details

| Metric | Linux data source |
|---|---|
| CPU usage | `/proc/stat` |
| Memory usage | `/proc/meminfo` |
| Disk usage | `df -P /` |
| Process statistics | `ps` |
| Operating system | `/etc/os-release` |
| Uptime | `/proc/uptime` |
| Load average | `/proc/loadavg` |
| Logged-in users | `who` |

### Calculation Notes

- CPU utilization is calculated from the difference between two consecutive CPU counter samples.
- Used memory is calculated as total memory minus available memory.
- Memory values are displayed in MiB.
- Disk values are displayed in GiB.
- Disk statistics cover the root filesystem (`/`).
- Process CPU percentages are based on the values reported by `ps`, not instantaneous measurements.

## Project Structure

```text
server-performance-stats/
├── server-stats.sh
├── README.md
└── .gitignore
```

## Repository

[GitHub — Server Performance Stats](https://github.com/ElidryssyYassineDev/server-performance-stats)
