# Arch Linux Minimal GNOME Installation Script

This repository contains a bash script that provides a Text User Interface (TUI), via `dialog`, for installing Arch Linux with a minimal GNOME environment

## Features

- Interactive disk partitioning
- Automatic formatting and mounting of partitions
- Installation of base Arch Linux system
- Configuration of timezone, localization, and hostname
- NetworkManager setup and enablement
- GRUB bootloader installation and configuration
- Minimal GNOME environment installation
- User creation with sudo privileges

## Prerequisites

- Boot from the Arch Linux USB.
- Connection to the internet (e.g., via `iwctl` for Wi-Fi or `dhcpcd` for Ethernet).

## Usage

1. Clone the repository or download the script.

   ```bash
   git clone https://github.com/yourusername/arch-linux-minimal-gnome.git
   cd arch-linux-minimal-gnome

2. Make the script executable:

```bash
chmod +x tui_install.sh
```

3. Run the script with root privileges:
```bash
sudo ./tui_install.sh
```

Script Breakdown

1. Check for root privileges: Ensure the script is run as root.
2. Install dialog: Install the dialog package if it is not already installed.
3. Set up variables: Use dialog to gather user input for partitions, hostname, and username.
4. Update system clock: Ensure the system clock is accurate.
5. Partition the disks: Create GPT partition table and partitions for root and boot.
6. Format the partitions: Format the root as ext4 and boot as FAT32.
7. Mount the file systems: Mount root and boot partitions.
8. Install essential packages: Install the base system.
9. Generate fstab: Create file system table.
10. Chroot into the new system: Change root into the new system and perform configurations.
11. Set up timezone, localization, hostname: Configure time, locale, and hostname.
12. Set root password: Set the root password.
13. Install and enable NetworkManager: Ensure network connectivity.
14. Install and configure bootloader: Install and configure GRUB.
15. Create a new user: Add a new user with sudo privileges.
16. Install Xorg and GNOME packages: Install minimal Xorg and GNOME packages.
17. Enable GDM: Enable GNOME Display Manager.
18. Clean up: Clean up the package cache.
19. Unmount file systems and reboot: Finish installation and reboot the system.