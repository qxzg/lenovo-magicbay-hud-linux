export HAL_PATH := $(PWD)/usb_hal
export DRM_PATH := $(PWD)/drm
export USB_HAL := hal_adaptor.o usb_device.o usb_hal_interface.o usb_hal_sysfs.o usb_hal_thread.o
MAGICBAY_VERSION := $(shell sed -n 's/^PACKAGE_VERSION="\([^"]*\)"/\1/p' $(CURDIR)/dkms.conf)
export MAGICBAY_VERSION


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

FORCE:

.PHONY: default drm clean FORCE

endif

