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

# Set up variables
dialog --inputbox "Enter the root partition (e.g., /dev/sda1):" 8 40 2> root_partition
ROOT_PARTITION=$(<root_partition)

dialog --inputbox "Enter the boot partition (e.g., /dev/sda2):" 8 40 2> boot_partition
BOOT_PARTITION=$(<boot_partition)

dialog --inputbox "Enter the hostname:" 8 40 2> hostname
HOSTNAME=$(<hostname)

dialog --inputbox "Enter the username:" 8 40 2> username
USERNAME=$(<username)

# Update system clock
timedatectl set-ntp true

# Partition the disks (adjust partitions as needed)
(
echo g # Create a new GPT partition table
echo n # New partition for root
echo 1 # Partition number 1
echo   # Default - start at beginning of disk
echo +20G # 20 GB root partition
echo n # New partition for boot
echo 2 # Partition number 2
echo   # Default - start at the end of previous partition
echo +512M # 512 MB boot partition
echo w # Write changes
) | fdisk /dev/sda

# Format the partitions
mkfs.ext4 $ROOT_PARTITION
mkfs.fat -F32 $BOOT_PARTITION

# Mount the file systems
mount $ROOT_PARTITION /mnt
mkdir /mnt/boot
mount $BOOT_PARTITION /mnt/boot

# Install essential packages
pacstrap /mnt base linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set up timezone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
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
echo "Set root password:"
passwd

# Install necessary packages
pacman -Syu --noconfirm
pacman -S --noconfirm base-devel linux-headers networkmanager

# Enable NetworkManager
systemctl enable NetworkManager

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Create a new user
useradd -m -G wheel $USERNAME
echo "Set password for $USERNAME:"
passwd $USERNAME
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

# Install Xorg
pacman -S --noconfirm xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xprop

# Install GNOME packages
pacman -S --noconfirm gnome-shell gnome-control-center gnome-terminal gdm

# Enable GDM
systemctl enable gdm

# Clean up
pacman -Scc --noconfirm

echo "Minimal GNOME installation is complete. Please exit the chroot and reboot your system."

EOF

# Unmount file systems
umount -R /mnt

# Reboot
dialog --msgbox "Installation complete. Please reboot the system." 8 40
reboot