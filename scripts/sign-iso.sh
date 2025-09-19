# /home/adrien/archeasy/scripts/sign-iso.sh
#!/usr/bin/env bash
set -euo pipefail
# Usage: sudo ./scripts/sign-iso.sh out/Archeasy-2025.09.18-x86_64.iso

ISO_IN="${1:-}"
if [ -z "$ISO_IN" ]; then
  ISO_IN=$(ls out/*.iso 2>/dev/null | head -n1) || { echo "Aucun ISO trouvé dans out/"; exit 1; }
fi

WORK_ISO_DIR="work/iso"
OUT_ISO="${ISO_IN%.iso}-secure.iso"

# --- 0) Sanity checks ---
[ -d "$WORK_ISO_DIR" ] || { echo "Dossier $WORK_ISO_DIR introuvable. Lance d'abord: sudo mkarchiso -v ."; exit 1; }
[ -d "$WORK_ISO_DIR/EFI/BOOT" ] || { echo "Dossier $WORK_ISO_DIR/EFI/BOOT introuvable."; exit 1; }
[ -f "$WORK_ISO_DIR/EFI/BOOT/BOOTx64.EFI" ] || { echo "BOOTx64.EFI absent dans $WORK_ISO_DIR/EFI/BOOT."; exit 1; }

# --- 1) Générer MOK si absente ---
if [ ! -f MOK.key ] || [ ! -f MOK.crt ] || [ ! -f MOK.cer ]; then
  echo "Génération des clés MOK (RSA2048)..."
  openssl req -newkey rsa:2048 -nodes -keyout MOK.key \
    -new -x509 -sha256 -days 3650 -subj "/CN=ArchEasy MOK/" -out MOK.crt
  openssl x509 -outform DER -in MOK.crt -out MOK.cer
fi

# --- 2) (Optionnel) fabriquer un GRUB standalone, sinon on signe celui de l'ISO ---
echo "Création d'un grub standalone (grub-mkstandalone)..."
GRUB_STANDALONE="./grubx64.standalone.efi"
if grub-mkstandalone -O x86_64-efi -o "$GRUB_STANDALONE" \
   --modules="part_gpt part_msdos fat ext2 normal boot configfile linux search" \
   "boot/grub/grub.cfg=/boot/grub/grub.cfg"; then
  cp "$GRUB_STANDALONE" "$WORK_ISO_DIR/EFI/BOOT/grubx64.efi"
else
  echo "grub-mkstandalone a échoué, on signe le GRUB existant."
  cp "$WORK_ISO_DIR/EFI/BOOT/BOOTx64.EFI" "$WORK_ISO_DIR/EFI/BOOT/grubx64.efi"
fi

# --- 3) Signer grubx64.efi ---
echo "Signature de grubx64.efi..."
chmod +w "$WORK_ISO_DIR/EFI/BOOT/grubx64.efi" || true
sbsign --key MOK.key --cert MOK.crt \
  --output "$WORK_ISO_DIR/EFI/BOOT/grubx64.efi" \
  "$WORK_ISO_DIR/EFI/BOOT/grubx64.efi"

# --- 4) Remplacer BOOTx64.EFI par shim + ajouter MokManager ---
echo "Copie de shim + MokManager..."
if [ -f /usr/share/shim/shimx64.efi ]; then
  SHIM="/usr/share/shim/shimx64.efi"; MM="/usr/share/shim/mmx64.efi"
elif [ -f /usr/share/shim-signed/shimx64.efi ]; then
  SHIM="/usr/share/shim-signed/shimx64.efi"; MM="/usr/share/shim-signed/mmx64.efi"
else
  echo "shim non trouvé (/usr/share/shim*). Installe 'shim'."; exit 1
fi
cp "$SHIM" "$WORK_ISO_DIR/EFI/BOOT/BOOTx64.EFI"
cp "$MM"   "$WORK_ISO_DIR/EFI/BOOT/mmx64.efi"

# --- 5) Signer le noyau de l’ISO ---
KERNEL_SRC="$WORK_ISO_DIR/arch/boot/x86_64/vmlinuz-linux"
if [ -f "$KERNEL_SRC" ]; then
  echo "Signature du noyau vmlinuz-linux..."
  sbsign --key MOK.key --cert MOK.crt --output "$KERNEL_SRC" "$KERNEL_SRC"
else
  echo "Attention: noyau non trouvé à $KERNEL_SRC (vérifie ton build)."
fi

# --- 6) Déposer MOK.cer à la racine de l'ISO (pour l'enrôlement via MokManager) ---
cp -f MOK.cer "$WORK_ISO_DIR/MOK.cer"

# --- 7) Repacker l’ISO en re-mappant les fichiers modifiés ---
echo "Repacking ISO -> $OUT_ISO ..."
xorriso -indev "$ISO_IN" -outdev "$OUT_ISO" \
  -map "$WORK_ISO_DIR/EFI/BOOT/BOOTx64.EFI" /EFI/BOOT/BOOTx64.EFI \
  -map "$WORK_ISO_DIR/EFI/BOOT/grubx64.efi" /EFI/BOOT/grubx64.efi \
  -map "$WORK_ISO_DIR/EFI/BOOT/mmx64.efi"   /EFI/BOOT/mmx64.efi \
  -map "$WORK_ISO_DIR/arch/boot/x86_64/vmlinuz-linux" /arch/boot/x86_64/vmlinuz-linux \
  -map "$WORK_ISO_DIR/MOK.cer" /MOK.cer \
  -boot_image any replay

echo "ISO signé (Secure Boot) : $OUT_ISO"
echo "Au 1er boot (Secure Boot activé) : MokManager -> Enroll key from disk -> MOK.cer"
