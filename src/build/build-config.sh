#!/bin/bash


export VERSION="0.1"


export ARCH=i386

export DISTRO=jessie
#export MIRROR="http://ftp.es.debian.org/debian/"
export MIRROR="http://ftp.us.debian.org/debian/"
export SECMIRROR="http://security.debian.org/"


#Tagname for the test builds
export TESTTAG="TEST"
export PRODTAG="RELEASE"


export IMGCDTAG="votUJI LiveCD"
export IMGNAME=votUJI.iso

#Generic pae kernel
export KERNELVERS="686-pae"
#export KERNELVERS="3.16.0-4-686-pae"




###############################
#   Packages to be installed  #
###############################

#Kernel and boot
PCKGS="linux-image-$KERNELVERS linux-headers-$KERNELVERS live-boot memtest86+ syslinux isolinux syslinux-utils plymouth plymouth-themes"

#System packages
PCKGS="$PCKGS ""dbus eject rsyslog openssl libnss3 libnspr4"

#IO and locales
PCKGS="$PCKGS ""gpm  locales console-data kbd"

#Network
PCKGS="$PCKGS ""net-tools iputils-ping iptables rsync smbclient openntpd cifs-utils"

#System setup utils
PCKGS="$PCKGS ""cryptsetup randomsound smbnetfs pcregrep wipe pm-utils zip unzip mdadm "

#Voting management ui
PCKGS="$PCKGS ""dialog sg3-utils usbutils postfix mailutils sysstat statgrab lm-sensors acpi rrdtool smartmontools hddtemp"

#Voting service
PCKGS="$PCKGS ""apache2 mysql-server libapache2-mod-php5 php5-mysql php5-curl php5-cli php5-gd php-pear php5-dev php5-mcrypt"

#Tools
PCKGS="$PCKGS ""vim lsof psmisc pciutils mysql-client mutt less"
#PCKGS="$PCKGS ""openssh-client openssh-server"

#Build tools
PCKGS="$PCKGS ""gcc g++ libssl-dev"

#<DEBUG>
#Debug tools
PCKGS="$PCKGS ""man emacs debconf-utils"
#</DEBUG>
