# Arch Linux Automated Installation Script

This script automates the installation of Arch Linux with optional software and configurations.

## Prerequisites

 - You must have root privileges to run this script.
 - The script requires dialog for the interactive menu.

## Usage

1. Download the script and make it executable:

```bash
chmod +x install.sh
```

2. Run the script:

```bash
sudo ./install.sh
```

## Script Details

### User Input

The script will prompt for the following information:

1. Hostname: Enter the desired hostname for the system.
2. Username: Enter the desired username.
3. Root Password: Enter the password for the root user.
4. User Password: Enter the password for the new user.
5. Timezone: Select or enter the desired timezone.
6. Partition Type: Select the type of partition (DOS, GPT, EFI).
7. Auto Reboot: Choose whether to reboot the system automatically after installation.
8. SSH Server Configuration:
    - Whether to configure the system as an SSH server.
    - SSH port (default is 22).
    - Allow root login via SSH.
    - Allow password login via SSH.
9. Software Selection: Select common software to install (e.g., Firefox, Git, Docker, etc.).
10. Font Selection: If fonts are selected, choose specific fonts to install.

### Partitioning and Formatting

The script supports three partition types:

 - DOS (MBR)
 - GPT
 - EFI

It will partition the disk, format the partitions, and set up the mount points.

### Swap Space

The script calculates the swap size based on the total RAM plus an additional 2GB.

### Base System Installation

The script installs the base system and generates the fstab file.

### Chroot Configuration

Inside the chroot environment, the script:

 - Sets up the timezone, localization, hostname, and root/user passwords.
 - Installs and enables NetworkManager.
 - Configures the SSH server if selected.
 - Installs and configures the bootloader.
 - Installs selected software and fonts.
 - Cleans up the package cache.

### Exiting Chroot and Reboot

After exiting the chroot environment, the script unmounts the partitions and optionally reboots the system.