#!/bin/bash

# ---- SETTINGS ----
LOGFILE="/var/log/post_install_script.log"
TMP_DIR="/tmp/post_install_tmp"
INSTALL_OK="✅"
INSTALL_FAIL="❌"

# ---- CLEAN OUTPUT FUNCTIONS ----
info() { echo -e "\e[1;34m[INFO]\e[0m $1" >&3; }
success() { echo -e "\e[1;32m[SUCCESS]\e[0m $1" >&3; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&3; }

# ---- VERBOSE OR NOT ----
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE=true
    echo "Running in verbose mode (full output shown)."
else
    VERBOSE=false
    exec 3>&1 1>>"$LOGFILE" 2>&1
fi

# ---- BASIC SETUP ----
sudo apt update -qq
sudo apt install -y figlet lolcat curl wget flatpak gnome-software-plugin-flatpak snapd

mkdir -p "$TMP_DIR"
sudo touch "$LOGFILE"
sudo chmod 644 "$LOGFILE"

# ---- BANNER ----
clear
figlet -f slant "Pop!_OS Setup" | lolcat
info "Welcome to your Pop! Post Install Party!"

# ---- MENU ----
options=("Gaming Usage" "Work Usage" "Sysadmin Usage" "All of the Above")
select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
        CHOICE="$REPLY"
        break
    else
        error "Invalid option. Please select 1-${#options[@]}."
    fi
done

# ---- FUNCTIONS ----

check_success() {
    if [ $? -eq 0 ]; then
        success "Done!"
    else
        error "Error encountered! Check $LOGFILE."
    fi
}

install_dependencies() {
    info "Installing core dependencies and updates..."
    sudo apt update && sudo apt full-upgrade -y
    check_success

    info "Replacing PulseAudio with PipeWire..."
    sudo apt install -y pipewire pipewire-audio-client-libraries wireplumber libspa-0.2-bluetooth libspa-0.2-jack
    sudo apt remove -y pulseaudio pulseaudio-utils pulseaudio-module-bluetooth
    check_success

    sudo apt install -y conky-all lm-sensors
    check_success
}

install_gaming() {
    info "🎮 Setting up Gaming Environment..."

    info "Installing Spotify and Discord..."
    sudo snap install spotify discord
    check_success

    info "Installing Zen Browser (Brave)..."
    sudo apt install -y brave-browser
    check_success

    info "Installing Steam via Flatpak..."
    flatpak install -y flathub com.valvesoftware.Steam
    check_success

    info "Installing Lutris..."
    sudo add-apt-repository -y ppa:lutris-team/lutris
    sudo apt update -qq
    sudo apt install -y lutris
    check_success

    info "Installing Heroic Games Launcher..."
    flatpak install -y flathub com.heroicgameslauncher.hgl
    check_success

    info "Installing Gnome Tweaks, OpenRGB, Fan Control..."
    sudo apt install -y gnome-tweaks fancontrol openrgb
    check_success

    info "Installing Parsec via Flatpak..."
    flatpak install -y flathub com.parsecgaming.parsec
    check_success
}

install_work() {
    info "💼 Setting up Work Environment..."

    info "Installing Cohesion, Spotify, and Signal..."
    sudo snap install cohesion-desktop spotify signal-desktop
    check_success

    info "Installing Zen Browser (Brave)..."
    sudo apt install -y brave-browser
    check_success

    info "Installing OnlyOffice..."
    sudo apt install -y onlyoffice-desktopeditors
    check_success

    info "Installing Proton Suite via Flatpak..."
    flatpak install -y ch.protonmail.protonmail-bridge ch.protonmail.proton-drive org.freedesktop.Piper
    check_success
}

install_sysadmin() {
    info "🛠️ Setting up Sysadmin Environment..."

    info "Installing Winbox via Snap..."
    sudo snap install winbox
    check_success

    info "Installing Burp Suite Community via Flatpak..."
    flatpak install -y com.burpsuite.BurpSuiteCommunity
    check_success

    info "Pre-configuring Wireshark to install non-interactively..."
    echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections

    info "Installing Nmap and Wireshark..."
    sudo apt install -y nmap wireshark
    check_success

    info "Installing Docker and VirtualBox..."
    sudo apt install -y docker.io virtualbox
    check_success

    info "Setting up Portainer container..."
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data \
        portainer/portainer-ce
    check_success
}

cleanup() {
    info "🧹 Cleaning up temp files..."
    rm -rf "$TMP_DIR"
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

info "🎉 All selected packages installed! Rebooting in 10 seconds..."
sleep 10
sudo reboot
