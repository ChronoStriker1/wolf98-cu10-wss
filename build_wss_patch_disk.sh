#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h}
patch_dir="$project_dir/wss_patch"
output_dir="$project_dir/out"
original_exe="$project_dir/original/WOLF98.EXE"
driver_bin="$output_dir/WSS_DRV.BIN"
driver_listing="$output_dir/WSS_DRV.LST"
output_exe="$output_dir/WOLF98.EXE"
output_image="$output_dir/CU10-OPL.FDI"

for command_name in nasm python3 unix2dos 7zz hdiutil newfs_msdos mount_msdos; do
  if ! command -v "$command_name" >/dev/null; then
    print -u2 "Missing required command: $command_name"
    exit 1
  fi
done

if [[ ! -f "$original_exe" ]]; then
  print -u2 "Place the supported original at: $original_exe"
  exit 1
fi

mkdir -p "$output_dir"
if [[ -e "$output_image" ]]; then
  print -u2 "Refusing to overwrite: $output_image"
  exit 1
fi

nasm -f bin -l "$driver_listing" -o "$driver_bin" "$patch_dir/WSS_DRV.ASM"
python3 "$patch_dir/patch_wolf98.py" \
  "$original_exe" "$driver_bin" "$driver_listing" "$output_exe"

raw_image=$(mktemp -t cu10-wss-patch-raw).img
mount_dir=$(mktemp -d -t cu10-wss-patch-mnt)
device_node=
complete=0

cleanup() {
  umount "$mount_dir" 2>/dev/null || true
  if [[ -n "$device_node" ]]; then
    hdiutil detach "$device_node" >/dev/null 2>&1 || true
  fi
  [[ -e "$raw_image" ]] && unlink "$raw_image"
  [[ -d "$mount_dir" ]] && rmdir "$mount_dir" 2>/dev/null || true
  if [[ "$complete" -eq 0 && -e "$output_image" ]]; then
    unlink "$output_image"
  fi
}
trap cleanup EXIT

python3 "$project_dir/tools/make_blank_fdi.py" "$output_image" >/dev/null
dd if="$output_image" of="$raw_image" bs=4096 skip=1 status=none
attach_output=$(hdiutil attach -nomount "$raw_image")
device_node=$(print -r -- "$attach_output" | awk 'NR == 1 {print $1}')
newfs_msdos -F 12 -S 1024 -c 1 -e 192 -m 0xfe -a 2 -u 8 -h 2 -s 1232 "$device_node" >/dev/null
mount_msdos "$device_node" "$mount_dir"
COPYFILE_DISABLE=1 cp "$output_exe" "$mount_dir/WOLF98.EXE"
unix2dos -q -n "$patch_dir/PATCH.BAT" "$mount_dir/PATCH.BAT"
unix2dos -q -n "$patch_dir/README.TXT" "$mount_dir/README.TXT"
sync
if [[ -d "$mount_dir/.fseventsd" ]]; then
  find "$mount_dir/.fseventsd" -depth -delete
fi
umount "$mount_dir"
hdiutil detach "$device_node" >/dev/null
device_node=

dd if="$raw_image" of="$output_image" bs=4096 seek=1 conv=notrunc status=none
7zz t "$output_image" >/dev/null
complete=1
shasum -a 256 "$output_exe" "$output_image"
