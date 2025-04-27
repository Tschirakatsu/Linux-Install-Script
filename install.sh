#!/usr/bin/env bash

# ========================================
#  Pop!_OS/Ubuntu Post-Install Script v4.0
# ========================================

# ---- SETTINGS ----
LOGFILE="/var/log/post_install_script.log"
TMP_DIR="/tmp/post_install_tmp"

# ---- COLORS ----
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
NC="\033[0m"  # No Color

# ---- HELPER FUNCTIONS ----
info()    { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; exit 1; }

# Spinner: show while last background job runs
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='-|/\\'
    while kill -0 "$pid" 2>/dev/null; do
        for char in "+" "-"; do
            printf " [%c]  " "$char"
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
    done
    printf "     \b\b\b\b\b\r"
}

# Run a command with info, spinner, and success check
run() {
    info "$1..."
    bash -c "$1" & spinner
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "Failed: $1"
    fi
}

# Notification helper as real user
notify_user() {
    if [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SUDO_USER")/bus" \
            notify-send "Pop!_Installer" "$1"
    else
        notify-send "Pop!_Installer" "$1"
    fi
}

# Check for verbose flag
VERBOSE=false
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE=true
    exec > >(tee -a "$LOGFILE") 2>&1
else
    # Quiet: only errors to logfile
    exec 2>>"$LOGFILE"
fi

# Ensure log file exists
sudo mkdir -p "$(dirname "$LOGFILE")"
sudo touch "$LOGFILE"
sudo chmod 644 "$LOGFILE"

# Create temp dir
mkdir -p "$TMP_DIR"

# ---- INSTALL BASE DEPENDENCIES ----
run "sudo apt update -qq"
run "sudo apt install -y ntpdate dbus figlet lolcat curl wget flatpak gnome-software-plugin-flatpak snapd libnotify-bin"

# ---- SYNC TIME ----
run "sudo timedatectl set-ntp true"
run "sudo ntpdate -u pool.ntp.org"
notify_user "System time synced"

# ---- BANNER ----
clear
figlet -f slant "Pop!_OS Setup" | lolcat
info "Welcome to your Pop! Post Install Party!"

# ---- MENU ----
echo -e "${BLUE}Select installation profile:${NC}"
echo " 1) Gaming Usage"
echo " 2) Work Usage"
echo " 3) Sysadmin Usage"
echo " 4) All of the Above"

while true; do
    read -rp "Choose [1-4]: " CHOICE
    case "$CHOICE" in
        1|2|3|4) break;;
        *) echo "Invalid choice, try 1-4.";;
    esac
done

# ---- INSTALL FUNCTIONS ----

# Install AMD GPU & CPU drivers (for Ryzen 7 7800X3D)
install_amd_drivers() {
    run "sudo apt install -y linux-headers-$(uname -r)"
    run "sudo apt install -y amdgpu-pro"
}

install_dependencies() {
    run "sudo apt install -y pipewire pipewire-audio-client-libraries wireplumber libspa-0.2-bluetooth libspa-0.2-jack"
    run "sudo apt remove -y pulseaudio pulseaudio-utils pulseaudio-module-bluetooth"
    run "sudo apt install -y easyeffects"
    run "sudo apt install -y conky-all lm-sensors"
}

install_gaming() {
    notify_user "Starting Gaming environment install"
    run "sudo snap install spotify discord"
    run "sudo apt install -y zen-browser"
    run "flatpak install -y flathub com.valvesoftware.Steam"
    run "sudo add-apt-repository -y ppa:lutris-team/lutris && sudo apt update && sudo apt install -y lutris"
    run "flatpak install -y flathub com.heroicgameslauncher.hgl"
    run "sudo apt install -y gnome-tweaks fancontrol openrgb"
    run "flatpak install -y flathub com.parsecgaming.parsec"
}

install_work() {
    notify_user "Starting Work environment install"
    run "sudo snap install cohesion-desktop spotify signal-desktop"
    run "sudo apt install -y zen-browser"
    run "sudo apt install -y onlyoffice-desktopeditors"
    run "flatpak install -y flathub ch.protonmail.protonmail-bridge ch.protonmail.proton-drive org.freedesktop.Piper"
}

install_sysadmin() {
    notify_user "Starting Sysadmin environment install"
    run "sudo snap install winbox"
    run "flatpak install -y flathub com.burpsuite.BurpSuiteCommunity"
    run "echo 'wireshark-common wireshark-common/install-setuid boolean true' | sudo debconf-set-selections"
    run "sudo apt install -y nmap wireshark"
    run "sudo apt install -y docker.io virtualbox"
    run "sudo docker volume create portainer_data && sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce"
}

cleanup() {
    run "rm -rf '$TMP_DIR'"
}

# ---- MAIN LOGIC ----
install_dependencies
install_amd_drivers  # Install AMD drivers
case "$CHOICE" in
    1) install_gaming ;; 2) install_work ;; 3) install_sysadmin ;; 4)
        install_gaming
        install_work
        install_sysadmin
        ;;
esac

cleanup
notify_user "All installations complete. Rebooting in 10s"
info "Rebooting in 10 seconds..."
sleep 10
sudo reboot
