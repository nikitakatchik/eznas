#!/bin/sh
set -eu

# ---------- settings ----------
BASE="${HOST_MOUNT_BASE:-/media}"   # host path we mount under
UID="${HOST_UID:-1000}"             # owner for FAT/NTFS/exFAT
GID="${HOST_GID:-1000}"
UMASK="${HOST_UMASK:-022}"

# ---------- helpers ----------
# Run a command in the HOST's mount + UTS namespaces (PID 1)
H() { nsenter -t 1 -m -u -- "$@"; }

safe() { printf "%s" "$1" | tr -cd '[:alnum:]_.-'; }

# Ensure host mount base exists: /media/usb
H mkdir -p "$BASE/usb"

# Unmount anything under /media/usb we previously created but whose device is gone
umount_missing() {
  H awk -v pref="$BASE/usb/" '$2 ~ "^"pref {print $1, $2}' /proc/self/mounts \
  | while read -r dev mp; do
      [ -b "$dev" ] || { H umount -l "$mp" 2>/dev/null || true; H rmdir "$mp" 2>/dev/null || true; }
    done
}

# Remove empty /media/usb/* dirs (safe no-op for non-empty/mounted)
cleanup_dirs() {
  H find "$BASE/usb" -mindepth 1 -maxdepth 1 -type d -empty -exec rmdir {} \; 2>/dev/null || true
}

mount_one() {
  dev="$1"
  # Skip internal storage/loop devices
  case "$dev" in /dev/mmcblk*|/dev/loop*) return 0 ;; esac

  fstype="$(blkid -o value -s TYPE "$dev" 2>/dev/null || true)"
  [ -n "$fstype" ] || return 0

  label="$(blkid -o value -s LABEL "$dev" 2>/dev/null || true)"
  uuid="$(blkid -o value -s UUID  "$dev" 2>/dev/null || true)"
  name="${label:-${uuid:-$(basename "$dev")}}"
  sname="$(safe "$name")"
  mp="$BASE/usb/${sname}"

  # Already mounted on host?
  if H sh -lc "grep -q ' $mp ' /proc/self/mounts 2>/dev/null"; then
    return 0
  fi

  opts="rw,noatime,nofail"
  case "$fstype" in
    vfat|msdos) opts="$opts,uid=$UID,gid=$GID,umask=$UMASK,utf8=1" ;;
    exfat)      opts="$opts,uid=$UID,gid=$GID,umask=$UMASK" ;;
    ntfs|ntfs3)
      # prefer in-kernel ntfs3 if present
      if grep -qw ntfs3 /proc/filesystems; then fstype="ntfs3"; fi
      opts="$opts,uid=$UID,gid=$GID,umask=$UMASK"
      ;;
    ext2|ext3|ext4|xfs|btrfs) : ;;   # ownership comes from FS, not mount opts
    *) : ;;
  esac

  H mkdir -p "$mp"
  if ! H mount -t "$fstype" -o "$opts" "$dev" "$mp"; then
    # fallback to auto-detect
    if ! H mount -t auto -o "$opts" "$dev" "$mp"; then
      H rmdir "$mp" 2>/dev/null || true
      return 0
    fi
  fi
}

# Initial sweep: mount all present partitions
lsblk -pnro NAME,TYPE | awk '$2=="part"{print $1}' | while read -r p; do mount_one "$p"; done
umount_missing
cleanup_dirs

# Clean up on exit (e.g., container stop/restart)
trap 'umount_missing; cleanup_dirs' EXIT INT TERM

# Poll for new/removed devices
while :; do
  lsblk -pnro NAME,TYPE | awk '$2=="part"{print $1}' | while read -r p; do mount_one "$p"; done
  umount_missing
  cleanup_dirs
  sleep 2
done
