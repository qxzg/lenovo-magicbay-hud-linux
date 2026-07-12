# Example build and load script
make clean
make
sleep 5
sudo insmod ./drm/usbdisp_drm.ko
sudo insmod ./drm/usbdisp_usb.ko
lsmod | grep usbdisp
