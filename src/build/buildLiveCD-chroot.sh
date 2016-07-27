#!/bin/bash
#This is the LiveCD building script executed inside the chroot

. /root/src/build/build-tools.sh
. /root/src/build/build-config.sh


#Default env to allow proper parsing
export HOME=/root
export LC_ALL=C
export LANG=""

cd $HOME

# TODO: in prod, apache logs go to null, at least during elections.


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
        echo -e "----------\nYou will be prompted to choose keyboard type. Please, select qwerty and press RETURN\n----------)" && read
        echo "console-data	console-data/keymap/qwerty/layout	select	US american" | debconf-set-selections
        echo "keyboard-configuration	keyboard-configuration/xkb-keymap	select	en" | debconf-set-selections
        echo "keyboard-configuration	keyboard-configuration/variant	select	English (US)" | debconf-set-selections
        #</DEBUG>
        
                
        apt-get -f install -y --force-yes ${PCKGS}
        
        
        #Copy the pm-utils package, as it needs to be reconfigured on every boot for hardware dependencies
        cp -fv /var/cache/apt/archives/pm-utils*.deb   $BINDIR/
        chmod 444 $BINDIR/pm-utils*.deb
        
        # TODO remove when we substitute the logon with the management script.
        passwd


 
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
   

cp -fv /root/src/sys/config/webserver/000-default.conf  /etc/apache2/sites-available/
cp -fv /root/src/sys/config/webserver/default-ssl.conf  /etc/apache2/sites-available/

cp -fv /root/src/sys/config/php/timezones              /usr/local/share/

cp -fv /root/src/sys/config/ntpd/ntpd.conf             /etc/openntpd/

cp -fv /root/src/sys/config/mailer/main.cf             /etc/postfix/

#All aliases set to root, so he receives all mail notifications
#adressed to specific app users
cp -fv /root/src/sys/config/misc/aliases               /etc/

#Non-privileged user is allowed to invoke privileged ops scripts
#acting as root
cp -fv /root/src/sys/config/misc/sudoers               /etc/



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



#Build bundle with the used sources, so everything can be audited.
find   /root/src/   -iname ".svn" | xargs rm -rf
tar czf /root/source-$VERSION.tgz /root/src/  





ctell "****** System tuning"


#FIREWALL INICIAL
# Configuraci�n del firewall que se aplicar� en cuanto se inicie el sistema de red.
if $(cat /etc/init.d/networking | grep -e "^\. /.*firewall.sh$")
    then
    :
else
    #Incluye el script con las reglas
    sed -i -re "s|(^.*init-functions.*$)|\1\n. $BINDIR/firewall.sh|"  /etc/init.d/networking
    
    #Ejecuta la regla
    sed -i -re "s|(^.*upstart-job.*start.*$)|\1\n        setupFirewall 'ssl'|" /etc/init.d/networking
fi





#Desmontamos los Fs especiales
umount /proc
umount /sys
#umount /dev
exit 42





#Instalamos la cach� de programas para PHP, para acelerar la ejecuci�n.
pecl install apc-3.1.7
echo $'extension=apc.so\napc.rfc1867 = On\n' >/etc/php5/conf.d/apc.ini
/etc/init.d/apache2 restart





# Activando SMARTmonTools
#Cambiamos los params del defaults para que se lance el daemon
sed -i -re "s/#(enable_smart)/\1/g" /etc/default/smartmontools
sed -i -re "s/#(start_smartd)/\1/g" /etc/default/smartmontools





#Quitar servicios innecesarios del rc.d
ctell "Stopping external services"
update-rc.d -f apache2       remove

update-rc.d -f mysql         remove
update-rc.d -f mysql-ndb     remove
update-rc.d -f mysql-ndb-mgm remove

update-rc.d -f open-iscsi    remove

update-rc.d -f portmap       remove
update-rc.d -f nfs-common    remove

update-rc.d -f postfix       remove

update-rc.d -f mdadm         remove #Lo quito para activar luego el monitor a mi estilo






#Alterar el script casper para que se incie sesi�n con el root 
#sed -i -e "s|login -f \$USERNAME|login -f root|g" /usr/share/initramfs-tools/scripts/casper-bottom/25configure_init


#Autorizamos el login de root en una consola por tty 3 (falla porque luego el casper altera el script)
#sed -i -re 's|^exec.*|exec /bin/login -f root </dev/tty3 >/dev/tty3 2>&1|g' /etc/event.d/tty3


#Alterar el autologin para desactivarlo (por si falla el script, que no lance un terminal.)
ctell "Altering autologin casper script"
sed -i -re "s|exec[ ]+/bin/login[^|]+|exec /bin/false|g" /usr/share/initramfs-tools/scripts/casper-bottom/25configure_init 

#sed -i -re 's|exec /bin/false|exec /bin/login -f root </dev/tty3 >/dev/tty3 2>\&1|g'  /usr/share/initramfs-tools/scripts/casper-bottom/25configure_init #trash


#Establecemos que se impida el acceso login a cualquiera menos el root
echo -e "------\nNo one can login\n------" > /var/lib/initscripts/nologin



#Quitamos el login al usuario ubuntu y al root
sed -i -e "s|passwd/user-password-crypted .*|passwd/user-password-crypted !|" /usr/share/initramfs-tools/scripts/casper-bottom/10adduser
sed -i -e "s|passwd/root-password-crypted .*|passwd/root-password-crypted !|" /usr/share/initramfs-tools/scripts/casper-bottom/10adduser






#Si falla probar con exec /bin/login -f vtuji </dev/tty7 >/dev/tty7 2>&1  #En principio no falla

############################ rc.local ##############################

cat > /etc/rc.local  <<EOF
#!/bin/sh -e
# This script is executed at the end of each multiuser runlevel.


#Lanzamos un bash en el tty 2 , para debug.
/bin/bash </dev/tty2 >/dev/tty2 2>&1 & #!!!!
#Lanzamos un bash en el tty 3 , para debug.
/bin/bash </dev/tty3 >/dev/tty3 2>&1 & #!!!!
#Lanzamos un bash en el tty 4 , para debug.
/bin/bash </dev/tty4 >/dev/tty4 2>&1 & #!!!!

exec /bin/login -f vtuji </dev/tty7 >/dev/tty7 2>&1
exec echo "*** Failed Loading eSurvey Configuration Script ***"
exit 0
EOF


#####################################################################




#Remove root login clearance to all terminals
echo "" > /etc/securetty



ctell "Enabling https server"
a2enmod ssl
a2enmod rewrite
a2ensite default-ssl



#Deshabilitamos el auto-arranque del iscsi y el nfs
rm /etc/network/if-up.d/open-iscsi
rm /etc/network/if-down.d/open-iscsi

mv /etc/network/if-up.d/mountnfs /trash/mountnfs 








### Instalaci�n de la aplicaci�n de voto ###
ctell "installing voting app"
chown www-data:www-data /var/www/tmp

cd /var/www/tmp

#Descomprimimos el instalador
php mkInstaller.php -r ./ ivot.php


mv dump*.sql buildDB.sql


# Funciona el language negotiation del apache. El problema era el poltergeist de que el directorio /var/www 
#  no se pod�a listar por www-data a pesar de tener permisos.


#Parseamos los ficheros necesarios  (atenci�n: NO parseamos los scripts de login, Eso lo haremos en run time)
for i in $(ls *.php)
  do 
  cat $i | python ./markVariables.py > aux
  mv aux $i
done



#copy sql file responsible of building database 
mv buildDB.sql       $BINDIR/
chmod 660 $BINDIR/buildDB.sql

#Eliminamos todos los ficheros innecesarios
rm -rf ins/
rm autorun*
rm eVotingBdd.html
rm ivot.php
rm *mkInstaller*
rm vars-*.php
rm markVariables.py
rm jmp*

#Movemos los ficheros restantes al directorio raiz
mv * /var/www/


#Arreglamos los permisos

chown -R root:www-data /var/www/  #////Probar(el subdr aps y aps/lib deberian tener todo con el root como prop., y la raiz tb)

#Perm de fichers y perm de dirs
setPerm /var/www 440 110

#Cambiamos permisos del directorio web (para permitir el listado del directorio a www-data) #por el multiviews
chmod 550 /var/www/

cd -

rm -rf /var/www/tmp/ 







#Cambiamos la config de seguridad del php.
sed -i -e "/magic_quotes_gpc/ s|On|Off|g"   /etc/php5/apache2/php.ini
sed -i -e "/register_globals/ s|On|Off|g"   /etc/php5/apache2/php.ini


sed -i -re "s/(error_reporting = ).+$/\1E_ALL \& ~E_NOTICE/g"   /etc/php5/apache2/php.ini


#Activamos la recogida extendida de estad�sticas en el apache
aux=$(cat /etc/apache2/apache2.conf | grep -e "ExtendedStatus On")
if [ "$aux" == ""  ]
    then
    echo "ExtendedStatus On" >> /etc/apache2/apache2.conf
fi

#Evitamos el acceso externo libre a las estad�sticas
aux=$(cat /etc/apache2/httpd.conf | grep -e "Location /server-status")
if [ "$aux" == ""  ]
    then
    echo -e "<Location /server-status>\n    SetHandler server-status\n    Order Deny,Allow \n    Deny from all \n    Allow from localhost ip6-localhost\n</Location>" >> /etc/apache2/httpd.conf
fi




#Cambiamos los par�metros del php:
sed -i -re "s/(max_input_time = )[0-9]+/\1600/g" /etc/php5/apache2/php.ini #max_input_time 600

sed -i -re "s/(post_max_size = )[0-9]+/\1800/g" /etc/php5/apache2/php.ini #post_max_size 800M

sed -i -re "s/(upload_max_filesize = )[0-9]+/\1200/g" /etc/php5/apache2/php.ini #upload_max_filesize 200M

sed -i -re "s/(memory_limit = )[0-9]+/\11280/g" /etc/php5/apache2/php.ini #memory_limit 1280M



#Para ocultar la versi�n del php
sed -i -re "s/(expose_php = )On/\1Off/gi" /etc/php5/apache2/php.ini 




#Cambiamos los par�metros del mysql
sed -i -re "s/(max_allowed_packet\s+=\s+)[0-9]+/\11300/g" /etc/mysql/my.cnf #max_allowed_packet 1300M

sed -i -re "s/(max_binlog_size\s+=\s+)[0-9]+/\11300/g" /etc/mysql/my.cnf #max_binlog_size 1300M
    


#Para poder hacer el hack del subject vacio en php:
sed -i -re "s/(mail.add_x_header = )On/\1Off/gi" /etc/php5/apache2/php.ini 





#Activamos el language negotiation para la p�gina de ayuda, etc.
aux=$(cat /etc/apache2/httpd.conf | grep -e "MultiViews")
if [ "$aux" == ""  ]
    then
    echo -e "\n\nAddLanguage es .es\nAddLanguage en .en\nAddLanguage ca .ca\n\nLanguagePriority es en ca\nForceLanguagePriority Fallback\n\n\n<Directory /var/www>\n    Options MultiViews\n</Directory>\n" >> /etc/apache2/httpd.conf
fi


#Reduce la info proporcionada por el apache en las cabeceras http
sed -i -re "s/(^\s*ServerTokens ).+$/\1Prod/g" /etc/apache2/conf.d/security



#Quitamos los directorios in�tiles del servidor web.
sed -i -re '/<Directory "\/usr/,/\/Directory/ d' /etc/apache2/sites-available/000-default.*
sed -i -re 's/^.*Alias \/cgi.*$//g' /etc/apache2/sites-available/000-default.*
sed -i -re 's/^.*Alias \/doc.*$//g' /etc/apache2/sites-available/000-default.*

sed -i -re '/<Directory "\/usr/,/\/Directory/ d' /etc/apache2/mods-enabled/alias.conf
sed -i -re 's/^.*Alias \/icons.*$//g' /etc/apache2/mods-enabled/alias.conf


#Evitamos que se puedan publicar enlaces en el servidor web.
sed -i -re 's/FollowSymLinks//g'  /etc/apache2/sites-available/000-default.*
sed -i -re 's/^\s*Options\s*$//g' /etc/apache2/sites-available/000-default.*



#Ocultamos la p�gina de error est�ndar. Adem�s redirige a la principal.
aux=$(cat /etc/apache2/httpd.conf | grep -e "ErrorDocument")
if [ "$aux" == ""  ]
    then
    echo  '';
    echo  'ErrorDocument 400 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Bad Request</h1>"' >> /etc/apache2/httpd.conf
    echo  'ErrorDocument 403 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Forbidden</h1>"' >> /etc/apache2/httpd.conf
    echo  'ErrorDocument 404 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Not Found</h1>"' >> /etc/apache2/httpd.conf
    echo  'ErrorDocument 405 "<head><meta http-equiv=\"refresh\" content=\"2;URL=/index.php\"></head><h1>Method Not Allowed</h1>"' >> /etc/apache2/httpd.conf
    echo  'ErrorDocument 500 "<h1>Internal Server Error</h1>"' >> /etc/apache2/httpd.conf
    echo  'ErrorDocument 503 "<h1>Service Unavailable</h1>"' >> /etc/apache2/httpd.conf
fi

 
 
 


# Instalamos el script que actualiza la whitelist de la LCN en el firewall cada d�a a las 0:00
aux=$(cat /etc/crontab | grep firewallWhitelist)
if [ "$aux" == "" ] 
    then
    echo -e "\n0 0 * * * root bash $BINDIR/firewallWhitelist.sh  >/dev/null 2>/dev/null\n" >> /etc/crontab  
fi





#Instalamos las locales en un idioma cualquiera, puesto que hace falta para poder usar las locales de mi script (esta func s�lo est� en ubuntu)
/usr/share/locales/install-language-pack es_ES

#Para cada idioma disponible,
langs=$(ls -p /root/src/localization/ | grep  -oEe "[^/]+/$" | sed -re "s|(.*)/$|\1|g")
for la in $langs
  do
  #copiamos el fichero de locales compilado a su ubicaci�n en el sistema
  cp -f /root/src/localization/$la/*.mo  /usr/share/locale/$la/LC_MESSAGES/
  
  #copiamos las licencias al directorio, con la extension de su idioma
  cp -f /root/src/localization/$la/License  /usr/share/doc/License.$la
  
  #copiamos el Readme de la firma del cert al directorio, con la extension de su idioma
  cp -f /root/src/localization/$la/eLectionLiveCD-README.txt   /usr/share/doc/eLectionLiveCD-README.txt.$la
  
done








#Crear el usuario vtuji. (El UID ser� 1000)
adduser --shell $BINDIR/wizard-setup.sh --disabled-password --disabled-login vtuji

#adduser [options] [--home DIR] [--shell SHELL] [--no-create-home] [--uid ID] [--firstuid ID] [--lastuid ID] [--ingroup GROUP | --gid ID] [--disabled-password] [--disabled-login] [--gecos GECOS] [--add_extra_groups] user




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

