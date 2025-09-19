#!/bin/bash
set -e

echo "[post_build] Patch des entrées de boot : archisolabel=ARCHEASY + retrait copytoram"

# UEFI (systemd-boot)
for f in work/iso/loader/entries/*.conf; do
  echo " - $f"
  # Remplacer archisosearchuuid=... par archisolabel=ARCHEASY
  sed -i -E 's/archisosearchuuid=[^ ]*/archisolabel=ARCHEASY/' "$f"
  # Retirer copytoram / copytoram=…
  sed -i -E 's/\<copytoram(=[^ ]*)?\>//g; s/  +/ /g' "$f"
  grep -n '^options' "$f"
done

# BIOS (syslinux)
if [ -d work/iso/syslinux ]; then
  for f in work/iso/syslinux/*.cfg; do
    echo " - $f"
    sed -i -E 's/archisosearchuuid=[^ ]*/archisolabel=ARCHEASY/' "$f"
    sed -i -E 's/\<copytoram(=[^ ]*)?\>//g; s/  +/ /g' "$f"
    grep -n 'append ' "$f" || true
  done
fi

echo "[post_build] Terminé."
