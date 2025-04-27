#!/bin/bash

# ---- SETTINGS ----
LOGFILE="/var/log/post_install_script.log"
TMP_DIR="/tmp/post_install_tmp"
INSTALL_OK="✅"
INSTALL_FAIL="❌"

# ---- COLORS ----
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# ---- CLEAN OUTPUT FUNCTIONS ----
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- VERBOSE OR NOT ----
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE=true
    echo "Running in verbose mode (full output shown)."
else
    VERBOSE=false
    exec 3>&1 1>>"$LOGFILE" 2>&1
fi

# ---- REQUIREMENTS CHECK ----
sudo apt update -qq
sudo apt install -y figlet lolcat curl wget flatpak gnome-software-plugin-flatpak snapd libnotify-bin dbus ntpdate > /dev/null 2>&1

mkdir -p "$TMP_DIR"
sudo touch "$LOGFILE"
sudo chmod 644 "$LOGFILE"

# ---- SPINNER FUNCTION ----
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ---- NOTIFICATION FUNCTION ----
notify() {
    notify-send -u normal "Pop! Installer" "$1"
}

# ---- BANNER ----
clear
figlet -f slant "Pop!_OS Setup" | lolcat
info "Welcome to your Pop! Post Install Party!"

# ---- TIME SYNC FUNCTION ----
info "🌐 Syncing system time with NTP..."
notify "Syncing system time..."

(sudo timedatectl set-ntp true && sudo ntpdate -u pool.ntp.org) & spinner

check_success
notify "System time synced ✅"

# ---- MENU ----
clear
echo -e "${BLUE}Please select an option below:${NC}"

options=("Gaming Usage" "Work Usage" "Sysadmin Usage" "All of the Above")
select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
        CHOICE="$REPLY"
        break
    else
        error "Invalid option. Please select 1-${#options[@]}."
    fi
done

# ---- CORE FUNCTIONS ----

check_success() {
    if [ $? -eq 0 ]; then
        success "Done!"
    else
        error "Error encountered! Check $LOGFILE."
    fi
}

install_dependencies() {
    info "🔄 Updating system packages..."
    notify "Updating system packages..."

    (sudo apt update -y && sudo apt full-upgrade -y) & spinner

    check_success
    notify "System update complete ✅"

    info "Replacing PulseAudio with PipeWire..."
    notify "Replacing PulseAudio with PipeWire..."

    (sudo apt install -y pipewire pipewire-audio-client-libraries wireplumber libspa-0.2-bluetooth libspa-0.2-jack \
        && sudo apt remove -y pulseaudio pulseaudio-utils pulseaudio-module-bluetooth) & spinner

    check_success
    notify "PipeWire set up successfully 🎵"

    info "Installing Conky + lm-sensors..."
    (sudo apt install -y conky-all lm-sensors) & spinner
    check_success
}

install_gaming() {
    info "🎮 Setting up Gaming Environment..."
    notify "Installing Gaming Environment..."

    info "Installing Spotify and Discord..."
    (sudo snap install spotify discord) & spinner
    check_success

    info "Installing Zen Browser..."
    (sudo apt install -y zen-browser) & spinner
    check_success

    info "Installing Steam via Flatpak..."
    (flatpak install -y flathub com.valvesoftware.Steam) & spinner
    check_success

    info "Installing Lutris..."
    (sudo add-apt-repository -y ppa:lutris-team/lutris && sudo apt update && sudo apt install -y lutris) & spinner
    check_success

    info "Installing Heroic Games Launcher..."
    (flatpak install -y flathub com.heroicgameslauncher.hgl) & spinner
    check_success

    info "Installing Gnome Tweaks, Fan Control, OpenRGB..."
    (sudo apt install -y gnome-tweaks fancontrol openrgb) & spinner
    check_success

    info "Installing Parsec via Flatpak..."
    (flatpak install -y flathub com.parsecgaming.parsec) & spinner
    check_success
}

install_work() {
    info "💼 Setting up Work Environment..."
    notify "Installing Work Environment..."

    info "Installing Cohesion, Spotify, Signal..."
    (sudo snap install cohesion-desktop spotify signal-desktop) & spinner
    check_success

    info "Installing Zen Browser..."
    (sudo apt install -y zen-browser) & spinner
    check_success

    info "Installing OnlyOffice..."
    (sudo apt install -y onlyoffice-desktopeditors) & spinner
    check_success

    info "Installing Proton Suite via Flatpak..."
    (flatpak install -y ch.protonmail.protonmail-bridge ch.protonmail.proton-drive org.freedesktop.Piper) & spinner
    check_success
}

install_sysadmin() {
    info "🛠️ Setting up Sysadmin Environment..."
    notify "Installing Sysadmin Environment..."

    info "Installing Winbox via Snap..."
    (sudo snap install winbox) & spinner
    check_success

    info "Installing Burp Suite Community via Flatpak..."
    (flatpak install -y com.burpsuite.BurpSuiteCommunity) & spinner
    check_success

    info "Pre-configuring Wireshark to install non-interactively..."
    echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections

    info "Installing Nmap and Wireshark..."
    (sudo apt install -y nmap wireshark) & spinner
    check_success

    info "Installing Docker and VirtualBox..."
    (sudo apt install -y docker.io virtualbox) & spinner
    check_success

    info "Setting up Portainer container..."
    (sudo docker volume create portainer_data && \
    sudo docker run -d -p 9000:9000 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
        portainer/portainer-ce) & spinner
    check_success
}

cleanup() {
    info "🧹 Cleaning up temp files..."
    (rm -rf "$TMP_DIR") & spinner
    check_success
}

# ---- MAIN LOGIC ----

install_dependencies

case $CHOICE in
    1)
        install_gaming
        ;;
    2)
        install_work
        ;;
    3)
        install_sysadmin
        ;;
    4)
        install_gaming
        install_work
        install_sysadmin
        ;;
    *)
        error "Invalid option"
        exit 1
        ;;
esac

cleanup

notify "🎉 All selected packages installed! System will reboot soon!"
info "🎉 All done! Rebooting in 10 seconds..."
sleep 10
sudo reboot
#!/bin/bash

# ---- SETTINGS ----
LOGFILE="/var/log/post_install_script.log"
TMP_DIR="/tmp/post_install_tmp"
INSTALL_OK="✅"
INSTALL_FAIL="❌"

# ---- COLORS ----
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# ---- CLEAN OUTPUT FUNCTIONS ----
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- VERBOSE OR NOT ----
VERBOSE=false
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE=true
    echo "Running in verbose mode (full output shown)."
else
    exec 3>&1 1>>"$LOGFILE" 2>&1
fi

# ---- REQUIREMENTS CHECK ----
info "🔄 Updating system packages..."
sudo apt update -qq && sudo apt install -y figlet lolcat curl wget flatpak gnome-software-plugin-flatpak snapd libnotify-bin dbus ntpdate > /dev/null 2>&1
sudo touch "$LOGFILE"
sudo chmod 644 "$LOGFILE"
mkdir -p "$TMP_DIR"

check_success() {
    if [ $? -eq 0 ]; then
        success "Done!"
    else
        error "Error encountered! Check $LOGFILE."
    fi
}

# ---- TIME SYNC FUNCTION ----
info "🌐 Syncing system time with NTP..."
(sudo timedatectl set-ntp true && sudo ntpdate -u pool.ntp.org) & spinner

check_success

# ---- MENU ----
clear
figlet -f slant "Pop!_OS Setup" | lolcat
info "Welcome to your Pop! Post Install Party!"

echo -e "${BLUE}Please select an option below:${NC}"
options=("Gaming Usage" "Work Usage" "Sysadmin Usage" "All of the Above")
select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
        CHOICE="$REPLY"
        break
    else
        error "Invalid option. Please select 1-${#options[@]}."
    fi
done

# ---- CORE FUNCTIONS ----
install_dependencies() {
    info "🌐 Installing required dependencies..."
    (sudo apt install -y pipewire pipewire-audio-client-libraries wireplumber libspa-0.2-bluetooth libspa-0.2-jack \
        && sudo apt remove -y pulseaudio pulseaudio-utils pulseaudio-module-bluetooth) & spinner
    check_success
}

install_gaming() {
    info "🎮 Setting up Gaming Environment..."
    notify "Installing Gaming Environment..."

    info "Installing Spotify and Discord..."
    (sudo snap install spotify discord) & spinner
    check_success

    info "Installing Zen Browser..."
    (sudo apt install -y zen-browser) & spinner
    check_success

    info "Installing Steam via Flatpak..."
    (flatpak install -y flathub com.valvesoftware.Steam) & spinner
    check_success

    info "Installing Lutris..."
    (sudo add-apt-repository -y ppa:lutris-team/lutris && sudo apt update && sudo apt install -y lutris) & spinner
    check_success

    info "Installing Heroic Games Launcher..."
    (flatpak install -y flathub com.heroicgameslauncher.hgl) & spinner
    check_success

    info "Installing Gnome Tweaks, Fan Control, OpenRGB..."
    (sudo apt install -y gnome-tweaks fancontrol openrgb) & spinner
    check_success

    info "Installing Parsec via Flatpak..."
    (flatpak install -y flathub com.parsecgaming.parsec) & spinner
    check_success
}

install_work() {
    info "💼 Setting up Work Environment..."
    notify "Installing Work Environment..."

    info "Installing Cohesion, Spotify, Signal..."
    (sudo snap install cohesion-desktop spotify signal-desktop) & spinner
    check_success

    info "Installing Zen Browser..."
    (sudo apt install -y zen-browser) & spinner
    check_success

    info "Installing OnlyOffice..."
    (sudo apt install -y onlyoffice-desktopeditors) & spinner
    check_success

    info "Installing Proton Suite via Flatpak..."
    (flatpak install -y ch.protonmail.protonmail-bridge ch.protonmail.proton-drive org.freedesktop.Piper) & spinner
    check_success
}

install_sysadmin() {
    info "🛠️ Setting up Sysadmin Environment..."
    notify "Installing Sysadmin Environment..."

    info "Installing Winbox via Snap..."
    (sudo snap install winbox) & spinner
    check_success

    info "Installing Burp Suite Community via Flatpak..."
    (flatpak install -y com.burpsuite.BurpSuiteCommunity) & spinner
    check_success

    info "Pre-configuring Wireshark to install non-interactively..."
    echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections

    info "Installing Nmap and Wireshark..."
    (sudo apt install -y nmap wireshark) & spinner
    check_success

    info "Installing Docker and VirtualBox..."
    (sudo apt install -y docker.io virtualbox) & spinner
    check_success

    info "Setting up Portainer container..."
    (sudo docker volume create portainer_data && \
    sudo docker run -d -p 9000:9000 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
        portainer/portainer-ce) & spinner
    check_success
}

cleanup() {
    info "🧹 Cleaning up temp files..."
    (rm -rf "$TMP_DIR") & spinner
    check_success
}

# ---- MAIN LOGIC ----

install_dependencies

case $CHOICE in
    1)
        install_gaming
        ;;
    2)
        install_work
        ;;
    3)
        install_sysadmin
        ;;
    4)
        install_gaming
        install_work
        install_sysadmin
        ;;
    *)
        error "Invalid option"
        exit 1
        ;;
esac

cleanup

notify "🎉 All selected packages installed! System will reboot soon!"
info "🎉 All done! Rebooting in 10 seconds..."
sleep 10
sudo reboot
