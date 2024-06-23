package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/textinput"
)

type state int

const (
	askHostname state = iota
	askUsername
	askRootPassword
	askUserPassword
	askTimezone
	askPartitionType
	askAutoReboot
	askSSHServer
	askSSHDPort
	askRootLogin
	askPasswordLogin
	askSoftware
	confirm
	done
)

type item struct {
	title, desc string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.desc }
func (i item) FilterValue() string { return i.title }

type model struct {
	state              state
	hostnameInput      textinput.Model
	usernameInput      textinput.Model
	rootPasswordInput  textinput.Model
	userPasswordInput  textinput.Model
	timezoneChoice     list.Model
	partitionTypeChoice list.Model
	autoRebootChoice   list.Model
	sshServerChoice    list.Model
	sshdPortInput      textinput.Model
	rootLoginChoice    list.Model
	passwordLoginChoice list.Model
	softwareChoice     list.Model
	selectedSoftware   []string
	autoReboot         bool
}

func initialModel() model {
	hostnameInput := textinput.New()
	hostnameInput.Placeholder = "Hostname"
	hostnameInput.Focus()

	usernameInput := textinput.New()
	usernameInput.Placeholder = "Username"

	rootPasswordInput := textinput.New()
	rootPasswordInput.Placeholder = "Root Password"
	rootPasswordInput.EchoMode = textinput.EchoPassword

	userPasswordInput := textinput.New()
	userPasswordInput.Placeholder = "User Password"
	userPasswordInput.EchoMode = textinput.EchoPassword

	timezones := []list.Item{
		item{title: "America/New_York"},
		item{title: "Europe/London"},
		item{title: "Asia/Tokyo"},
		item{title: "Other"},
	}
	timezoneChoice := list.New(timezones, list.NewDefaultDelegate(), 0, 0)
	timezoneChoice.Title = "Select Timezone"

	partitionTypes := []list.Item{
		item{title: "DOS (MBR)"},
		item{title: "GPT"},
		item{title: "EFI"},
	}
	partitionTypeChoice := list.New(partitionTypes, list.NewDefaultDelegate(), 0, 0)
	partitionTypeChoice.Title = "Select Partition Type"

	yesNoOptions := []list.Item{
		item{title: "Yes"},
		item{title: "No"},
	}
	autoRebootChoice := list.New(yesNoOptions, list.NewDefaultDelegate(), 0, 0)
	autoRebootChoice.Title = "Auto Reboot"

	sshServerChoice := list.New(yesNoOptions, list.NewDefaultDelegate(), 0, 0)
	sshServerChoice.Title = "Configure SSH Server"

	sshdPortInput := textinput.New()
	sshdPortInput.Placeholder = "SSH Port (default is 22)"
	sshdPortInput.SetValue("22")

	rootLoginChoice := list.New(yesNoOptions, list.NewDefaultDelegate(), 0, 0)
	rootLoginChoice.Title = "Allow Root Login via SSH"

	passwordLoginChoice := list.New(yesNoOptions, list.NewDefaultDelegate(), 0, 0)
	passwordLoginChoice.Title = "Allow Password Login via SSH"

	softwareOptions := []list.Item{
		item{title: "Oh My Zsh"},
		item{title: "Kitty"},
		item{title: "Firefox"},
		item{title: "OSS Codium"},
		item{title: "Git"},
		item{title: "Vim"},
		item{title: "AUR Support"},
		item{title: "Mullvad VPN (AUR)"},
		item{title: "VirtualBox"},
		item{title: "Gnome Tweaks"},
		item{title: "Eye of GNOME (eog)"},
		item{title: "Fonts"},
		item{title: "LibreOffice"},
		item{title: "GIMP"},
		item{title: "Inkscape"},
		item{title: "GNOME Calendar"},
		item{title: "GNOME Weather"},
		item{title: "Evolution (Email Client)"},
		item{title: "Docker"},
		item{title: "Node.js"},
		item{title: "Python"},
		item{title: "JDK (Java Development Kit)"},
		item{title: "IntelliJ IDEA Community Edition"},
		item{title: "gnome-calculator"},
		item{title: "evince (Document Viewer)"},
		item{title: "gnome-disk-utility"},
		item{title: "nautilus (Files)"},
		item{title: "gnome-screenshot"},
		item{title: "gnome-control-center"},
		item{title: "gnome-text-editor"},
		item{title: "aria2"},
		item{title: "zsh-autosuggestions"},
		item{title: "zsh-syntax-highlighting"},
		item{title: "VLC Media Player"},
		item{title: "MPV Media Player"},
		item{title: "Spotify (AUR)"},
		item{title: "Audacity"},
		item{title: "Double Commander"},
		item{title: "Discord (AUR)"},
		item{title: "Slack (AUR)"},
		item{title: "Zoom (AUR)"},
		item{title: "Htop"},
		item{title: "Neofetch"},
		item{title: "GNOME System Monitor"},
		item{title: "GNOME Usage"},
		item{title: "Google Chrome (AUR)"},
		item{title: "Brave Browser (AUR)"},
		item{title: "OpenSSH"},
		item{title: "NetworkManager"},
		item{title: "Papirus Icon Theme"},
		item{title: "Arc GTK Theme"},
	}
	softwareChoice := list.New(softwareOptions, list.NewDefaultDelegate(), 0, 0)
	softwareChoice.Title = "Select Software to Install"

	return model{
		state:              askHostname,
		hostnameInput:      hostnameInput,
		usernameInput:      usernameInput,
		rootPasswordInput:  rootPasswordInput,
		userPasswordInput:  userPasswordInput,
		timezoneChoice:     timezoneChoice,
		partitionTypeChoice: partitionTypeChoice,
		autoRebootChoice:   autoRebootChoice,
		sshServerChoice:    sshServerChoice,
		sshdPortInput:      sshdPortInput,
		rootLoginChoice:    rootLoginChoice,
		passwordLoginChoice: passwordLoginChoice,
		softwareChoice:     softwareChoice,
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
				m.timezoneChoice.SetFilter(choice.Title())
			} else {
				m.state = askPartitionType
			}
		}
	case askPartitionType:
		m.partitionTypeChoice, cmd = m.partitionTypeChoice.Update(msg)
		if choice := m.partitionTypeChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.state = askAutoReboot
		}
	case askAutoReboot:
		m.autoRebootChoice, cmd = m.autoRebootChoice.Update(msg)
		if choice := m.autoRebootChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			m.autoReboot = choice.Title() == "Yes"
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
		if choice := m.softwareChoice.SelectedItem(); choice != nil && (msg == tea.KeyEnter || msg == tea.KeyTab) {
			if !contains(m.selectedSoftware, choice.Title()) {
				m.selectedSoftware = append(m.selectedSoftware, choice.Title())
			}
			if msg == tea.KeyEnter {
				m.state = confirm
			}
		}
	case confirm:
		m.state = done
		go m.performInstallation()
	case done:
		os.Exit(0)
	}

	return m, cmd
}

func (m model) View() string {
	switch m.state {
	case askHostname:
		return fmt.Sprintf(
			"What is your hostname?\n\n%s\n\nPress Enter to confirm.",
			m.hostnameInput.View(),
		)
	case askUsername:
		return fmt.Sprintf(
			"What is your username?\n\n%s\n\nPress Enter to confirm.",
			m.usernameInput.View(),
		)
	case askRootPassword:
		return fmt.Sprintf(
			"Enter your root password:\n\n%s\n\nPress Enter to confirm.",
			m.rootPasswordInput.View(),
		)
	case askUserPassword:
		return fmt.Sprintf(
			"Enter your user password:\n\n%s\n\nPress Enter to confirm.",
			m.userPasswordInput.View(),
		)
	case askTimezone:
		return m.timezoneChoice.View()
	case askPartitionType:
		return m.partitionTypeChoice.View()
	case askAutoReboot:
		return m.autoRebootChoice.View()
	case askSSHServer:
		return m.sshServerChoice.View()
	case askSSHDPort:
		return fmt.Sprintf(
			"Enter the SSH port (default is 22):\n\n%s\n\nPress Enter to confirm.",
			m.sshdPortInput.View(),
		)
	case askRootLogin:
		return m.rootLoginChoice.View()
	case askPasswordLogin:
		return m.passwordLoginChoice.View()
	case askSoftware:
		return m.softwareChoice.View()
	case confirm:
		return "Installation in progress...\n\n"
	case done:
		return "Installation complete. Please reboot your system.\n\n"
	}
	return ""
}

func (m *model) performInstallation() {
	hostname := m.hostnameInput.Value()
	username := m.usernameInput.Value()
	rootPassword := m.rootPasswordInput.Value()
	userPassword := m.userPasswordInput.Value()
	timezone := m.timezoneChoice.SelectedItem().Title()
	partitionType := m.partitionTypeChoice.SelectedItem().Title()
	sshServer := m.sshServerChoice.SelectedItem().Title() == "Yes"
	sshPort := m.sshdPortInput.Value()
	rootLogin := m.rootLoginChoice.SelectedItem().Title() == "Yes"
	passwordLogin := m.passwordLoginChoice.SelectedItem().Title() == "Yes"
	autoReboot := m.autoReboot

	// Set up timezone
	exec.Command("/bin/sh", "-c", fmt.Sprintf("ln -sf /usr/share/zoneinfo/%s /etc/localtime && hwclock --systohc", timezone)).Run()

	// Set up localization
	exec.Command("/bin/sh", "-c", "echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen && echo 'LANG=en_US.UTF-8' > /etc/locale.conf").Run()

	// Set up hostname
	exec.Command("/bin/sh", "-c", fmt.Sprintf("echo '%s' > /etc/hostname && echo '127.0.0.1 localhost' >> /etc/hosts && echo '::1 localhost' >> /etc/hosts && echo '127.0.1.1 %s.localdomain %s' >> /etc/hosts", hostname, hostname, hostname)).Run()

	// Set root password
	exec.Command("/bin/sh", "-c", fmt.Sprintf("echo 'root:%s' | chpasswd", rootPassword)).Run()

	// Create a new user
	exec.Command("/bin/sh", "-c", fmt.Sprintf("useradd -m -G wheel %s && echo '%s:%s' | chpasswd && echo '%s ALL=(ALL) ALL' >> /etc/sudoers", username, username, userPassword, username)).Run()

	// Install necessary packages
	exec.Command("/bin/sh", "-c", "pacman -Syu --noconfirm && pacman -S --noconfirm base-devel linux-headers networkmanager").Run()

	// Enable NetworkManager
	exec.Command("/bin/sh", "-c", "systemctl enable NetworkManager").Run()

	// Configure SSH server if selected
	if sshServer {
		exec.Command("/bin/sh", "-c", "pacman -S --noconfirm openssh && systemctl enable sshd").Run()
		exec.Command("/bin/sh", "-c", fmt.Sprintf("sed -i 's/#Port 22/Port %s/' /etc/ssh/sshd_config", sshPort)).Run()
		if rootLogin {
			exec.Command("/bin/sh", "-c", "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config").Run()
		} else {
			exec.Command("/bin/sh", "-c", "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config").Run()
		}
		if passwordLogin {
			exec.Command("/bin/sh", "-c", "sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config").Run()
		} else {
			exec.Command("/bin/sh", "-c", "sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config").Run()
		}
	}

	// Install and configure bootloader
	exec.Command("/bin/sh", "-c", "pacman -S --noconfirm grub efibootmgr").Run()
	if partitionType == "EFI" {
		exec.Command("/bin/sh", "-c", "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB").Run()
	} else {
		exec.Command("/bin/sh", "-c", "grub-install --target=i386-pc /dev/sda").Run()
	}
	exec.Command("/bin/sh", "-c", "grub-mkconfig -o /boot/grub/grub.cfg").Run()

	// Install selected software
	for _, software := range m.selectedSoftware {
		exec.Command("/bin/sh", "-c", fmt.Sprintf("pacman -S --noconfirm %s", software)).Run()
	}

	// Clean up
	exec.Command("/bin/sh", "-c", "pacman -Scc --noconfirm").Run()

	if autoReboot {
		exec.Command("/bin/sh", "-c", "reboot").Run()
	} else {
		fmt.Println("Installation complete. Please reboot the system.")
	}
}

func contains(slice []string, item string) bool {
	for _, v := range slice {
		if v == item {
			return true
		}
	}
	return false
}

func main() {
	m := initialModel()
	if err := tea.NewProgram(&m).Start(); err != nil {
		fmt.Printf("Alas, there's been an error: %v", err)
		os.Exit(1)
	}
}