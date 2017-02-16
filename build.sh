#!/bin/bash
# -x Trace all executed commands
# -n Check file syntax

# These markers are used to allow backdoors for debugging on the test
# release mode, but backdoors are erased before compiling in
# production release mode.
# #<DEBUG>   #</DEBUG>    --> All command lines between these two markers will be removed from the release version
# #<RELEASE> #</RELEASE>  --> All command lines between these two markers will be removed from the debug version


#To update the webapp:
#wget http://dwnl.nisu.org/dwnl/ivot.php.zip -O - | funzip > src/webapp/bundle/ivot.php
## TODO ELIMINAR LA VERSIÓN ESTÁTICA de index.php antes de actualizar el bundle de nuevo


. src/build/build-tools.sh
. src/build/build-config.sh


##TODO: add selinux support?
##TODO: copy only needed isolunix modules

#########################
#      Run options      #
#########################


usage(){
    echo "Usage:"
    echo "$0 run_profile"
}

if [ $# -ne 1 ] ; then
    usage
    exit 0
fi

if [ -f $1  ] ; then :
else
    warn "run profile file not found $i"
    usage
    exit 0
fi


tell "Loading run profile"
. $1

#We test one profile var to see if properly loaded. Should be enough
#for an acceptable warranty
if [ "$RELEASE" != "0" -a  "$RELEASE" != "1"  ] ; then
    die "Run profile file might be ill loaded or not well formatted. Please check"
fi

#Executes priority rules among the profile variables.
[ "$RUNCHROOT" -eq 0  ] && NEWCD=0
[ "$NEWCD"     -eq 1  ] && RUNCHROOT=1

#Show profile
tell "*** Run profile ***"
tell "Production release?: $RELEASE"
tell "Build new CD:        $NEWCD"
tell "Run chroot commands: $RUNCHROOT"
tell "Compression:         $COMPRESS"
tell ""

#Calculating build tag and version
TAG=$TESTTAG
[ "$RELEASE" -eq 1  ] && TAG=$PRODTAG

FULLVERSION=$VERSION-$(buildNumber)-$TAG


tell "Starting LiveCD creation. Version: $FULLVERSION"




#########################
# Download base system  #
#########################


if [ "$NEWCD" -eq 1 ]
    then
    tell "*** Building from scratch. ***"

    tell "Erasing old target."
    rm -rf target/*
    
    tell "Creating directory trees"
    mkdir -p target/rootfs target/image target/bin
    
    tell "Downloading and installing base system"
    debootstrap --arch=${ARCH} --variant=minbase ${DISTRO} target/rootfs/ ${MIRROR}
fi

if [ -d  target/rootfs  -a  -d target/rootfs/home ] ; then
    tell "Done installing base system."
else
    die "Base system not installed or installation failed. Run with NEWCD flag on or check source repository."
fi




#####################################
# Setup distribution on the Chroot  #
#####################################


if [ "$RUNCHROOT" -eq 1 ]
then
    tell "*** Preparing chroot environment ***"
    
    tell "Copy voting system tools to the chroot workdir"
    rm -rf target/rootfs/root/src
    mkdir  target/rootfs/root/src
    mkdir  target/rootfs/root/doc
    cp -rf src/* target/rootfs/root/src/
    cp -rf doc/*.pdf target/rootfs/root/doc
    

    ######## Process scripts to comply with build mode #######
    tell "Process system tools to comply with the build mode"
    #We delete debug blocks when in release mode or release blocks
    #when in debug mode (opposite comments are left behind as they are harmful)
    if [ "$RELEASE" -eq 1 ] ; then
        sed -i -re '/#\s*<DEBUG>/,/#\s*<\/DEBUG>/d' $(find target/rootfs/root/src/ -iname "*.sh")
    else
        sed -i -re '/#\s*<RELEASE>/,/#\s*<\/RELEASE>/d' $(find target/rootfs/root/src/ -iname "*.sh")
    fi
    

    #Perform a syntax check of all the scripts (to save time and builds)
    for scrpt in $(find src/ -iname "*.sh")
    do
        bash -n $scrpt
        if [ $? -ne 0 ] ; then
            die "Compilation aborted due to syntax errors in bash scripts."
        fi
    done
    
    
    ######## Setup APT and network #######

    # TODO add contrib and non-free if needed    
    tell "Setting chroot apt sources"
    cat > target/rootfs/etc/apt/sources.list  <<EOF
deb ${MIRROR} ${DISTRO} main
deb-src ${MIRROR} ${DISTRO} main

deb ${SECMIRROR} ${DISTRO}/updates main
deb-src ${SECMIRROR} ${DISTRO}/updates main

deb ${MIRROR} ${DISTRO}-updates main
deb-src ${MIRROR} ${DISTRO}-updates main

EOF
    
    
    tell "Setting chroot internet access"
    #Configure Internet access inside chroot
    for i in /etc/resolv.conf /etc/hosts /etc/hostname; do cp -pv $i target/rootfs/etc/; done
    
    
    #Map special filesystems on the chroot
    tell "Mapping special filesystems to the chroot"
    mount --bind /dev target/rootfs/dev
    

    #Setup a policy to prevent daemons from starting and locking the
    #mounted special filesystems  #TODO see if mounting /dev causes issues, to the moment everything worked fine without it
    tell "Setting up policy to prevent daemons from starting"
    cat > target/rootfs/usr/sbin/policy-rc.d  <<EOF
#!/bin/sh
exit 101
EOF
    chmod a+x target/rootfs/usr/sbin/policy-rc.d
    
      
    tell "Entering chroot."
    cp $1 target/rootfs/root/src/
    #Calling chrooted script to setup the liveCD filesystem and packages, we pass the run profile
    chroot target/rootfs /bin/bash /root/src/build/buildLiveCD-chroot.sh /root/src/$(basename $1)

    tell "Removing policy to prevent daemons from starting"
    rm -vf target/rootfs/usr/sbin/policy-rc.d
    
    #Unmounting chroot bound special filesystems
    umount target/rootfs/dev
    
    
fi



####### Building LiveCD #######

mkdir -p target/image/{live,isolinux}
rm -f target/image/isolinux/*
rm -f target/image/live/*


tell "Copying kernel to CD boot dir"
#Copying Kernel at CD Boot dir
find   target/rootfs/boot -iname 'vmlinuz*'    -exec cp -vp {} target/image/live/vmlinuz1 \;
find   target/rootfs/boot -iname 'initrd.img*' -exec cp -vp {} target/image/live/initrd1  \;

tell "Setting up CD bootloader"

#cp -vp target/rootfs/boot/memtest86+.bin                     target/image/live/memtest

cp -vp target/rootfs/usr/lib/ISOLINUX/isolinux.bin               target/image/isolinux/
#cp target/rootfs/usr/lib/syslinux/modules/bios/hdt.c32           target/image/isolinux/
#cp -vp target/rootfs/usr/lib/syslinux/modules/bios/menu.c32      target/image/isolinux/
#cp -vp target/rootfs/usr/lib/syslinux/modules/bios/pci.c32       target/image/isolinux/
#cp -vp target/rootfs/usr/lib/syslinux/modules/bios/libcom32.c32  target/image/isolinux/
#cp -vp target/rootfs/usr/lib/syslinux/modules/bios/libutil.c32   target/image/isolinux/
#cp -vp target/rootfs/usr/lib/syslinux/modules/bios/vesamenu.c32  target/image/isolinux/
#cp -vp target/rootfs/usr/lib/syslinux/modules/bios/ldlinux.c32   target/image/isolinux/
cp -vp target/rootfs/usr/lib/syslinux/modules/bios/*   target/image/isolinux/

cp -vp src/build/boot/isolinux.cfg target/image/isolinux/


if [ -s target/image/isolinux/isolinux.bin ] ; then
    :
else
    die "Missing bootloader. Check build process"
fi

#These params turn off squashfs compression
tell "Building squashfs with the OS root filesystem"
SQUASHPARAMS=""
[ "$COMPRESS" -eq 0 ] && SQUASHPARAMS="-noI -noD -noF -noX"
mksquashfs target/rootfs target/image/live/filesystem.squashfs ${SQUASHPARAMS}


if [ -s target/image/live/filesystem.squashfs ] ; then
    :
else
    die "Missing or empty squashfs. Something went wrong."
fi



#If activated, name will be completed with -version-build-build_tag
if [ "$VERSIONINFO" -eq 1 ] ; then
    tell "Adding version info to the image name"
    BASEN=$(getBasename $IMGNAME)
    EXT=$(getExtension $IMGNAME)
    IMGNAME=$BASEN-$FULLVERSION.$EXT
fi

#build ISO CD image
tell "Building ISO CD image: $IMGNAME"
genisoimage -b isolinux/isolinux.bin -rational-rock -volid "$IMGCDTAG" -cache-inodes -joliet -full-iso9660-filenames -no-emul-boot -boot-load-size 4 -boot-info-table -output target/bin/$IMGNAME target/image


##TODO detect if up, then shutdown and up
VBoxManage startvm $VBOXVMNAME
