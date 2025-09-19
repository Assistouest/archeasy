#!/usr/bin/env bash
set -euo pipefail
set -x
trap 'echo "💥 Échec à la ligne $LINENO : $BASH_COMMAND"' ERR


### --- Correctif copytoram pour Calamares (script + service) ---
# 1) Script qui recrée les chemins attendus par Calamares quand copytoram est actif
install -d -m 0755 /usr/local/bin
cat > /usr/local/bin/archeasy-copytoram-compat.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

SRC_SFS="/run/archiso/copytoram/airootfs.sfs"
DST_SFS_DIR="/run/archiso/bootmnt/arch/x86_64"
DST_SFS="${DST_SFS_DIR}/airootfs.sfs"

# Optionnel : fournir un vmlinuz au chemin attendu par la conf Calamares
SRC_VMLINUZ="/usr/lib/modules/$(uname -r)/vmlinuz"
DST_VMLINUZ_DIR="/run/archiso/bootmnt/arch/boot/x86_64"
DST_VMLINUZ="${DST_VMLINUZ_DIR}/vmlinuz-linux"

# Attendre que copytoram soit prêt (jusqu'à ~10 s)
for i in {1..20}; do
  [ -f "$SRC_SFS" ] && break
  sleep 0.5
done

# Si pas de copytoram, ne rien faire
[ -f "$SRC_SFS" ] || exit 0

mkdir -p "$DST_SFS_DIR" "$DST_VMLINUZ_DIR"

# Lier le squashfs en RAM vers l'emplacement attendu par Calamares
ln -sfn "$SRC_SFS" "$DST_SFS"

# Copier un vmlinuz si disponible
if [ -f "$SRC_VMLINUZ" ]; then
  cp -f "$SRC_VMLINUZ" "$DST_VMLINUZ"
fi

exit 0
EOF
chmod 0755 /usr/local/bin/archeasy-copytoram-compat.sh

# 2) Service systemd qui s'exécute avant l'UI (SDDM)
install -d -m 0755 /etc/systemd/system
cat > /etc/systemd/system/archeasy-copytoram-compat.service << 'EOF'
[Unit]
Description=ArchEasy copytoram compat for Calamares (restore /run/archiso/bootmnt paths)
DefaultDependencies=no
After=local-fs.target
Before=display-manager.service sddm.service graphical.target
ConditionPathExists=/run/archiso

[Service]
Type=oneshot
ExecStart=/usr/local/bin/archeasy-copytoram-compat.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 3) Activer le service
install -d -m 0755 /etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/archeasy-copytoram-compat.service \
  /etc/systemd/system/multi-user.target.wants/archeasy-copytoram-compat.service


### --- Ta config d'origine ArchEasy ---
# --- Créer utilisateur live ---
useradd -m -s /bin/bash liveuser
passwd -d liveuser   # pas de mot de passe
usermod -aG wheel,audio,video,network liveuser

### --- Activer services Bluetooth ---
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/bluetooth.service \
    /etc/systemd/system/multi-user.target.wants/bluetooth.service

# (Optionnel) auto-activation Bluetooth au boot
mkdir -p /etc/bluetooth
cat > /etc/bluetooth/main.conf <<'EOF'
[Policy]
AutoEnable=true
EOF


# Assure les dossiers "wants"
mkdir -p airootfs/etc/systemd/system/multi-user.target.wants

# Active power-profiles-daemon en créant le symlink d’activation
ln -sf /usr/lib/systemd/system/power-profiles-daemon.service \
       airootfs/etc/systemd/system/multi-user.target.wants/power-profiles-daemon.service


### --- Activer services Impression ---
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/cups.service \
    /etc/systemd/system/multi-user.target.wants/cups.service
ln -sf /usr/lib/systemd/system/avahi-daemon.service \
    /etc/systemd/system/multi-user.target.wants/avahi-daemon.service

### --- Ajouter l’utilisateur liveuser aux groupes nécessaires ---
usermod -aG lp,sys,network,scanner liveuser || true

# --- Configurer autologin SDDM pour liveuser ---
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf <<'EOF'
[Autologin]
User=liveuser
Session=plasma.desktop
EOF


# --- Autostart Calamares uniquement en session live + blocage BIOS ---
# Script lanceur conditionné au live + UEFI requis
install -d -m 0755 /usr/local/bin
cat > /usr/local/bin/run-calamares-live << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# N'agir que dans le live ArchISO
if ! [ -d /run/archiso ] && ! grep -q 'archiso' /proc/cmdline 2>/dev/null; then
    exit 0
fi

# Bloquer en BIOS/Legacy : UEFI requis
if ! [ -d /sys/firmware/efi ]; then
    TITLE="ArchEasy – Mode BIOS non pris en charge"
    MSG=$'Installation non disponible en mode BIOS/Legacy.\n\nVeuillez redémarrer votre PC en mode UEFI (désactivez CSM/Legacy Boot).'

    if command -v kdialog >/dev/null 2>&1; then
        kdialog --error "$MSG" --title "$TITLE"
    elif command -v xmessage >/dev/null 2>&1; then
        xmessage -center "$TITLE\n\n$MSG"
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "$TITLE" "$MSG"
    else
        echo -e "\n$TITLE\n$MSG\n" >/dev/tty1 || true
    fi
    exit 0
fi

# Live + UEFI : laisser l'UI respirer puis lancer Calamares
sleep 2
exec pkexec calamares
EOF
chmod 0755 /usr/local/bin/run-calamares-live

# Fichier d'autostart XDG (appliqué à toutes les sessions graphiques du live)
install -d -m 0755 /etc/xdg/autostart
cat > /etc/xdg/autostart/archeasy-calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=ArchEasy Installer
Comment=Lancer Calamares automatiquement en session live
Exec=/bin/sh -c '/usr/local/bin/run-calamares-live'
OnlyShowIn=KDE;LXQt;XFCE;GNOME;
X-GNOME-Autostart-enabled=true
NoDisplay=false
Terminal=false
EOF
