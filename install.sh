#!/bin/bash

# ---- SETTINGS ----
LOGFILE="/var/log/post_install_script.log"

# ---- BASIC SETUP ----
echo "Setting up basic tools..."
sudo apt update -qq
sudo apt install -y figlet lolcat curl wget flatpak gnome-software-plugin-flatpak snapd

# Create log if not existing
sudo touch "$LOGFILE"
sudo chmod 644 "$LOGFILE"

# ---- LOGGING ----
VERBOSE=false
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE=true
    echo "Running in verbose mode (full output shown)."
else
    echo "Running in quiet mode. Errors logged to $LOGFILE."
    exec > >(tee -a "$LOGFILE") 2>&1
fi

# ---- INSTALL MENU ----
echo "" | figlet -f slant "Pop!_OS Setup" | lolcat
echo -e "\e[1;35mPost-Install Configuration Menu\e[0m"

options=("Gaming Usage" "Work Usage" "Sysadmin Usage" "All of the Above")
select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
        CHOICE="$REPLY"
        break
    else
        echo "Invalid option. Please select 1-${#options[@]}."
    fi
done

# ---- FUNCTIONS ----

install_dependencies() {
    echo "Installing core dependencies..."
    sudo apt update && sudo apt full-upgrade -y
    sudo apt install -y pipewire pipewire-audio-client-libraries wireplumber libspa-0.2-bluetooth libspa-0.2-jack
    sudo apt remove -y pulseaudio pulseaudio-utils pulseaudio-module-bluetooth
    sudo apt install -y conky-all lm-sensors
}

install_gaming() {
    echo "Installing Gaming Environment..."
    sudo snap install spotify discord
    sudo apt install -y brave-browser
    flatpak install -y flathub com.valvesoftware.Steam
    sudo add-apt-repository -y ppa:lutris-team/lutris
    sudo apt update -qq
    sudo apt install -y lutris
    flatpak install -y flathub com.heroicgameslauncher.hgl
    sudo apt install -y gnome-tweaks fancontrol openrgb
    flatpak install -y flathub com.parsecgaming.parsec
}

install_work() {
    echo "Installing Work Environment..."
    sudo snap install cohesion-desktop spotify signal-desktop
    sudo apt install -y brave-browser
    flatpak install -y flathub com.valvesoftware.Steam
    sudo apt install -y conky-all onlyoffice-desktopeditors
    sudo snap install protonvpn
}

install_sysadmin() {
    echo "Installing Sysadmin Environment..."
    sudo snap install winbox
    wget -O jetbrains-toolbox.tar.gz "https://download.jetbrains.com/toolbox/jetbrains-toolbox-1.27.2.12534.tar.gz"
    tar -xzf jetbrains-toolbox.tar.gz -C /tmp
    /tmp/jetbrains-toolbox*/jetbrains-toolbox --no-sandbox &
    sudo apt install -y nmap wireshark
    wget -O ~/burpsuite-community.sh "https://portswigger-cdn.net/burp/releases/download?product=community&version=2025.3&type=Linux" && chmod +x ~/burpsuite-community.sh && bash ~/burpsuite-community.sh
    sudo apt install -y docker.io virtualbox
    sudo docker volume create portainer_data
    sudo docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
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
        echo "Invalid option"
        exit 1
        ;;
esac

echo "✨ All selected packages installed. Rebooting in 10 seconds..."
sleep 10
sudo reboot
