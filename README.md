# 👁️‍🗨️ Akashic Records

> **"The Ultimate System Omniscience Tool."**

![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Maintenance](https://img.shields.io/badge/Maintenance-Active-green?style=for-the-badge)

---

**Akashic Records** serves as the central repository for your system's knowledge. It is a powerful, interactive utility designed to extract deep insights from your Linux environment, monitor vital statistics in real-time, and forge a robust, productive shell experience.

Whether you need a quick system audit, a live performance dashboard, or a fully configured ZSH environment, Akashic Records has the answer.

---

## 🔮 Capabilities

### 🧠 **System Omniscience (Information)**
Gain instant access to every detail of your machine:
*   **Core Intel**: Kernel version, architecture, uptime, and OS distribution.
*   **Hardware Sight**: Deep dive into CPU models, PCI/USB devices, and memory topology.
*   **Network Awareness**: IP routing, DNS configurations, and active listening ports.
*   **Container Status**: Real-time status of Docker and Podman instances.
*   **Service Health**: Instantly identify failed systemd units.

### ⚡ **Live Vitality (Dashboard)**
Launch a stunning, dependency-free **Terminal User Interface (TUI)** dashboard.
*   **Real-time Monitoring**: Visual bars for CPU, RAM, Swap, and Disk usage.
*   **Network Flow**: Live RX/TX data transfer rates.
*   **Battery Status**: Color-coded power monitoring.
*   **Top Processes**: Identify resource hogs instantly.

### 🛠️ **Environment Forge (Setup)**
Transform your terminal into a productivity powerhouse.
*   **Interactive Installer**: A guided wizard to set up **ZSH**.
*   **Starship Integration**: Automatically installs and configures the Starship prompt.
*   **Plugin Management**:
    *   `zsh-autosuggestions` (Type faster)
    *   `zsh-syntax-highlighting` (Catch errors early)
    *   `zsh-autocomplete` (Navigate like a pro)
*   **Safe & Reversible**: Includes dry-run modes, backups, and fail-safe logic.

---

## 🚀 Initialization

### Prerequisites
*   A Linux environment (Debian, Fedora, or Arch based).
*   `bash` (v4.0+ recommended).
*   `curl` and `git` (for installation).

### Installation

**✨ The Fast Way (One-Command Installer):**
Launch Akashic Records instantly without manual cloning. This will fetch the latest version and start the utility.

```bash
curl -sL https://raw.githubusercontent.com/TinorNoah/Akashic-Records/main/run.sh | bash
```

**🛠 The Manual Way:**
Clone the archives to your local machine:

```bash
git clone https://github.com/TinorNoah/Akashic-Records.git
cd Akashic-Records
chmod +x akashic_records.sh dashboard.sh
```

### Usage

**Invoke the Main Utility:**
```bash
./akashic_records.sh
```

**Launch Vitality Dashboard Only:**
```bash
./dashboard.sh
```

---

## ⚙️ Configuration

Akashic Records respects your existing configuration while offering powerful new defaults.

*   **Block-Based Config**: modifications to `.zshrc` are wrapped in clear start/end blocks (`# >>> plugin:name >>>`).
*   **Idempotent**: Run the setup as many times as you like; it won't duplicate configurations.
*   **Uninstallation**: Simply remove the marked blocks from your `.zshrc`.

---

## 🖼️ Gallery

> *Visualize the interface here*

| Main Menu | Dashboard | Setup Wizard |
| :---: | :---: | :---: |
| *(Image Placeholder)* | *(Image Placeholder)* | *(Image Placeholder)* |

---

## 📜 License

This project is open-source and available under the [MIT License](LICENSE).

> *"Knowledge is power. Absolute knowledge is Akashic."*
