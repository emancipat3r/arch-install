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

dialog --inputbox "Enter the username:" 8 40 2> username
USERNAME=$(<username)

# Ask for root password
dialog --passwordbox "Enter the root password:" 8 40 2> root_password
ROOT_PASSWORD=$(<root_password)

# Ask for user password
dialog --passwordbox "Enter the password for $USERNAME:" 8 40 2> user_password
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
  DISK_SIZE=$(echo "$line" | awk '{print $4}')
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

# Software selection associative array
declare -A SOFTWARE_SELECTION=(
  ["1"]="ohmyzsh"
  ["2"]="kitty"
  ["3"]="firefox"
  ["4"]="vscodium-bin"
  ["5"]="git"
  ["6"]="vim"
  ["7"]="aur-support"
  ["8"]="mullvad-vpn"
  ["9"]="virtualbox"
  ["10"]="gnome-tweaks"
  ["11"]="eog"
  ["12"]="fonts"
  ["13"]="libreoffice-fresh"
  ["14"]="gimp"
  ["15"]="inkscape"
  ["16"]="gnome-calendar"
  ["17"]="gnome-weather"
  ["18"]="evolution"
  ["19"]="docker"
  ["20"]="nodejs npm"
  ["21"]="python python-pip"
  ["22"]="jdk-openjdk"
  ["23"]="intellij-idea-community-edition"
  ["24"]="gnome-calculator"
  ["25"]="evince"
  ["26"]="gnome-disk-utility"
  ["27"]="nautilus"
  ["28"]="gnome-screenshot"
  ["29"]="gnome-control-center"
  ["30"]="gnome-text-editor"
  ["31"]="aria2"
  ["32"]="zsh-autosuggestions"
  ["33"]="zsh-syntax-highlighting"
  ["34"]="vlc"
  ["35"]="mpv"
  ["36"]="spotify"
  ["37"]="audacity"
  ["38"]="doublecmd-gtk2"
  ["39"]="discord"
  ["40"]="slack-desktop"
  ["41"]="zoom"
  ["42"]="htop"
  ["43"]="neofetch"
  ["44"]="gnome-system-monitor"
  ["45"]="gnome-usage"
  ["46"]="google-chrome"
  ["47"]="brave-bin"
  ["48"]="openssh"
  ["49"]="networkmanager"
  ["50"]="papirus-icon-theme"
  ["51"]="arc-gtk-theme"
)

SOFTWARE_SELECTION_DIALOG=$(dialog --title "Common Software" --checklist "Select software to install:" 25 70 45 \
  1 "Oh My Zsh" off \
  2 "Kitty" off \
  3 "Firefox" off \
  4 "OSS Codium" off \
  5 "Git" off \
  6 "Vim" off \
  7 "AUR Support" off \
  8 "Mullvad VPN (AUR)" off \
  9 "VirtualBox" off \
  10 "Gnome Tweaks" off \
  11 "Eye of GNOME (eog)" off \
  12 "Fonts" off \
  13 "LibreOffice" off \
  14 "GIMP" off \
  15 "Inkscape" off \
  16 "GNOME Calendar" off \
  17 "GNOME Weather" off \
  18 "Evolution (Email Client)" off \
  19 "Docker" off \
  20 "Node.js" off \
  21 "Python" off \
  22 "JDK (Java Development Kit)" off \
  23 "IntelliJ IDEA Community Edition" off \
  24 "gnome-calculator" off \
  25 "evince (Document Viewer)" off \
  26 "gnome-disk-utility" off \
  27 "nautilus (Files)" off \
  28 "gnome-screenshot" off \
  29 "gnome-control-center" off \
  30 "gnome-text-editor" off \
  31 "aria2" off \
  32 "zsh-autosuggestions" off \
  33 "zsh-syntax-highlighting" off \
  34 "VLC Media Player" off \
  35 "MPV Media Player" off \
  36 "Spotify (AUR)" off \
  37 "Audacity" off \
  38 "Double Commander" off \
  39 "Discord (AUR)" off \
  40 "Slack (AUR)" off \
  41 "Zoom (AUR)" off \
  42 "Htop" off \
  43 "Neofetch" off \
  44 "GNOME System Monitor" off \
  45 "GNOME Usage" off \
  46 "Google Chrome (AUR)" off \
  47 "Brave Browser (AUR)" off \
  48 "OpenSSH" off \
  49 "NetworkManager" off \
  50 "Papirus Icon Theme" off \
  51 "Arc GTK Theme" off \
  3>&1 1>&2 2>&3)

# Ask for font installation if selected
if [[ "$SOFTWARE_SELECTION_DIALOG" == *"12"* ]]; then
  FONTS_SELECTION=$(dialog --title "Fonts" --checklist "Select fonts to install:" 25 70 12 \
    1 "ttf-ubuntu-font-family" off \
    2 "ttf-dejavu" off \
    3 "ttf-bitstream-vera" off \
    4 "ttf-liberation" off \
    5 "noto-fonts" off \
    6 "ttf-roboto" off \
    7 "ttf-opensans" off \
    8 "opendesktop-fonts" off \
    9 "cantarell-fonts" off \
    10 "freetype2" off \
    11 "Nerd Fonts version of Fira Code" off \
    12 "ttf-ms-fonts" off \
    3>&1 1>&2 2>&3)
fi

# Partitioning and formatting
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

# Create and activate swap
print_status "Creating and activating swap..."
fallocate -l $SWAP_SIZE /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# Install base system
print_status "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware

# Generate fstab
print_status "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set up timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set up localization
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set up hostname
echo $HOSTNAME > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create a new user
useradd -m -G wheel $USERNAME
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

# Install necessary packages
pacman -Syu --noconfirm
pacman -S --noconfirm base-devel linux-headers networkmanager xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xprop gnome-shell gnome-control-center gnome-terminal gdm

# Enable NetworkManager
systemctl enable NetworkManager

# Enable GDM
systemctl enable gdm

# Configure SSH server if selected
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

# Install selected software
for software in $SOFTWARE_SELECTION_DIALOG; do
  pacman -S --noconfirm ${SOFTWARE_SELECTION[$software]}
done

# Install fonts if selected
if [[ "$SOFTWARE_SELECTION_DIALOG" == *"12"* ]]; then
  for font in $FONTS_SELECTION; do
    pacman -S --noconfirm ${SOFTWARE_SELECTION[$font]}
  done
fi

# Clean up
pacman -Scc --noconfirm

echo "Minimal GNOME installation is complete. Please exit the chroot and reboot your system."

EOF

# Exit chroot, unmount and reboot if selected
print_status "Exiting chroot and unmounting..."
umount -R /mnt

if [ "$AUTO_REBOOT" == "1" ]; then
  print_status "Rebooting system..."
  reboot
else
  print_success "Installation complete. Please reboot the system."
fi