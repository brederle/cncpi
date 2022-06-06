#!/bin/bash

###
# Headless image preparation for raspberry pis
# with WLAN configuration
# example call: 
#     ./sdcard-osx.sh ~/Downloads/2020-02-13-raspbian-buster-lite.img disk2
imagepath=$1
diskname=$2   # just the name, not the raw name, without /dev

sudo diskutil unmountDisk /dev/$diskname
sudo dd if=$imagepath of=/dev/r$diskname bs=1m conv=sync
sleep 1
cp config.txt userconf.txt wpa_supplicant.conf /Volumes/boot
touch /Volumes/boot/ssh
sudo diskutil unmountDisk /dev/$2
