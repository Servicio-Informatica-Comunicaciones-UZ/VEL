#!/bin/bash


export VERSION="2.1.2"


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


#Name of the VirtualBox VM used to test the LiveCD
export VBOXVMNAME="votUJI-dev"

#Generic pae kernel
export KERNELVERS="686-pae"
#export KERNELVERS="3.16.0-4-686-pae"




###############################
#   Packages to be installed  #
###############################

#Kernel and boot
PCKGS="linux-image-$KERNELVERS linux-headers-$KERNELVERS live-boot memtest86+ syslinux isolinux syslinux-utils plymouth plymouth-themes"

#System packages
PCKGS="$PCKGS ""dbus eject rsyslog openssl libnss3 libnspr4 sysvinit-utils libncurses5 ncurses-term"

#IO and locales
PCKGS="$PCKGS ""gpm  locales console-data kbd"

#Network
PCKGS="$PCKGS ""net-tools iputils-ping iptables rsync smbclient openntpd cifs-utils host"

#System setup utils
PCKGS="$PCKGS ""cryptsetup randomsound smbnetfs pcregrep wipe pm-utils zip unzip mdadm sudo x11-xkb-utils apt-utils"

#Voting management ui
PCKGS="$PCKGS ""dialog sg3-utils usbutils postfix mailutils sysstat statgrab lm-sensors acpi rrdtool smartmontools hddtemp"

#Voting service
PCKGS="$PCKGS ""apache2 mysql-server libapache2-mod-php5 php5-mysql php5-curl php5-cli php5-gd php-pear php5-dev php5-mcrypt"

#Tools
PCKGS="$PCKGS ""vim lsof psmisc pciutils mysql-client mutt less curl wget bc openssh-client sshpass ntpdate at"
#PCKGS="$PCKGS ""openssh-client openssh-server"

#Build tools
PCKGS="$PCKGS ""gcc g++ libssl-dev"

#<DEBUG>
#Debug tools
PCKGS="$PCKGS ""man emacs debconf-utils"
#</DEBUG>


###############################
#       System variables      #
###############################

BINDIR="/usr/local/bin"

#List of scripts and executables that can be called by the non-privileged user
NONPRIVILEGEDSCRIPTS="addslashes combs.py common.sh wizard-setup.sh wizard-maintenance.sh wizard-common.sh genPwd.php separateCerts.py urlencode"

