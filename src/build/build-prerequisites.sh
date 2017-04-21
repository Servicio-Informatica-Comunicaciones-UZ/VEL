#!/bin/bash

. build-tools.sh
. build-config.sh




tell "Installing necessary tools."
apt-get update

apt-get install -y make gcc g++ libssl-dev
apt-get install -y linux-headers-$(uname -r)
apt-get install -y debootstrap debconf-utils syslinux squashfs-tools genisoimage memtest86+ rsync grub


#dpkg -i virtualbox...
