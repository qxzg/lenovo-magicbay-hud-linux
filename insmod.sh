#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_dir"

make clean
make
sudo insmod drm/usbdisp_drm.ko
sudo insmod drm/usbdisp_usb.ko
lsmod | grep '^usbdisp'
