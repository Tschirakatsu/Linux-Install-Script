#!/bin/bash
# Ultimate Pop!_OS Setup Script with Profiles, Hardening & Pro Tweaks
# Prioritizes Flatpak installs, dual logging, error handling
# Run as root (sudo su) and optionally pass --quiet for minimal output

# --- Log files ---
USER_LOG="/var/log/ultimate_setup.log"
VERBOSE_LOG="/var/log/ultimate_setup_verbose.log"
touch "$USER_LOG" "$VERBOSE_LOG"
echo "=== Ultimate Setup started at $(date) ===" >> "$USER_LOG"
echo "=== $(date) ===" >> "$VERBOSE_LOG"

# --- Logging functions ---
log() {
  echo "$(date '+%F %T') - $1" | tee -a "$USER_LOG"
}
log_verbose() {
  echo "$(date '+%F %T') - $1" >> "$VERBOSE_LOG"
}

# --- Root / Verbose check ---
if [[ "$EUID" -ne 0 ]]; then
  log "❌ Must run as root (sudo su)"
  exit 1
fi

verbose=true
if [[ "$1" == "--quiet" ]]; then
  verbose=false
fi

print_msg() {
  $verbose && echo -e "$1"
}

# --- Initial system update ---
log "Updating package lists (APT)..."
apt-get update >>"$VERBOSE_LOG" 2>&1
if [[ $? -eq 0 ]]; then log "APT update succeeded"; else log "APT update failed"; fi

log "Upgrading packages (APT)..."
apt-get upgrade -y >>"$VERBOSE_LOG" 2>&1
if [[ $? -eq 0 ]]; then log "APT upgrade succeeded"; else log "APT upgrade failed"; fi

# --- Flatpak setup ---
if ! command -v flatpak &>/dev/null; then
  log "Flatpak not found, installing..."
  apt-get install -y flatpak >>"$VERBOSE_LOG" 2>&1
  if [[ $? -eq 0 ]]; then log "Flatpak installed"; else log "Flatpak install failed"; fi
fi

if ! flatpak remote-list | grep -q flathub; then
  log "Adding Flathub repository..."
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >>"$VERBOSE_LOG" 2>&1
  if [[ $? -eq 0 ]]; then log "Flathub added"; else log "Adding Flathub failed"; fi
fi

# --- Helper: Flatpak first, fallback APT ---
install_app() {
  local name="$1"
  local fpkg="$2"
  local apk="$3"
  log "Processing $name..."

  # If no package targets provided, skip
  if [ -z "$fpkg" ] && [ -z "$apk" ]; then
    log "No installation targets for $name, skipping."
    return
  fi

  # Flatpak check & install
  if [ -n "$fpkg" ]; then
    if flatpak info "$fpkg" >/dev/null 2>&1; then
      log "$name (Flatpak) already installed"
      return
    fi
    log_verbose "Attempting Flatpak install: $fpkg"
    if flatpak install flathub "$fpkg" -y >>"$VERBOSE_LOG" 2>&1; then
      log "$name installed via Flatpak"
      return
    else
      log "$name Flatpak install failed, will try APT"
    fi
  fi

  # APT fallback
  if [ -n "$apk" ]; then
    if dpkg -s "$apk" >/dev/null 2>&1; then
      log "$name (APT) already installed"
    else
      log "Installing $name via APT..."
      if apt-get install -y "$apk" >>"$VERBOSE_LOG" 2>&1; then
        log "$name installed via APT"
      else
        log "Error installing $name via APT"
      fi
    fi
  fi
}

# --- Proton Suite ---
install_proton_suite() {
  log "Installing ProtonVPN CLI..."
  install_app "ProtonVPN CLI" protonvpn-cli protonvpn-cli
  log "Installing Proton Mail Bridge..."
  install_app "Proton Mail Bridge" com.protonmail.bridge protonmail-bridge
  log "Installing Proton Pass..."
  install_app "Proton Pass" com.proton.pass proton-pass
}

# --- Core applications ---
install_spotify()     { install_app "Spotify"     com.spotify.Client      spotify-client; }
install_steam()       { install_app "Steam"       com.valvesoftware.Steam steam; }
install_discord()     { install_app "Discord"     com.discordapp.Discord  discord; }
install_lutris()      { install_app "Lutris"      net.lutris.Lutris       lutris; }
install_easyeffects() { install_app "EasyEffects" com.github.wwmm.easyeffects ""; }
install_zenbrowser()  { install_app "Zen Browser" app.zen_browser.zen   zen-browser; }
install_onlyoffice()  { install_app "OnlyOffice"  org.onlyoffice.desktopeditors onlyoffice-desktopeditors; }
install_winbox()      { install_app "Winbox"      com.winehq.Winbox        wine; }

# --- JetBrains Toolbox via direct download ---
install_jetbrains() {
  log "Checking JetBrains Toolbox..."
  if command -v jetbrains-toolbox &>/dev/null; then
    log "JetBrains Toolbox already installed"
  else
    log "Installing JetBrains Toolbox..."
    URL=$(curl -s 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' \
         | grep -o 'https://download.jetbrains.com/[^" ]*toolbox.*\.tar\.gz')
    wget -O /tmp/toolbox.tar.gz "$URL" >>"$VERBOSE_LOG" 2>&1
    mkdir -p /opt/jetbrains-toolbox
    tar -xzf /tmp/toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
    ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
    rm /tmp/toolbox.tar.gz
    if command -v jetbrains-toolbox &>/dev/null; then log "JetBrains Toolbox installed"; else log "JetBrains Toolbox failed"; fi
  fi
}

# --- System/security tools ---
install_ssh()              { install_app "OpenSSH & UFW"       "" openssh-server; ufw --force enable >>"$VERBOSE_LOG" 2>&1; ufw allow OpenSSH >>"$VERBOSE_LOG" 2>&1; }
install_fail2ban()         { install_app "Fail2Ban"            "" fail2ban; systemctl enable --now fail2ban >>"$VERBOSE_LOG" 2>&1; }
install_wireguard()        { install_app "WireGuard"           "" wireguard; }
install_docker()           { install_app "Docker"              "" docker.io; }
install_portainer() { log "Checking Portainer..."; if ! docker ps -a | grep -q portainer; then docker volume create portainer_data >>"$VERBOSE_LOG" 2>&1; docker run -d -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce >>"$VERBOSE_LOG" 2>&1 && log "Portainer installed"; else log "Portainer already present"; fi; }
install_wireshark()        { install_app "Wireshark"           "" wireshark; usermod -aG wireshark root; }
install_burpsuite()        { install_app "BurpSuite"           "" burpsuite; }
install_lmsensors()        { install_app "lm-sensors"          "" lm-sensors; sensors-detect --auto >>"$VERBOSE_LOG" 2>&1; }
install_security_updates() { install_app "unattended-upgrades" "" unattended-upgrades; }

# --- Hardware & kernel checks ---
check_amd_gpu() { if lspci | grep -i amd | grep -q vga && ! lsmod | grep -q amdgpu; then apt-get install -y linux-headers-$(uname -r) amdgpu-pro >>"$VERBOSE_LOG" 2>&1 && log "AMDGPU driver installed"; fi; }
check_ryzen_microcode(){ if [[ ! -f /lib/firmware/amd-ucode/amd-ucode.bin ]]; then apt-get install -y amd64-microcode >>"$VERBOSE_LOG" 2>&1 && log "Ryzen microcode installed"; fi; }
check_kernel_version(){ kv=$(uname -r); log_verbose "Kernel: $kv"; if [[ "${kv%%.*}" -lt 5 || "${kv#*.}" -lt 10 ]]; then log "⚠️ Consider kernel upgrade for Ryzen"; fi; }

# --- Hardening & tweaks ---
apply_hardening(){ cat >/etc/sysctl.d/99-sysadmin.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.netfilter.nf_conntrack_max = 262144
net.ipv4.tcp_window_scaling = 1
EOF
  sysctl --system >>"$VERBOSE_LOG" 2>&1 && log "Sysctl applied"
  apt-get install -y apparmor apparmor-profiles apparmor-utils >>"$VERBOSE_LOG" 2>&1
  aa-enforce /etc/apparmor.d/*docker* || true
  aa-enforce /etc/apparmor.d/*wireguard* || true
}

# --- Synth-shell & Hack font ---
install_synth_shell(){ if [[ ! -d "/opt/synth-shell" ]]; then apt-get install -y zsh git fonts-powerline >>"$VERBOSE_LOG" 2>&1; git clone https://github.com/andresgongora/synth-shell.git /opt/synth-shell >>"$VERBOSE_LOG" 2>&1; bash /opt/synth-shell/setup.sh --install >>"$VERBOSE_LOG" 2>&1; log "synth-shell installed"; else log "synth-shell already present"; fi; }
install_hack_font(){ if ! fc-list | grep -q 'Hack Nerd Font'; then apt-get install -y unzip >>"$VERBOSE_LOG" 2>&1; mkdir -p /usr/local/share/fonts/NerdFonts; wget -O /tmp/Hack.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip >>"$VERBOSE_LOG" 2>&1; unzip -o /tmp/Hack.zip -d /usr/local/share/fonts/NerdFonts >>"$VERBOSE_LOG" 2>&1; rm /tmp/Hack.zip; fc-cache -fv >>"$VERBOSE_LOG" 2>&1; log "Hack Nerd Font installed"; else log "Hack Nerd Font already installed"; fi; }

# --- CLI glow-up ---
setup_cli_tools(){ install_app "exa" "" exa; install_app "bat" "" bat; install_app "fd" "" fd-find; install_app "ripgrep" "" ripgrep; install_app "fzf" "" fzf; install_app "htop" "" htop; install_app "ncdu" "" ncdu; install_app "neofetch" "" neofetch; install_app "tldr" "" tldr; ln -sf \$(which fdfind) /usr/local/bin/fd; }

# --- Docker group ---
grant_docker_group(){ usermod -aG docker \${SUDO_USER:-root}; log "Added user to docker group"; }

# --- Profiles ---
main_menu(){ echo -e "\nSelect profile:"; echo "1) Gaming"; echo "2) Work"; echo "3) Sysadmin"; echo "4) All"; echo "5) Exit"; read -p "Choice: " c; case \$c in
  1) gaming_tasks;;2) work_tasks;;3) sysadmin_tasks;;4) gaming_tasks;work_tasks;sysadmin_tasks;;5) exit 0;;*) echo "Invalid"; main_menu;;
esac; cleanup; }

gaming_tasks(){ log "Gaming profile..."; install_spotify; install_steam; install_discord; install_lutris; install_easyeffects; install_zenbrowser; install_winbox; install_synth_shell; install_hack_font; install_lmsensors; install_fail2ban; setup_cli_tools; grant_docker_group; }
work_tasks(){ log "Work profile..."; install_spotify; install_proton_suite; install_zenbrowser; install_onlyoffice; install_jetbrains; install_ssh; install_security_updates; install_synth_shell; install_hack_font; install_lmsensors; setup_cli_tools; grant_docker_group; }
sysadmin_tasks(){ log "Sysadmin profile..."; install_spotify; install_proton_suite; install_ssh; install_security_updates; install_fail2ban; install_wireguard; install_docker; install_portainer; install_jetbrains; install_winbox; install_wireshark; install_burpsuite; install_synth_shell; install_hack_font; install_lmsensors; check_amd_gpu; check_ryzen_microcode; check_kernel_version; apply_hardening; setup_apparmor_profiles; setup_email_alerts; setup_cli_tools; grant_docker_group; }

# --- Cleanup ---
cleanup(){ log "Cleaning up..."; apt-get autoremove -y >>"$VERBOSE_LOG" 2>&1; apt-get clean -y >>"$VERBOSE_LOG" 2>&1; flatpak uninstall --unused -y >>"$VERBOSE_LOG" 2>&1; log "Done. See logs for details."; }

# --- Run ---
main_menu
