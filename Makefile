export HAL_PATH := $(CURDIR)/usb_hal
export DRM_PATH := $(CURDIR)/drm
export USB_HAL := hal_adaptor.o usb_device.o usb_hal_interface.o usb_hal_sysfs.o usb_hal_thread.o
MAGICBAY_VERSION := $(shell sed -n 's/^PACKAGE_VERSION="\([^"]*\)"/\1/p' $(CURDIR)/dkms.conf)
export MAGICBAY_VERSION
UDEV_RULE := udev/99-magicbay-xhci-power.rules
UDEV_RULE_DIR ?= /etc/udev/rules.d


ifneq ($(KERNELRELEASE),)
include Kbuild

else

# kbuild against specified or current kernel
ifeq ($(KVER),)
	KVER := $(shell uname -r)
endif

ifeq ($(KDIR),)
	KDIR := /lib/modules/$(KVER)/build
endif

export KVER KDIR

default: drm FORCE

drm: FORCE
	@echo "drm build"
	$(MAKE) -C $(DRM_PATH)

clean: FORCE
	$(MAKE) -C $(HAL_PATH) clean
	$(MAKE) -C $(DRM_PATH) clean

install-xhci-rule: $(UDEV_RULE)
	install -Dm0644 $(UDEV_RULE) $(DESTDIR)$(UDEV_RULE_DIR)/$(notdir $(UDEV_RULE))

apply-xhci-rule: FORCE
	udevadm control --reload
	udevadm trigger --subsystem-match=pci --sysname-match=0000:00:0d.0

uninstall-xhci-rule: FORCE
	rm -f $(DESTDIR)$(UDEV_RULE_DIR)/$(notdir $(UDEV_RULE))
	udevadm control --reload

FORCE:

.PHONY: default drm clean install-xhci-rule apply-xhci-rule uninstall-xhci-rule FORCE

endif
