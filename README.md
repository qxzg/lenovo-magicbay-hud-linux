# Lenovo MagicBay HUD Linux Driver

Out-of-tree DRM/KMS driver for the Lenovo MagicBay HUD USB display.

## Status

The HUD works as a standard extended display with its native
`1424x280@60` mode. The current implementation has been tested with KDE Plasma on Wayland.

Tested hardware and kernels:

- Lenovo MagicBay HUD, USB ID `17ef:1117`
- Lenovo ThinkBook 14 G8+ IPH, machine type `21VG`
- Linux `6.18.38-2-lts`
- Linux `7.1.3-arch1-2`
- Linux `7.1.3-zen1-2-zen`

The driver is based on MacroSilicon's MS91xx Linux DRM source package `3.0.3.13`. It also retains the vendor IDs for MS9132, MS9133, and MS9135 devices; those devices are outside the current hardware test coverage.

## Requirements

- Linux kernel headers for the target kernel
- GCC and Make
- DKMS for automatic rebuilds after kernel updates

## DKMS installation

From the repository root:

```bash
sudo dkms install .
sudo modprobe usbdisp_usb
```

`usbdisp_usb` loads `usbdisp_drm` through its module dependency.

Verify the installation:

```bash
dkms status -m magicbay-hud
modinfo usbdisp_drm
modinfo usbdisp_usb
lsusb -d 17ef:1117
```

Remove the driver:

```bash
sudo dkms remove magicbay-hud/3.0.3.13.r3 --all
```

## Manual build

Build against the running kernel:

```bash
make clean
make
```

Load the modules:

```bash
sudo insmod drm/usbdisp_drm.ko
sudo insmod drm/usbdisp_usb.ko
```

The included `insmod.sh` script performs the same development build and load
sequence.

To build for another installed kernel:

```bash
make clean
make KVER=<kernel-release> KDIR=/lib/modules/<kernel-release>/build
```

## ThinkBook xHCI power rule

The tested ThinkBook requires its MagicBay Type-C xHCI controller to remain
awake while the HUD enumerates. Install the included rule with:

```bash
sudo make install-xhci-rule
sudo make apply-xhci-rule
```

The rule matches the PCI IDs of the tested ThinkBook 14 G8+ controller.

## Known limitations

- Kernel API changes can require updates to this out-of-tree driver.
- Large dynamic updates still have visible USB display latency.
- Runtime testing currently covers the Lenovo `17ef:1117` device.

## License and source

The source files are licensed under GNU GPL version 2 and retain the original
MacroSilicon copyright notices.

Vendor source:
[MS91xx Linux DRM source code](http://www.macrosilicon.com:9080/download/USBDisplay/Linux/SourceCode/)
