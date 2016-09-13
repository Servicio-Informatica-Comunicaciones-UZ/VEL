#!/bin/bash
#This is the LiveCD building script executed inside the chroot

. /root/src/build/build-tools.sh
. /root/src/build/build-config.sh


#Default env to allow proper parsing
export HOME=/root
export LC_ALL=C
export LANG=""

cd $HOME

# TODO: in prod, apache logs should go to null, at least during elections, if any info can be extracted from there. check.


##TODO: Prompt del keymap: ver si puede saltarse, prompt del mysql?  separar los prompts insalvables. intentar automatizar. si no, dar instrucciones con read antes de proceder.
##TODO: puede ser necesario /dev/pts

#TODO check if needed:  libnss3 libnspr4

#TODO cambiar el hostname y el hosts


#TODO remake plymouth theme


## TODO generate available locales
# locale-gen
#[root@lab9054::ujiVoting]$ less  /etc/locale.gen

##

##TODO disable apache logs? (or reduce their ttl)

# TODO los cert ssl, buscarlos en la ruta /etc/ssl/ certs/ y private/

#TODO config TLS en postfi. Do we need to secure SSL for postfix?

#Tras el mgr, relanzar el apache, mysql, postfix y smartmontools (verificar), mdadm


ctell "Running with profile: $*"
. "$1"


#Map special filesystems on the chroot
ctell "Mapping special filesystems"
mount -t proc  proc  /proc
mount -t sysfs sysfs /sys
#mount --bind /dev /dev





#Perform installs and updates
if [ $UPDATEPACKAGES -eq "1" ]
    then

        ctell "Packages to be installed: $PCKGS"

        ctell "Update package list"
        apt-get update

        ctell "***************** Upgrading packages *******************"
        apt-get update --allow-unauthenticated
        apt-get upgrade -y
        if [ $? -ne 0 ]
        then
	           ctell "Repairing..."
	           dpkg --configure -a
        fi

        ctell "***************** Install packages *******************"


        #Add presets to avoid as much interactions as possible
        echo 'mysql-server mysql-server/root_password password defaultpassword' | debconf-set-selections 
        echo 'mysql-server mysql-server/root_password_again password defaultpassword' | debconf-set-selections

        echo "postfix postfix/mailname string dummy.domain.com" | debconf-set-selections
        echo "postfix postfix/main_mailer_type string 'No configuration'" | debconf-set-selections
        echo "console-common  console-data/keymap/policy      select  Don't touch keymap" | debconf-set-selections
        echo "console-data    console-data/keymap/policy      select  Don't touch keymap" | debconf-set-selections
    

        #<DEBUG>
        # For the test version, we automatise the most we can the
        # installation. For the release version, default keyboard layout will
        # be prompted
        #echo -e "----------\nYou will be prompted to choose keyboard type. Please, select qwerty and press RETURN\n----------)" && read
        echo "console-data	console-data/keymap/qwerty/layout	select	US american" | debconf-set-selections
        echo "keyboard-configuration	keyboard-configuration/xkb-keymap	select	en" | debconf-set-selections
        echo "keyboard-configuration	keyboard-configuration/variant	select	English (US)" | debconf-set-selections
        #</DEBUG>
        
                
        apt-get -f install -y --force-yes ${PCKGS}
        
        
        #Copy the pm-utils package, as it needs to be reconfigured on every boot for hardware dependencies
        cp -fv /var/cache/apt/archives/pm-utils*.deb   $BINDIR/
        chmod 444 $BINDIR/pm-utils*.deb

 
# TODO pensarme si soporto nfs
#    ctell "CHROOT: Installing conflictive custom package: nfs"
#    (apt-get -f install -y nfs-common)    
#    #Si falla la instalaci�n y peta el sub-shell, hacer el reconfigure
        #    [ "$?" -ne 0 ] && dpkg --configure -a
        
fi




#Generate DH parameters for the apache SSL
if [ $GENERATEDHPARAMS -eq "1" ]
    then
        ctell "Generating 4096 bit Diffie Helman parameters for SSL"
        openssl dhparam -out /etc/ssl/dhparams.pem 4096
fi



ctell "***** Building Secret Sharing tool"
pushd  /root/src/tools/ssss/
make
cp ssOperations $BINDIR/
popd



#Setting Up Plymouth theme
ctell "***** Installing plymouth theme"

cp -rf /root/src/sys/plymouth/vtuji    /usr/share/plymouth/themes/

/usr/sbin/plymouth-set-default-theme vtuji

#TODO
#cat >> /etc/initramfs-tools/modules  <<EOF
#
## VESA Framebuffer
#vesafb
#fbcon
#EOF

#Configure initramfs so it loads the new splash
update-initramfs -u






ctell "***** Copying binaries and system configuration files"

echo $VERSION > /etc/vtUJIversion

cp -fv /root/src/mgr/bin/*                             $BINDIR/
cp -fv /root/src/tools/misc/*                          $BINDIR/

cp -fv /root/src/sys/config/webserver/000-default.conf  /etc/apache2/sites-available/
cp -fv /root/src/sys/config/webserver/default-ssl.conf  /etc/apache2/sites-available/
cp -fv /root/src/sys/config/webserver/security.conf     /etc/apache2/conf-available/

cp -fv /root/src/sys/config/php/timezones              /usr/local/share/

cp -fv /root/src/sys/config/ntpd/ntpd.conf             /etc/openntpd/

cp -fv /root/src/sys/config/mailer/main.cf             /etc/postfix/

#All aliases set to root, so he receives all mail notifications
#adressed to specific app users
cp -fv /root/src/sys/config/mailer/aliases             /etc/

#Non-privileged user is allowed to invoke privileged ops scripts
#acting as root
cp -fv /root/src/sys/config/misc/sudoers               /etc/

cp -fv  /root/src/sys/firewall/*.sh       $BINDIR/
cp -fv  /root/src/sys/firewall/whitelist  /etc/whitelist

#Set owner and permissions
ctell "***** Setting file owners and permissions of scripts and executables"
chown root:root $BINDIR/*

pushd $BINDIR/
chmod 550 ./*
#Set which tools can be used by the non-privileged user    
chmod o+rx $NONPRIVILEGEDSCRIPTS
popd

#Privileges scripts for root only (non-privileged user can use sudo)
chmod 500 $BINDIR/privileged-ops.sh
chmod 500 $BINDIR/privileged-setup.sh

#Setuid the sginfo executable for the non-privileged user  #//// TODO Creo que no hace falta. pruebo a ver (he quitado el setuid en al vm).
#chmod ug+s /usr/bin/sginfo


#Copy web application files
ctell "***** Copy web application installer"
rm -rf   /var/www/*
mkdir -pv /var/www/tmp/
cp -fv /root/src/webapp/bundle/ivot.php          /var/www/tmp/
cp -fv /root/src/webapp/tools/mkInstaller.php    /var/www/tmp/
cp -fv /root/src/webapp/tools/markVariables.py   /var/www/tmp/



ctell "***** Installing localization for our tools *****"
#For each available language
langs=$(ls -p /root/src/mgr/localization/ | grep  -oEe "[^/]+/$" | sed -re "s|(.*)/$|\1|g")
for la in $langs
  do
  #Copy compiled locales to the system locale path
  cp -f /root/src/mgr/localization/$la/*.mo  /usr/share/locale/$la/LC_MESSAGES/
  
  #copiamos las licencias al directorio, con la extension de su idioma
  cp -f /root/src/mgr/localization/$la/License  /usr/share/doc/License.$la
  
  #copiamos el Readme de la firma del cert al directorio, con la extension de su idioma
  cp -f /root/src/mgr/localization/$la/eLectionLiveCD-README.txt   /usr/share/doc/sslcert-README.txt.$la
  
done


# TODO invocar al compilador de i18n para asegurar que se aplica la �ltima traducci�n? probar primero una ejecuci�n manual, a ver c�mo era



#Build bundle with the used sources, so everything can be audited.
ctell "***** Build source bundle"
find   /root/src/   -iname ".svn" | xargs rm -rf
tar czf /root/source-$VERSION.tgz /root/src/
rm -rf /root/src/





ctell "****** Setup firewall on startup"
if grep --quiet -e "^\. /.*firewall.sh$" /etc/init.d/networking
then
    :
else
    #Include firewall script
    sed -i -re "s|(^.*init-functions.*$)|\1\n. $BINDIR/firewall.sh|"  /etc/init.d/networking
    
    #Execute on "start" (inserts as last line of the start case block)
    sed -i -re '/^\s*start\)\s*$/,/^\s*;;\s*$/{/^\s*;;\s*$/!b;i\  setupFirewall' -e '}' /etc/init.d/networking
fi

#Daily update the LCN servers list on the whitelist # TODO decide what we do with the eSurvey LCN
#On error (if there's output) an e-mail will be sent to the root
aux=$(cat /etc/crontab | grep whitelistLCN)
if [ "$aux" == "" ] 
    then
    echo -e "\n0 0 * * * root bash $BINDIR/whitelistLCN.sh; bash $BINDIR/updateWhitelist.sh  >/dev/null 2>/dev/null \n" >> /etc/crontab
fi




ctell "****** Activating smart monitor on startup"
sed -i -re "s/#(start_smartd)/\1/g" /etc/default/smartmontools
sed -i -re "s/#(smartd_opts)/\1/g"  /etc/default/smartmontools





#The necessary ones are launched from the manager after system is
#setup and loaded, not on startup
ctell "****** Removing autoload of services"
update-rc.d -f apache2       remove
update-rc.d -f postfix       remove
update-rc.d -f mysql         remove

update-rc.d -f mdadm         remove

update-rc.d -f smbd          remove
update-rc.d -f nmbd          remove
update-rc.d -f winbind       remove

# TODO decide if we support nfs
#update-rc.d -f nfs-common    remove
#update-rc.d -f rpcbind       remove


#Create non-privileged user (UID 1000)
#adduser [options] [--home DIR] [--shell SHELL] [--no-create-home] [--uid ID] [--firstuid ID] [--lastuid ID] [--ingroup GROUP | --gid ID] [--disabled-password] [--disabled-login] [--gecos GECOS] [--add_extra_groups] user
ctell "****** Create non-privileged user vtuji"
adduser --shell $BINDIR/wizard-bootstrap.sh --disabled-password --disabled-login vtuji



#Launch a shell on tty 2-4. DEBUG BUILD ONLY (removes the file every time for the proper build)
rm $BINDIR/launch-debug-console.sh
#<DEBUG>
#Setup debug console script
echo "/bin/bash </dev/tty2 >/dev/tty2 2>&1 &"  >> $BINDIR/launch-debug-console.sh
echo "/bin/bash </dev/tty3 >/dev/tty3 2>&1 &"  >> $BINDIR/launch-debug-console.sh
echo "/bin/bash </dev/tty4 >/dev/tty4 2>&1 &"  >> $BINDIR/launch-debug-console.sh
chmod 550       $BINDIR/launch-debug-console.sh
chown root:root $BINDIR/launch-debug-console.sh
#Authorise sudo on debug console script (we alter the sudoers file every time as it is previously overwritten on every build)
sed -i -re "s|(vtuji\s+ALL=.*)$|\1,/usr/local/bin/launch-debug-console.sh|g" /etc/sudoers
#</DEBUG>
# TODO check that on no-debug, these blocks have dissapeared

#Create the wizard setup bootstrapper script (will launch some debug options and then the proper wizard script)
echo "echo 'Launching wizard'"  > $BINDIR/wizard-bootstrap.sh
#<DEBUG>
echo "sudo /usr/local/bin/launch-debug-console.sh" >> $BINDIR/wizard-bootstrap.sh
#<DEBUG>
echo "exec /usr/local/bin/wizard-setup.sh"  >> $BINDIR/wizard-bootstrap.sh


############################ rc.local ##############################
#Add the forced autologin (all users disallowed to login otherwise) of
#the unprivileged user, launched 'shell' will be the management
#script, with limited interactivity
cat > /etc/rc.local  <<EOF
#!/bin/sh -e
# This script is executed at the end of each multiuser runlevel.

#Autologin non-privileged user, launched shell will be the manager script
exec /bin/login -f vtuji </dev/tty7 >/dev/tty7 2>&1
exec echo "*** Failed loading voting system management tool ***"
exit 0
EOF
#####################################################################


#Delay login to ensure it is done at the end of the asyncronous boot process
if grep --quiet -oEe "^\s*#DELAYLOGIN" /etc/default/rcS
then
    sed -i -re "s|#DELAYLOGIN=no|DELAYLOGIN=yes|"  /etc/default/rcS
fi

#Disable systemd tty spawn (to make sure no flaw will leave the system
#vulnerable to forceful login attacks). Also disable reservation, as
#tty6 is always reserved and spawned
if grep --quiet -oEe "^\s*#NAutoVTs" /etc/systemd/logind.conf
then
    sed -i -re "s|#NAutoVTs=6|NAutoVTs=0|"  /etc/systemd/logind.conf
    sed -i -re "s|#ReserveVT=6|ReserveVT=0|"  /etc/systemd/logind.conf
fi

#Disable systemd tty1 spawn (which is always launched)
rm -rf /etc/systemd/system/getty.target.wants/getty\@tty1.service


#Prevent user login (excepting root)
echo -e "------\nNo one can login to this system\n------" > /etc/nologin

#Remove root login clearance to all terminals
echo "" > /etc/securetty

#Lock unprivileged and root user passwords to disable login (set pwd to !)
sed -i -re "s/^(root:)[^:]*(:.+)$/\1\!\2/g" /etc/shadow
sed -i -re "s/^(vtuji:)[^:]*(:.+)$/\1\!\2/g" /etc/shadow


#TODO: see things at etc/security

#Disable nfs autoload  // TODO if we suport it
#mv /etc/network/if-up.d/mountnfs /trash/mountnfs 




ctell "Configure web server and PHP"
a2enmod ssl
a2enmod rewrite
a2enmod headers
a2disconf apache2-doc
a2disconf serve-cgi-bin
a2ensite default-ssl


#Install PHP file and object cache. # TODO proyecto abandonado. MAntener? sustitu�r? OPCache? https://blogs.oracle.com/opal/entry/using_php_5_5_s
ctell "****** Setup PHP cache"
pecl install apc-3.1.9
echo $'extension=apc.so\napc.rfc1867 = On\n' >/etc/php5/conf.d/apc.ini
/etc/init.d/apache2 restart



#Securing PHP:

#Don't exist anymore
#sed -i -e "/magic_quotes_gpc/ s|On|Off|g"   /etc/php5/apache2/php.ini
#sed -i -e "/register_globals/ s|On|Off|g"   /etc/php5/apache2/php.ini
#Current default value fits our needs: E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED
#sed -i -re "s/(error_reporting = ).+$/\1E_ALL \& ~E_NOTICE/g"   /etc/php5/apache2/php.ini

#Hide PHP presence and version on banners
sed -i -e "/expose_php/ s|On|Off|g"   /etc/php5/apache2/php.ini


#Logging and error showing
sed -i -e "/display_errors/ s|On|Off|g"   /etc/php5/apache2/php.ini
sed -i -e "/log_errors/ s|Off|On|g"       /etc/php5/apache2/php.ini

#Security against remote file inclusion
sed -i -e "/allow_url_fopen/ s|On|Off|g"       /etc/php5/apache2/php.ini
sed -i -e "/allow_url_include/ s|On|Off|g"     /etc/php5/apache2/php.ini


#Set required PHP parameters for security and performance
sed -i -re "s/(max_input_time = )[0-9]+/\1600/g" /etc/php5/apache2/php.ini #max_input_time 600

sed -i -re "s/(max_execution_time = )[0-9]+/\1800/g" /etc/php5/apache2/php.ini #max_execution_time 800

sed -i -re "s/(post_max_size = )[0-9]+/\1800/g" /etc/php5/apache2/php.ini #post_max_size 800M

sed -i -re "s/(upload_max_filesize = )[0-9]+/\1200/g" /etc/php5/apache2/php.ini #upload_max_filesize 200M

sed -i -re "s/(memory_limit = )[0-9]+/\11280/g" /etc/php5/apache2/php.ini #memory_limit 1280M


#Set required mysql parameters
sed -i -re "s/(max_allowed_packet\s+=\s+)[0-9]+/\11300/g" /etc/mysql/my.cnf #max_allowed_packet 1300M

sed -i -re "s/(max_binlog_size\s+=\s+)[0-9]+/\11300/g" /etc/mysql/my.cnf #max_binlog_size 1300M
    

#To be able to do the empty subject hack when mailing from PHP:
sed -i -re "s/(mail.add_x_header = )On/\1Off/gi" /etc/php5/apache2/php.ini 


#Set open_basedir to limit file access from the apps (can't do now, as /usr/share/fonts is accessed)
#open_basedir="/var/www/"


#Avoid symlinking of resources at the virtual host
#sed -i -re 's/FollowSymLinks//g'  /etc/apache2/sites-available/000-default.*
#sed -i -re 's/^\s*Options\s*$//g' /etc/apache2/sites-available/000-default.*

#Activate extended statistics on apache
aux=$(cat /etc/apache2/apache2.conf | grep -e "ExtendedStatus On")
if [ "$aux" == ""  ]
    then
    echo "ExtendedStatus On" >> /etc/apache2/apache2.conf
fi

#Hide stats page from public access
aux=$(cat /etc/apache2/apache2.conf | grep -e "Location /server-status")
if [ "$aux" == ""  ]
    then
    echo -e "<Location /server-status>\n    SetHandler server-status\n    Order Deny,Allow \n    Deny from all \n    Allow from localhost ip6-localhost\n</Location>" >> /etc/apache2/apache2.conf
fi

#Activate language negotiation (for the static application pages)
aux=$(cat /etc/apache2/apache2.conf | grep -e "MultiViews")
if [ "$aux" == ""  ]
    then
    echo -e "\n\nAddLanguage es .es\nAddLanguage en .en\nAddLanguage ca .ca\n\nLanguagePriority es en ca\nForceLanguagePriority Fallback\n\n\n<Directory /var/www>\n    Options MultiViews\n</Directory>\n" >> /etc/apache2/apache2.conf
fi

#Remove alias module configuration to reduce exposure
sed -i -re '/<Directory "\/usr/,/\/Directory/ d' /etc/apache2/mods-enabled/alias.conf
sed -i -re 's/^.*Alias \/icons.*$//g' /etc/apache2/mods-enabled/alias.conf


#Override default error pages (to avoid leaking server information. Also, redirect to index on error.
aux=$(cat /etc/apache2/conf-available/localized-error-pages.conf | grep -Ee "^\s*ErrorDocument")
if [ "$aux" == ""  ]
    then
    echo  'ErrorDocument 400 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Bad Request</h1>"' >> /etc/apache2/conf-available/localized-error-pages.conf
    echo  'ErrorDocument 403 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Forbidden</h1>"' >> /etc/apache2/conf-available/localized-error-pages.conf
    echo  'ErrorDocument 404 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Not Found</h1>"' >> /etc/apache2/conf-available/localized-error-pages.conf
    echo  'ErrorDocument 405 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Method Not Allowed</h1>"' >> /etc/apache2/conf-available/localized-error-pages.conf
    echo  'ErrorDocument 500 "<h1>Internal Server Error</h1>"' >> /etc/apache2/conf-available/localized-error-pages.conf
    echo  'ErrorDocument 503 "<h1>Service Unavailable</h1>"' >> /etc/apache2/conf-available/localized-error-pages.conf
fi





 
### voting app installation ###
ctell "***** Installing voting webapp *****"
chown www-data:www-data /var/www/tmp
pushd /var/www/tmp

#Extract installer
php mkInstaller.php -r ./ ivot.php

#Move SQL file responsible of building database (will be built when installed)
mv dump*.sql buildDB.sql
mv buildDB.sql       $BINDIR/
chmod 660 $BINDIR/buildDB.sql

#Parse necessary files to add app config  (login scripts are parsed on runtime)
for i in $(ls *.php)
  do 
  cat $i | python ./markVariables.py > aux
  mv aux $i
done

#Remove all files not needed
rm -rf ins/
rm autorun*
rm eVotingBdd.html
rm ivot.php
rm *mkInstaller*
rm vars-*.php
rm markVariables.py
rm jmp*

#Move all remaining files to the webserver root
mv * /var/www/


#Fix permissions (read for files, access for dirs) and ownership
chown -R root:www-data /var/www/
setPerm /var/www 440 110
#www-data must be allowed to list webserver root dir. Needed by multiviews
chmod 550 /var/www/


# TODO pre-install uji skin
popd
rm -rf /var/www/tmp/







#Umount special filesystems (/dev is mounted and umounted outside)
umount /proc
umount /sys
exit 42

 























#SEGUIR



#######Preparando el estado final del dirdctorio /root ############


ctell "####### Preparando el estado final del dirdctorio /root #########"

rm -r /root/*


#Establecemos el valor por defecto del bloqueo de ejecuci�n de operaciones privilegiadas
# (porm defecto no verifica la llave, porque est� en modo setup)
LOCKOPSFILE="/root/lockPrivileged"
echo "*******************$LOCKOPSFILE" 
touch $LOCKOPSFILE
echo -n "0" > $LOCKOPSFILE
chmod 400 $LOCKOPSFILE
chmod 700 /root/
echo "****************"




############ �ltimos cambios de permisos y del sistema de ficheros ##################
chmod 750 /sbin/cryptsetup   #////probar


#Aunque el chsh pide autenticarse incluso al root (y ninguno tiene pwd v�lido), me cargo la lista de login shells v�lidas, porque al login -f no le afecta y as� bloqueo cualquier programa que potencialmente lo use. 
echo "" > /etc/shells



















#Determining kernel version
export kversion=`cd /boot && ls vmlinuz-* | sed 's@vmlinuz-@@'`
ctell "CHROOT: Kernel version: $kversion"

ctell "CHROOT: Updating initramfs"
#Updating initramfs (to contain casper init scripts)
depmod -a ${kversion}
update-initramfs -u -k ${kversion}





ctell "####### Cleaning system configuration #########"


ctell "CHROOT: Deleting useless programs"
#Removing All unnecessary programs installed to compile others
apt-get remove -y gcc g++ libssl-dev autotools-dev libc-dev-bin libc6-dev libltdl-dev libpcre3-dev php5-dev linux-libc-dev manpages-dev autoconf automake  binutils m4
apt-get autoremove -y 


#Cleaning apt cache
apt-get clean


ctell "CHROOT: Deleting useless files"
#Deleting potentially interfering files
for i in "/etc/hosts /etc/hostname /etc/resolv.conf /etc/timezone /etc/fstab /etc/mtab /etc/shadow /etc/shadow- /etc/gshadow  /etc/gshadow- /etc/gdm/gdm-cdd.conf /etc/gdm/gdm.conf-custom /etc/X11/xorg.conf /boot/grub/menu.lst /boot/grub/device.map"
do
	rm $i
done




#Limpiamos Los ficheros inservibles
ctell "####### Cleaning files #########"

rm -f /root/.bash_history
rm -rf /root/src


#Cleaning useless or potentially dangerous data
rm -r /tmp/*
rm  /boot/*.bak



ctell "####### Closing LiveCD chrooted construction #######"




#Desmontamos los Fs especiales
umount /proc
umount /sys
umount /dev



ctell "CHROOT: Leaving chroot"
#Leaving chroot
exit
