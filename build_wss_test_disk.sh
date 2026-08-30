#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h}
test_dir="$project_dir/wss_test"
output_dir="$project_dir/out"
output_com="$output_dir/WSS_TST.COM"
output_image="$output_dir/CU10-TST.FDI"

for command_name in nasm python3 unix2dos 7zz hdiutil newfs_msdos mount_msdos; do
  if ! command -v "$command_name" >/dev/null; then
    print -u2 "Missing required command: $command_name"
    exit 1
  fi
done

mkdir -p "$output_dir"
if [[ -e "$output_image" ]]; then
  print -u2 "Refusing to overwrite: $output_image"
  exit 1
fi

nasm -f bin -o "$output_com" "$test_dir/WSS_TST.ASM"

raw_image=$(mktemp -t cu10-wss-test-raw).img
mount_dir=$(mktemp -d -t cu10-wss-test-mnt)
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
COPYFILE_DISABLE=1 cp "$output_com" "$mount_dir/WSS_TST.COM"
unix2dos -q -n "$test_dir/TEST.BAT" "$mount_dir/TEST.BAT"
unix2dos -q -n "$test_dir/README.TXT" "$mount_dir/README.TXT"
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
shasum -a 256 "$output_image"
