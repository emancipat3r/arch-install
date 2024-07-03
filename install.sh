#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check for internet connection
if ! ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
  echo "It doesn't appear you are connected to the Internet. Exiting..."
  exit 1
fi

# Install gum if not already installed
if ! command -v gum &> /dev/null; then
  pacman -Sy --noconfirm gum
fi

# Colors for pretty printing
RED=$(gum style --foreground 196)
GREEN=$(gum style --foreground "#9aff9a")
YELLOW=$(gum style --foreground 226)
BLUE=$(gum style --foreground 75)
MAGENTA=$(gum style --foreground 201)
CYAN=$(gum style --foreground 51)
GRAY=$(gum style --foreground 250) # LightGray
NC=$(gum style --reset)
UNDERLINED=$(gum style --underline)
ITALIC=$(gum style --italic)
BOLD=$(gum style --bold)
FAINT=$(gum style --faint)


print_title() {
    local title="$1"

    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 50 --margin "1 2" --padding "2 4" \
        "$title"
}

print_status() {
  echo -e "${BLUE}[-]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[+]{NC} $1"
}

print_error() {
  echo -e "${RED}[!]${NC} $1"
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
SET_USERNAME=$(<username)

# Ask for root password
dialog --passwordbox "Enter the root password:" 8 40 2> root_password
ROOT_PASSWORD=$(<root_password)

# Ask for user password
dialog --passwordbox "Enter the password for $SET_USERNAME:" 8 40 2> user_password
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

# Validate disk selection
if [ -z "$INSTALL_DISK" ]; then
  print_error "No disk selected. Exiting."
  exit 1
fi

# Determine if the disk is an NVMe drive
if [[ $INSTALL_DISK == nvme* ]]; then
  PART_SUFFIX="p"
else
  PART_SUFFIX=""
fi

# Ask for partition type
PARTITION_TYPE=$(dialog --title "Select Partition Type" --menu "Choose one of the following partition types:" 15 50 4 \
  1 "DOS (MBR)" \
  2 "GPT" \
  3 "EFI" \
  3>&1 1>&2 2>&3)

# Validate partition type selection
if [ -z "$PARTITION_TYPE" ]; then
  print_error "No partition type selected. Exiting."
  exit 1
fi

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
  ["4"]="code"
  ["6"]="vim"
  ["7"]="mullvad-vpn"
  ["8"]="virtualbox"
  ["9"]="gnome-tweaks"
  ["10"]="eog"
  ["11"]="fonts"
  ["12"]="python python-pip"
  ["13"]="gnome-calculator"
  ["14"]="evince"
  ["15"]="gnome-disk-utility"
  ["16"]="nautilus"
  ["17"]="gnome-screenshot"
  ["18"]="gnome-control-center"
  ["19"]="gnome-text-editor"
  ["20"]="aria2"
  ["21"]="zsh-autosuggestions"
  ["22"]="zsh-syntax-highlighting"
  ["23"]="vlc"
  ["24"]="openssh"
  ["25"]="networkmanager"
)

SOFTWARE_SELECTION_DIALOG=$(dialog --title "Common Software" --checklist "Select software to install:" 25 70 45 \
  1 "Oh My Zsh" off \
  2 "Kitty" off \
  3 "Firefox" off \
  4 "Code - OSS" off \
  6 "Vim" off \
  7 "Mullvad VPN (AUR)" off \
  8 "VirtualBox" off \
  9 "Gnome Tweaks" off \
  10 "Eye of GNOME (eog)" off \
  11 "Fonts" off \
  12 "Python" off \
  13 "gnome-calculator" off \
  14 "evince (Document Viewer)" off \
  15 "Gnome Disk Utility" off \
  16 "Nautilus (File Explorer)" off \
  17 "Gnome Screenshot" off \
  18 "Gnome Settings" off \
  19 "gnome-text-editor" off \
  20 "aria2" off \
  21 "ZSH Auto Suggestions" off \
  22 "ZSH Syntax Highlighting" off \
  23 "VLC Media Player" off \
  24 "OpenSSH" off \
  25 "Network Manager" off \
  3>&1 1>&2 2>&3)

# Partitioning and formatting based on selection
print_status "Partitioning and formatting the disk..."

for type in $PARTITION_TYPE; do
  case $type in
    1) # DOS (MBR)
      parted /dev/$INSTALL_DISK --script mklabel msdos
      echo -e "n\np\n\n\n+512M\na\nw" | fdisk /dev/$INSTALL_DISK
      echo -e "n\np\n\n\n+$SWAP_SIZE\nt\n\n82\nw" | fdisk /dev/$INSTALL_DISK
      echo -e "n\np\n\n\n\nw" | fdisk /dev/$INSTALL_DISK
      mkfs.ext4 /dev/${INSTALL_DISK}${PART_SUFFIX}1
      mkfs.ext4 /dev/${INSTALL_DISK}${PART_SUFFIX}3
      mkswap /dev/${INSTALL_DISK}${PART_SUFFIX}2
      swapon /dev/${INSTALL_DISK}${PART_SUFFIX}2
      mount /dev/${INSTALL_DISK}${PART_SUFFIX}3 /mnt
      ;;
    2) # GPT
      parted /dev/$INSTALL_DISK --script mklabel gpt
      sgdisk -n=1:0:+31M -t=1:ef02 -c=0:mbrboot /dev/$INSTALL_DISK
      sgdisk -n=2:0:+512M -c=0:boot /dev/$INSTALL_DISK
      sgdisk -n=3:0:+${SWAP_SIZE} -t=3:8200 -c=0:swap /dev/$INSTALL_DISK
      sgdisk -n=4:0:0 -c=0:root /dev/$INSTALL_DISK
      mkfs.ext4 /dev/${INSTALL_DISK}${PART_SUFFIX}4
      mkfs.ext4 /dev/${INSTALL_DISK}${PART_SUFFIX}2
      mkswap /dev/${INSTALL_DISK}${PART_SUFFIX}3
      swapon /dev/${INSTALL_DISK}${PART_SUFFIX}3
      mount /dev/${INSTALL_DISK}${PART_SUFFIX}4 /mnt
      mkdir -p /mnt/boot
      mount /dev/${INSTALL_DISK}${PART_SUFFIX}2 /mnt/boot
      ;;
    3) # EFI + GPT
      parted /dev/$INSTALL_DISK --script mklabel gpt
      sgdisk -n=1:0:+512M -t=1:ef00 -c=0:boot /dev/$INSTALL_DISK
      sgdisk -n=2:0:+${SWAP_SIZE} -t=2:8200 -c=0:swap /dev/$INSTALL_DISK
      sgdisk -n=3:0:0 -c=0:root /dev/$INSTALL_DISK
      mkfs.fat -F32 /dev/${INSTALL_DISK}${PART_SUFFIX}1
      mkfs.ext4 /dev/${INSTALL_DISK}${PART_SUFFIX}3
      mkswap /dev/${INSTALL_DISK}${PART_SUFFIX}2
      swapon /dev/${INSTALL_DISK}${PART_SUFFIX}2
      mount /dev/${INSTALL_DISK}${PART_SUFFIX}3 /mnt
      mkdir -p /mnt/boot/efi
      mount /dev/${INSTALL_DISK}${PART_SUFFIX}1 /mnt/boot/efi
      ;;
    *)
      print_error "Invalid partition type selected. Exiting."
      exit 1
      ;;
  esac
done

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

# Chroot into new system 
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
useradd -m -G wheel $SET_USERNAME
echo "$SET_USERNAME:$USER_PASSWORD" | chpasswd
echo "$SET_USERNAME ALL=(ALL) ALL" >> /etc/sudoers

# Install necessary packages
pacman -Syu --noconfirm
pacman -S --noconfirm base-devel linux-headers networkmanager xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xprop gnome-shell gnome-control-center gnome-terminal gdm gnome-tweaks dconf git

# Enable NetworkManager
systemctl enable NetworkManager

# Enable GDM
systemctl enable gdm

# Remove GDM logo
dbus-launch gsettings set org.gnome.login-screen logo ''

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
if [[ "$PARTITION_TYPE" == *"3"* ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
  grub-install --target=i386-pc /dev/$INSTALL_DISK
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Install selected software
SOFTWARE_LIST=($SOFTWARE_SELECTION_DIALOG)
for software in "\${SOFTWARE_LIST[@]}"; do
  pacman -S --noconfirm ${SOFTWARE_SELECTION[$software]}
done

# Install fonts if selected
if [[ "$SOFTWARE_SELECTION_DIALOG" == *"12"* ]]; then
  pacman -S --noconfirm ttf-ubuntu-font-family ttf-dejavu ttf-bitstream-vera ttf-liberation noto-fonts ttf-roboto ttf-opensans opendesktop-fonts cantarell-fonts freetype2 ttf-firacode-nerd ttf-ms-fonts
fi

# Clean up
pacman -Scc --noconfirm
EOF

# Exit chroot, unmount and reboot if selected
print_status "Installation complete. Unmounting..."
umount -R /mnt

if [ "$AUTO_REBOOT" == "1" ]; then
  print_status "Rebooting system..."
  reboot
else
  print_success "Installation complete. Please reboot the system."
fi