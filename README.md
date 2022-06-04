# Automated ssh install for cnc.js on Raspberry pi

## Purpose
This script collects all required installation and setup steps to
1. do a basic hardening of raspian/raspberry os installation, e.g. by replacing pi user
2. enable exclusive shell access via (elliptic) ssh certificates
3. enable weekly security auto-updates
4. fully automate setup steps by running scripts via ssh calls
5. run node.js as non-root
6. run cnc.js as non-root

## Howto use the scripts
The script is separated into 2 parts:
1. a script (at the moment for MacOS only) to install raspian/raspberry os and do a headless boot setup (see `./boot`)
2. a script that hardens pi via ssh calls and executes all installation steps

###### Prepare boot SD card 
1. If you are using wlan to connect pi to your network, put your network SID and wifi password (encrpyted) into `./boot/wpa_supplicant.conf` (see file comments for details)
2. Execute preparation of SD card where
   - `<path to .img>` is the path to a local Raspian/Raspberry OS image to use
   - `<sd disk name>` is the disk name (without `/dev/`) to use. Call `diskutil list` to find the proper disk 

```
> cd boot; ./sdcard_osx <path to .img> <sd disk name>
```

###### Setup
1. Add the public key hashes that exclusively have permission to login to the pi in the future to `authorized_keys`. Make sure you have the corresponding private keys at hand
2. Execute setup where
   - `<host>` is the dns name or ip of the pi in your network
   - `<user>` is a self-chosen username that replaces the pi user
   - `<path to ssh private key>` is the location of your ssh private key.
Note that all installation steps log in with this key and the new username.

```
> cd setup; ./setup-cncpi.sh <host> <username> <path to ssh private key>
```
You are prompted for the initial `pi` user default password (usually `raspberry` by default).  