package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/lipgloss"
)

type item struct {
	title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

type state int

const (
	askHostname state = iota
	askUsername
	askRootPassword
	askUserPassword
	askTimezone
	askPartitionType
	askSSHServer
	askSSHDPort
	askRootLogin
	askPasswordLogin
	askSoftware
	confirm
	installing
	done
)

type model struct {
	state               state
	hostnameInput       textinput.Model
	usernameInput       textinput.Model
	rootPasswordInput   textinput.Model
	userPasswordInput   textinput.Model
	timezoneChoice      list.Model
	partitionTypeChoice list.Model
	sshServerChoice     list.Model
	sshdPortInput       textinput.Model
	rootLoginChoice     list.Model
	passwordLoginChoice list.Model
	softwareChoice      list.Model
	softwareList        map[string]string
	selectedSoftware    []string
	output              string
}

func initialModel() model {
	hostnameInput := textinput.New()
	hostnameInput.Placeholder = "Enter the hostname"
	hostnameInput.Focus()

	usernameInput := textinput.New()
	usernameInput.Placeholder = "Enter the username"

	rootPasswordInput := textinput.New()
	rootPasswordInput.Placeholder = "Enter the root password"
	rootPasswordInput.EchoMode = textinput.EchoPassword

	userPasswordInput := textinput.New()
	userPasswordInput.Placeholder = "Enter the user password"
	userPasswordInput.EchoMode = textinput.EchoPassword

	timezones := []item{
		{title: "America/New_York", desc: "Eastern Time (US & Canada)"},
		{title: "Europe/London", desc: "Greenwich Mean Time (GMT)"},
		{title: "Asia/Tokyo", desc: "Japan Standard Time (JST)"},
		{title: "Other", desc: "Enter manually"},
	}
	timezoneChoice := list.New(timezones, list.NewDefaultDelegate(), 0, 0)
	timezoneChoice.Title = "Select Timezone"

	partitionTypes := []item{
		{title: "DOS (MBR)", desc: "Master Boot Record"},
		{title: "GPT", desc: "GUID Partition Table"},
		{title: "EFI", desc: "Extensible Firmware Interface"},
	}
	partitionTypeChoice := list.New(partitionTypes, list.NewDefaultDelegate(), 0, 0)
	partitionTypeChoice.Title = "Select Partition Type"

	yesNoOptions := []item{
		{title: "Yes", desc: ""},
		{title: "No", desc: ""},
	}
	sshServerChoice := list.New(yesNoOptions, list.NewDefaultDelegate(), 0, 0)
	sshServerChoice.Title = "Configure as SSH server?"

	rootLoginChoice := list.New(yesNoOptions, list.NewDefaultDelegate(), 0, 0)
	rootLoginChoice.Title = "Allow root login via SSH?"

	passwordLoginChoice := list.New(yesNoOptions, list.NewDefaultDelegate(), 0, 0)
	passwordLoginChoice.Title = "Allow password login via SSH?"

	sshdPortInput := textinput.New()
	sshdPortInput.Placeholder = "Enter SSH port (default is 22)"
	sshdPortInput.SetValue("22")

	softwareList := map[string]string{
		"Oh My Zsh":                    "ohmyzsh",
		"Kitty":                        "kitty",
		"Firefox":                      "firefox",
		"VSCodium":                     "vscodium-bin",
		"Git":                          "git",
		"Vim":                          "vim",
		"AUR Support":                  "aur-support",
		"Mullvad VPN (AUR)":            "mullvad-vpn",
		"VirtualBox":                   "virtualbox",
		"Gnome Tweaks":                 "gnome-tweaks",
		"Eye of GNOME (eog)":           "eog",
		"LibreOffice":                  "libreoffice-fresh",
		"GIMP":                         "gimp",
		"Inkscape":                     "inkscape",
		"GNOME Calendar":               "gnome-calendar",
		"GNOME Weather":                "gnome-weather",
		"Evolution (Email Client)":     "evolution",
		"Docker":                       "docker",
		"Node.js":                      "nodejs npm",
		"Python":                       "python python-pip",
		"JDK (Java Development Kit)":   "jdk-openjdk",
		"IntelliJ IDEA Community Edition": "intellij-idea-community-edition",
		"gnome-calculator":             "gnome-calculator",
		"evince (Document Viewer)":     "evince",
		"gnome-disk-utility":           "gnome-disk-utility",
		"nautilus (Files)":             "nautilus",
		"gnome-screenshot":             "gnome-screenshot",
		"gnome-control-center":         "gnome-control-center",
		"gnome-text-editor":            "gnome-text-editor",
		"aria2":                        "aria2",
		"zsh-autosuggestions":          "zsh-autosuggestions",
		"zsh-syntax-highlighting":      "zsh-syntax-highlighting",
		"VLC Media Player":             "vlc",
		"MPV Media Player":             "mpv",
		"Spotify (AUR)":                "spotify",
		"Audacity":                     "audacity",
		"Double Commander":             "doublecmd-gtk2",
		"Discord (AUR)":                "discord",
		"Slack (AUR)":                  "slack-desktop",
		"Zoom (AUR)":                   "zoom",
		"Htop":                         "htop",
		"Neofetch":                     "neofetch",
		"GNOME System Monitor":         "gnome-system-monitor",
		"GNOME Usage":                  "gnome-usage",
		"Google Chrome (AUR)":          "google-chrome",
		"Brave Browser (AUR)":          "brave-bin",
		"OpenSSH":                      "openssh",
		"NetworkManager":               "networkmanager",
		"Papirus Icon Theme":           "papirus-icon-theme",
		"Arc GTK Theme":                "arc-gtk-theme",
	}

	softwareItems := make([]list.Item, 0, len(softwareList))
	for title := range softwareList {
		softwareItems = append(softwareItems, item{title: title})
	}
	softwareChoice := list.New(softwareItems, list.NewDefaultDelegate(), 0, 0)
	softwareChoice.Title = "Select Software to Install"

	return model{
		state:               askHostname,
		hostnameInput:       hostnameInput,
		usernameInput:       usernameInput,
		rootPasswordInput:   rootPasswordInput,
		userPasswordInput:   userPasswordInput,
		timezoneChoice:      timezoneChoice,
		partitionTypeChoice: partitionTypeChoice,
		sshServerChoice:     sshServerChoice,
		sshdPortInput:       sshdPortInput,
		rootLoginChoice:     rootLoginChoice,
		passwordLoginChoice: passwordLoginChoice,
		softwareChoice:      softwareChoice,
		softwareList:        softwareList,
		selectedSoftware:    []string{},
	}
}

func (m model) Init() tea.Cmd {
	return textinput.Blink
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch m.state {
	case askHostname:
		m.hostnameInput, cmd = m.hostnameInput.Update(msg)
		if m.hostnameInput.Value() != "" && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askUsername
			m.usernameInput.Focus()
		}
	case askUsername:
		m.usernameInput, cmd = m.usernameInput.Update(msg)
		if m.usernameInput.Value() != "" && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askRootPassword
			m.rootPasswordInput.Focus()
		}
	case askRootPassword:
		m.rootPasswordInput, cmd = m.rootPasswordInput.Update(msg)
		if m.rootPasswordInput.Value() != "" && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askUserPassword
			m.userPasswordInput.Focus()
		}
	case askUserPassword:
		m.userPasswordInput, cmd = m.userPasswordInput.Update(msg)
		if m.userPasswordInput.Value() != "" && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askTimezone
		}
	case askTimezone:
		m.timezoneChoice, cmd = m.timezoneChoice.Update(msg)
		if choice := m.timezoneChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			if choice.Title() == "Other" {
				m.timezoneChoice.SetFilter("Enter manually")
				m.state = askPartitionType
			} else {
				m.state = askPartitionType
			}
		}
	case askPartitionType:
		m.partitionTypeChoice, cmd = m.partitionTypeChoice.Update(msg)
		if choice := m.partitionTypeChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askSSHServer
		}
	case askSSHServer:
		m.sshServerChoice, cmd = m.sshServerChoice.Update(msg)
		if choice := m.sshServerChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			if choice.Title() == "Yes" {
				m.state = askSSHDPort
			} else {
				m.state = askSoftware
			}
		}
	case askSSHDPort:
		m.sshdPortInput, cmd = m.sshdPortInput.Update(msg)
		if m.sshdPortInput.Value() != "" && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askRootLogin
		}
	case askRootLogin:
		m.rootLoginChoice, cmd = m.rootLoginChoice.Update(msg)
		if choice := m.rootLoginChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askPasswordLogin
		}
	case askPasswordLogin:
		m.passwordLoginChoice, cmd = m.passwordLoginChoice.Update(msg)
		if choice := m.passwordLoginChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askSoftware
		}
	case askSoftware:
		m.softwareChoice, cmd = m.softwareChoice.Update(msg)
		if msg == tea.KeyEnter || msg == tea.KeyTab {
			m.selectedSoftware = append(m.selectedSoftware, m.softwareChoice.SelectedItems()...)
			m.state = confirm
		}
	case confirm:
		// Confirm and perform the installation
		m.performInstallation()
	}

	return m, cmd
}

func (m model) View() string {
	switch m.state {
	case askHostname:
		return fmt.Sprintf(
			"Enter Hostname:\n\n%s\n\n%s",
			m.hostnameInput.View(),
			"(Press Enter to confirm)",
		)
	case askUsername:
		return fmt.Sprintf(
			"Enter Username:\n\n%s\n\n%s",
			m.usernameInput.View(),
			"(Press Enter to confirm)",
		)
	case askRootPassword:
		return fmt.Sprintf(
			"Enter Root Password:\n\n%s\n\n%s",
			m.rootPasswordInput.View(),
			"(Press Enter to confirm)",
		)
	case askUserPassword:
		return fmt.Sprintf(
			"Enter User Password:\n\n%s\n\n%s",
			m.userPasswordInput.View(),
			"(Press Enter to confirm)",
		)
	case askTimezone:
		return fmt.Sprintf(
			"Select Timezone:\n\n%s\n\n%s",
			m.timezoneChoice.View(),
			"(Press Enter to confirm)",
		)
	case askPartitionType:
		return fmt.Sprintf(
			"Select Partition Type:\n\n%s\n\n%s",
			m.partitionTypeChoice.View(),
			"(Press Enter to confirm)",
		)
	case askSSHServer:
		return fmt.Sprintf(
			"Configure as SSH Server?\n\n%s\n\n%s",
			m.sshServerChoice.View(),
			"(Press Enter to confirm)",
		)
	case askSSHDPort:
		return fmt.Sprintf(
			"Enter SSH Port:\n\n%s\n\n%s",
			m.sshdPortInput.View(),
			"(Press Enter to confirm)",
		)
	case askRootLogin:
		return fmt.Sprintf(
			"Allow Root Login via SSH?\n\n%s\n\n%s",
			m.rootLoginChoice.View(),
			"(Press Enter to confirm)",
		)
	case askPasswordLogin:
		return fmt.Sprintf(
			"Allow Password Login via SSH?\n\n%s\n\n%s",
			m.passwordLoginChoice.View(),
			"(Press Enter to confirm)",
		)
	case askSoftware:
		return fmt.Sprintf(
			"Select Software to Install:\n\n%s\n\n%s",
			m.softwareChoice.View(),
			"(Press Enter to confirm)",
		)
	case confirm:
		return "Installation in progress...\n\nPlease wait."
	default:
		return "Unknown state"
	}
}

func (m *model) performInstallation() {
	// Print status messages
	printStatus := func(msg string) {
		m.output += fmt.Sprintf("%s\n", msg)
	}

	printStatus("Starting installation...")

	// Set the hostname
	exec.Command("hostnamectl", "set-hostname", m.hostnameInput.Value()).Run()
	printStatus("Hostname set")

	// Create the user
	exec.Command("useradd", "-m", "-G", "wheel", m.usernameInput.Value()).Run()
	printStatus("User created")

	// Set passwords
	exec.Command("sh", "-c", fmt.Sprintf("echo root:%s | chpasswd", m.rootPasswordInput.Value())).Run()
	exec.Command("sh", "-c", fmt.Sprintf("echo %s:%s | chpasswd", m.usernameInput.Value(), m.userPasswordInput.Value())).Run()
	printStatus("Passwords set")

	// Configure timezone
	exec.Command("ln", "-sf", fmt.Sprintf("/usr/share/zoneinfo/%s", m.timezoneChoice.SelectedItem().Title()), "/etc/localtime").Run()
	exec.Command("hwclock", "--systohc").Run()
	printStatus("Timezone configured")

	// Configure localization
	exec.Command("sh", "-c", "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen").Run()
	exec.Command("locale-gen").Run()
	exec.Command("sh", "-c", "echo 'LANG=en_US.UTF-8' > /etc/locale.conf").Run()
	printStatus("Localization configured")

	// Partitioning and formatting
	printStatus("Partitioning and formatting the disk...")
	switch m.partitionTypeChoice.SelectedItem().Title() {
	case "DOS (MBR)":
		exec.Command("parted", "/dev/sda", "--script", "mklabel", "msdos").Run()
		exec.Command("parted", "/dev/sda", "--script", "mkpart", "primary", "ext4", "1MiB", "100%").Run()
		exec.Command("mkfs.ext4", "/dev/sda1").Run()
		exec.Command("mount", "/dev/sda1", "/mnt").Run()
	case "GPT":
		exec.Command("parted", "/dev/sda", "--script", "mklabel", "gpt").Run()
		exec.Command("parted", "/dev/sda", "--script", "mkpart", "primary", "ext4", "1MiB", "100%").Run()
		exec.Command("mkfs.ext4", "/dev/sda1").Run()
		exec.Command("mount", "/dev/sda1", "/mnt").Run()
	case "EFI":
		exec.Command("parted", "/dev/sda", "--script", "mklabel", "gpt").Run()
		exec.Command("parted", "/dev/sda", "--script", "mkpart", "primary", "fat32", "1MiB", "512MiB").Run()
		exec.Command("parted", "/dev/sda", "--script", "set", "1", "esp", "on").Run()
		exec.Command("mkfs.fat", "-F32", "/dev/sda1").Run()
		exec.Command("parted", "/dev/sda", "--script", "mkpart", "primary", "ext4", "512MiB", "100%").Run()
		exec.Command("mkfs.ext4", "/dev/sda2").Run()
		exec.Command("mount", "/dev/sda2", "/mnt").Run()
		exec.Command("mkdir", "-p", "/mnt/boot/efi").Run()
		exec.Command("mount", "/dev/sda1", "/mnt/boot/efi").Run()
	}

	// Create and activate swap
	printStatus("Creating and activating swap...")
	exec.Command("fallocate", "-l", fmt.Sprintf("%dM", m.RAM_SIZE()+2048), "/mnt/swapfile").Run()
	exec.Command("chmod", "600", "/mnt/swapfile").Run()
	exec.Command("mkswap", "/mnt/swapfile").Run()
	exec.Command("swapon", "/mnt/swapfile").Run()

	// Install base system
	printStatus("Installing base system...")
	exec.Command("pacstrap", "/mnt", "base", "base-devel", "linux", "linux-firmware").Run()

	// Generate fstab
	printStatus("Generating fstab...")
	exec.Command("genfstab", "-U", "/mnt").Output()
	exec.Command("genfstab", "-U", "/mnt", ">>", "/mnt/etc/fstab").Output()

	// Chroot into the new system
	printStatus("Configuring the new system...")

	cmd := exec.Command("arch-chroot", "/mnt", "/bin/bash")
	cmd.Stdin = strings.NewReader(`

# Set up timezone
ln -sf /usr/share/zoneinfo/` + m.timezoneChoice.SelectedItem().Title() + ` /etc/localtime
hwclock --systohc

# Set up localization
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set up hostname
echo ` + m.hostnameInput.Value() + ` > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 ` + m.hostnameInput.Value() + `.localdomain ` + m.hostnameInput.Value() + `" >> /etc/hosts

# Set root password
echo "root:` + m.rootPasswordInput.Value() + `" | chpasswd

# Create a new user
useradd -m -G wheel ` + m.usernameInput.Value() + `
echo "` + m.usernameInput.Value() + `:` + m.userPasswordInput.Value() + `" | chpasswd
echo "` + m.usernameInput.Value() + ` ALL=(ALL) ALL" >> /etc/sudoers

# Install necessary packages
pacman -Syu --noconfirm
pacman -S --noconfirm base-devel linux-headers networkmanager

# Enable NetworkManager
systemctl enable NetworkManager

# Configure SSH server if selected
if [ "` + m.sshServerChoice.SelectedItem().Title() + `" == "Yes" ]; then
  pacman -S --noconfirm openssh
  systemctl enable sshd
  sed -i "s/#Port 22/Port ` + m.sshdPortInput.Value() + `/" /etc/ssh/sshd_config
  if [ "` + m.rootLoginChoice.SelectedItem().Title() + `" == "Yes" ]; then
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config
  else
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
  fi
  if [ "` + m.passwordLoginChoice.SelectedItem().Title() + `" == "Yes" ]; then
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
  else
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
  fi
fi

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
if [ "` + m.partitionTypeChoice.SelectedItem().Title() + `" == "EFI" ]; then
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
  grub-install --target=i386-pc /dev/sda
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Install selected software
for software in ` + strings.Join(m.selectedSoftware, " ") + `; do
  pacman -S --noconfirm $software
done

# Clean up
pacman -Scc --noconfirm

echo "Installation is complete. Please exit the chroot and reboot your system."

	`)
	cmd.Run()

	// Exit chroot, unmount and reboot if selected
	printStatus("Exiting chroot and unmounting...")
	exec.Command("umount", "-R", "/mnt").Run()

	if m.autoReboot {
		printStatus("Rebooting system...")
		exec.Command("reboot").Run()
	} else {
		printStatus("Installation complete. Please reboot the system.")
	}

	m.state = done
}

func main() {
	p := tea.NewProgram(initialModel())
	if err := p.Start(); err != nil {
		fmt.Printf("Alas, there's been an error: %v", err)
		os.Exit(1)
	}
}
