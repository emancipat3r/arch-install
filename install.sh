#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Install dialog if not already installed
if ! command -v dialog &> /dev/null; then
  pacman -Sy --noconfirm dialog
fi

# Colors for pretty printing
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
  echo -e "${BLUE}==>${NC} $1"
}

print_success() {
  echo -e "${GREEN}==>${NC} $1"
}

print_error() {
  echo -e "${RED}==>${NC} $1"
}

# Get the amount of RAM in MB and round up to nearest whole number
RAM_SIZE=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024}')
RAM_SIZE=$(printf "%.0f" $RAM_SIZE)  # Round to the nearest integer

# Calculate swap size based on rounded RAM size plus 2GB
SWAP_SIZE="$((RAM_SIZE + 2048))M"

# Set up variables
dialog --inputbox "Enter the hostname:" 8 40 2> hostname
HOSTNAME=$(<hostname)

dialog --inputbox "Enter the username:" 8 40 2> new_username_var
NEW_USERNAME=$(<new_username_var)
USERNAME

# Ask for root password
dialog --passwordbox "Enter the root password:" 8 40 2> root_password
ROOT_PASSWORD=$(<root_password)

# Ask for user password
dialog --passwordbox "Enter the password for $NEW_USERNAME:" 8 40 2> user_password
USER_PASSWORD=$(<user_password)

# Ask for timezone
TIMEZONE=$(dialog --title "Select Timezone" --menu "Choose your timezone:" 15 50 4 \
  1 "America/New_York" \
  2 "Europe/London" \
  3 "Asia/Tokyo" \
  4 "Other" \
  3>&1 1>&2 2>&3)

if [ "$TIMEZONE" == "4" ]; then
  dialog --inputbox "Enter the full path of your timezone (e.g., Region/City):" 8 40 2> timezone
  TIMEZONE=$(<timezone)
else
  case $TIMEZONE in
    1) TIMEZONE="America/New_York";;
    2) TIMEZONE="Europe/London";;
    3) TIMEZONE="Asia/Tokyo";;
  esac
fi

# List available disks and sizes
DISK_LIST=()
while read -r line; do
  DISK_NAME=$(echo "$line" | awk '{print $1}')
  DISK_SIZE=$(echo "$line" | awk '{print $2}')
  DISK_LIST+=("$DISK_NAME" "$DISK_SIZE" "off")
done < <(lsblk -dn -o NAME,SIZE,TYPE | grep disk)

INSTALL_DISK=$(dialog --title "Select Disk" --radiolist "Choose the disk for OS installation:" 15 70 6 "${DISK_LIST[@]}" 3>&1 1>&2 2>&3)

# Ask for partition type
PARTITION_TYPE=$(dialog --title "Select Partition Type" --menu "Choose one of the following partition types:" 15 50 4 \
  1 "DOS (MBR)" \
  2 "GPT" \
  3 "EFI" \
  3>&1 1>&2 2>&3)

# Ask if the user wants to auto-reboot
AUTO_REBOOT=$(dialog --title "Auto Reboot" --menu "Do you want to auto reboot after installation?" 10 40 2 \
  1 "Yes" \
  2 "No" \
  3>&1 1>&2 2>&3)

# Ask if the user wants to configure as an SSH server
SSH_SERVER=$(dialog --title "SSH Server" --menu "Do you want to configure this as an SSH server?" 10 40 2 \
  1 "Yes" \
  2 "No" \
  3>&1 1>&2 2>&3)

if [ "$SSH_SERVER" == "1" ]; then
  SSHD_PORT=$(dialog --inputbox "Enter the SSH port (default is 22):" 8 40 22 3>&1 1>&2 2>&3)
  ALLOW_ROOT_LOGIN=$(dialog --title "Root Login" --menu "Allow root login via SSH?" 10 40 2 \
    1 "Yes" \
    2 "No" \
    3>&1 1>&2 2>&3)
  ALLOW_PASSWORD_LOGIN=$(dialog --title "Password Login" --menu "Allow password login via SSH?" 10 40 2 \
    1 "Yes" \
    2 "No" \
    3>&1 1>&2 2>&3)
fi

print_status "Partitioning and formatting the disk..."
case $PARTITION_TYPE in
    1)
        parted /dev/$INSTALL_DISK --script mklabel msdos
        parted /dev/$INSTALL_DISK --script mkpart primary ext4 1MiB 100%
        mkfs.ext4 /dev/${INSTALL_DISK}1
        mount /dev/${INSTALL_DISK}1 /mnt
        ;;
    2)
        parted /dev/$INSTALL_DISK --script mklabel gpt
        parted /dev/$INSTALL_DISK --script mkpart primary ext4 1MiB 100%
        mkfs.ext4 /dev/${INSTALL_DISK}1
        mount /dev/${INSTALL_DISK}1 /mnt
        ;;
    3)
        parted /dev/$INSTALL_DISK --script mklabel gpt
        parted /dev/$INSTALL_DISK --script mkpart primary fat32 1MiB 512MiB
        parted /dev/$INSTALL_DISK --script set 1 esp on
        mkfs.fat -F32 /dev/${INSTALL_DISK}1
        parted /dev/$INSTALL_DISK --script mkpart primary ext4 512MiB 100%
        mkfs.ext4 /dev/${INSTALL_DISK}2
        mount /dev/${INSTALL_DISK}2 /mnt
        mkdir -p /mnt/boot/efi
        mount /dev/${INSTALL_DISK}1 /mnt/boot/efi
        ;;
esac

print_status "Creating and activating swap..."
fallocate -l $SWAP_SIZE /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

print_status "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware

print_status "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system and configure
arch-chroot /mnt /bin/bash <<EOF
# Set up timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set up localization
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set up hostname and network
echo $HOSTNAME > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create a new user
useradd -m -G wheel $NEW_USERNAME
echo "$NEW_USERNAME:$USER_PASSWORD" | chpasswd
echo "$NEW_USERNAME ALL=(ALL) ALL" >> /etc/sudoers

# Install necessary packages
echo "Updating package database and installing necessary packages..."
pacman -Syu --noconfirm
pacman -S --noconfirm base-devel linux-headers networkmanager xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xprop gnome-shell gnome-control-center gnome-terminal gdm

# Enable essential services
systemctl enable NetworkManager
systemctl enable gdm

# SSH configuration if needed
if [ "$SSH_SERVER" == "1" ]; then
    pacman -S --noconfirm openssh
    systemctl enable sshd
    sed -i "s/#Port 22/Port $SSHD_PORT/" /etc/ssh/sshd_config
    if [ "$ALLOW_ROOT_LOGIN" == "1" ]; then
        sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config
    else
        sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
    fi
    if [ "$ALLOW_PASSWORD_LOGIN" == "1" ]; then
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
    else
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
    fi
fi

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
if [ "$PARTITION_TYPE" == "3" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
    grub-install --target=i386-pc /dev/$INSTALL_DISK
fi
grub-mkconfig -o /boot/grub/grub.cfg

echo "Minimal GNOME installation is complete. Please exit the chroot and reboot your system."
EOF

# Exit chroot, unmount and reboot if selected
print_status "Exiting chroot and unmounting..."
#umount -R /mnt

if [ "$AUTO_REBOOT" == "1" ]; then
  print_status "Rebooting system..."
  reboot
else
  print_success "Installation complete. Please reboot the system."
fi