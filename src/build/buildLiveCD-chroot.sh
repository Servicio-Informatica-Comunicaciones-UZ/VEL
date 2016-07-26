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

        # TODO remove when we substitute the logon with the management script.
        passwd


 
# TODO pensarme si soporto nfs
#    ctell "CHROOT: Installing conflictive custom package: nfs"
#    (apt-get -f install -y nfs-common)    
#    #Si falla la instalación y peta el sub-shell, hacer el reconfigure
        #    [ "$?" -ne 0 ] && dpkg --configure -a
        
fi  #Fin del modo -r




#Generate DH parameters for the apache SSL
if [ $GENERATEDHPARAMS -eq "1" ]
    then
        ctell "Generating 4096 bit Diffie Helman parameters for SSL"
        openssl dhparam -out /etc/ssl/dhparams.pem 4096
fi



ctell "***** Building Secret Sharing tool"
pushd  /root/src/tools/ssss/
make
cp ssOperations $BINDIR
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






ctell "***** Copying utilities"

cp -fv /root/src/mgr/bin/*  $BINDIR
   

cp -fv /root/src/sys/config/webserver/ssl-config.conf  /etc/apache2/sites-available/

cp -fv /root/src/sys/config/php/timezones              /usr/local/share/

cp -fv /root/src/sys/config/ntpd/ntpd.conf             /etc/openntpd/


cp -fv /root/src/data/config/main.cf             /etc/postfix/



cp -fv /root/src/version                         /etc/vtUJIversion

# Alias de correo, para que el root reciba todas las notificaciones 
#enviadas a los usuarios específicos de las aplicaciones.
cp -fv /root/src/data/config/aliases             /etc/




cp -fv /root/src/data/config/misc/sudoers           /etc/





#Desmontamos los Fs especiales
umount /proc
umount /sys
#umount /dev
exit 42


#Aseguramos que el propietario es el root
chown root:root /usr/local/bin/*


#Damos permisos de ejecución a los ficheros
pushd /usr/local/bin/

chmod 550 ./*

#Damos permiso a algunos para que accedan usuarios no privilegiados
chmod o+rx addslashes combs.py common.sh wizard-setup.sh wizard-maintenance.sh wizard-common.sh genPwd.php separateCerts.py urlencode

chmod 444 pm-utils*.deb

popd


#Los scripts privilegiados, sólo puede ejecutarlos el root (vtuji puede con sudo).
chmod 500 /usr/local/bin/privileged-ops.sh
chmod 500 /usr/local/bin/privileged-setup.sh



#Setuid para el ejecutable de sginfo  #//// Creo que no hace falta. pruebo a ver (he quitado el setuid en al vm).
#chmod ug+s /usr/bin/sginfo







#Copiamos los elementos necesarios para instalar la app web a un directorio temporal
rm -rf   /var/www/*
mkdir -p /var/www/tmp/
cp -f /root/src/build/bundles/ivot.php          /var/www/tmp/
cp -f /root/src/build/mkInstaller.php           /var/www/tmp/
cp -f /root/src/build/markVariables.py          /var/www/tmp/




#copiamos las sources del proyecto empleadas al CD, por tansparencia.
#Borramos los datos del subversion y de trabajo
find   /root/src/   -iname ".svn" | xargs rm -rf
rm -rf /root/src/doc/Auditory
rm -rf /root/src/doc/onWork
rm -rf /root/src/doc/sources
rm -f  /root/src/myBuild.sh
rm -rf /root/src/test-tools

tar czf /vtUJI-$(cat /root/src/version)-source.tgz /root/src/  






ctell "***************** CHROOT: Realizando ajustes sobre el sistema *******************"


#read -p "*** Desea aplicar los ajustes de VtUJI (no generara el LiveCD generico) (Y/n)? " VTUJITUNE
#if [ "$VTUJITUNE" == "n" ]
#    then
#    exit 0;
#fi



#ctell "CHROOT: Removing Networking script from init"
#Remove networking script from init (workaround to avoid hangups during startup)
#Now we don't remove it, to properly launch firewall, hoping the bug is solved
#update-rc.d -f networking remove





#FIREWALL INICIAL
# Configuración del firewall que se aplicará en cuanto se inicie el sistema de red.
if $(cat /etc/init.d/networking | grep -e "^\. /.*firewall.sh$")
    then
    :
else
    #Incluye el script con las reglas
    sed -i -re "s|(^.*init-functions.*$)|\1\n. /usr/local/bin/firewall.sh|"  /etc/init.d/networking
    
    #Ejecuta la regla
    sed -i -re "s|(^.*upstart-job.*start.*$)|\1\n        setupFirewall 'ssl'|" /etc/init.d/networking
fi










#Establecemos la configuración del servidor openntpd
#cp -f /root/src/data/config/ntpd.conf         /etc/openntpd/  #Esto se hace Arriba

sed -i -re "s/#(DAEMON_OPTS.*)/\1/g" /etc/default/openntpd





#Instalamos la caché de programas para PHP, para acelerar la ejecución.
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






#Alterar el script casper para que se incie sesión con el root 
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




#Quitamos el login al root en todos los terminales
echo "" > /etc/securetty


#Quitamos los privilegios sudo
sed -i -r -e "/sed.+admin/ s|s/.+?/.+?/'|s/%admin/#%admin/'|"  /usr/share/initramfs-tools/scripts/casper-bottom/10adduser
sed -i -r -e "s/echo '%admin.*'/echo ''/"  /usr/share/initramfs-tools/scripts/casper-bottom/10adduser


#Apache SSL  
#ctell "Closing port 80"
#sed -i -re "s/^NameVirtualHost/#NameVirtualHost/g" /etc/apache2/ports.conf
#sed -i -re "s/^Listen 80/#Listen 80/g" /etc/apache2/ports.conf


ctell "Redirecting port 80 to 443"
#didit=$(grep /etc/apache2/sites-enabled/000-default -e "RewriteEngine")
#if [ "$didit" == "" ]
if [ -f /etc/apache2/sites-enabled/000-default.sslredirect ]
    then
    :
else
    #Sacamos una copia del fichero para cada modalidad (webserver ssl o no.)
    cp /etc/apache2/sites-enabled/000-default /etc/apache2/sites-available/000-default.sslredirect
    cp /etc/apache2/sites-enabled/000-default /etc/apache2/sites-available/000-default.noredirect
    
    #Añadimos las reglas de redirección a ssl
    sed -i -re "s/(.*VirtualHost.*:80.*$)/\1\nRewriteEngine On\nRewriteCond %{HTTPS} off\nRewriteRule (.*) https:\/\/%{HTTP_HOST}%{REQUEST_URI} [L,R]\n/" /etc/apache2/sites-available/000-default.sslredirect
fi






# Para redirigir automáticamente las peticiones del pto 80 al ssl
#	RewriteEngine On
#	RewriteCond %{HTTPS} off
#	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI} [L,R]


ctell "Enabling ssl server"
ln -s /etc/apache2/sites-available/ssl-config.conf /etc/apache2/sites-enabled/



ctell "Enabling mod rewrite"
#ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/
a2enmod rewrite




#Deshabilitamos el auto-arranque del iscsi y el nfs
rm /etc/network/if-up.d/open-iscsi
rm /etc/network/if-down.d/open-iscsi

mv /etc/network/if-up.d/mountnfs /trash/mountnfs 








### Instalación de la aplicación de voto ###
ctell "installing voting app"
chown www-data:www-data /var/www/tmp

cd /var/www/tmp

#Descomprimimos el instalador
php mkInstaller.php -r ./ ivot.php


mv dump*.sql buildDB.sql


# Funciona el language negotiation del apache. El problema era el poltergeist de que el directorio /var/www 
#  no se podía listar por www-data a pesar de tener permisos.


#Parseamos los ficheros necesarios  (atención: NO parseamos los scripts de login, Eso lo haremos en run time)
for i in $(ls *.php)
  do 
  cat $i | python ./markVariables.py > aux
  mv aux $i
done



#copy sql file responsible of building database 
mv buildDB.sql       /usr/local/bin/
chmod 660 /usr/local/bin/buildDB.sql

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


#Activamos la recogida extendida de estadísticas en el apache
aux=$(cat /etc/apache2/apache2.conf | grep -e "ExtendedStatus On")
if [ "$aux" == ""  ]
    then
    echo "ExtendedStatus On" >> /etc/apache2/apache2.conf
fi

#Evitamos el acceso externo libre a las estadísticas
aux=$(cat /etc/apache2/httpd.conf | grep -e "Location /server-status")
if [ "$aux" == ""  ]
    then
    echo -e "<Location /server-status>\n    SetHandler server-status\n    Order Deny,Allow \n    Deny from all \n    Allow from localhost ip6-localhost\n</Location>" >> /etc/apache2/httpd.conf
fi




#Cambiamos los parámetros del php:
sed -i -re "s/(max_input_time = )[0-9]+/\1600/g" /etc/php5/apache2/php.ini #max_input_time 600

sed -i -re "s/(post_max_size = )[0-9]+/\1800/g" /etc/php5/apache2/php.ini #post_max_size 800M

sed -i -re "s/(upload_max_filesize = )[0-9]+/\1200/g" /etc/php5/apache2/php.ini #upload_max_filesize 200M

sed -i -re "s/(memory_limit = )[0-9]+/\11280/g" /etc/php5/apache2/php.ini #memory_limit 1280M



#Para ocultar la versión del php
sed -i -re "s/(expose_php = )On/\1Off/gi" /etc/php5/apache2/php.ini 




#Cambiamos los parámetros del mysql
sed -i -re "s/(max_allowed_packet\s+=\s+)[0-9]+/\11300/g" /etc/mysql/my.cnf #max_allowed_packet 1300M

sed -i -re "s/(max_binlog_size\s+=\s+)[0-9]+/\11300/g" /etc/mysql/my.cnf #max_binlog_size 1300M
    


#Para poder hacer el hack del subject vacio en php:
sed -i -re "s/(mail.add_x_header = )On/\1Off/gi" /etc/php5/apache2/php.ini 





#Activamos el language negotiation para la página de ayuda, etc.
aux=$(cat /etc/apache2/httpd.conf | grep -e "MultiViews")
if [ "$aux" == ""  ]
    then
    echo -e "\n\nAddLanguage es .es\nAddLanguage en .en\nAddLanguage ca .ca\n\nLanguagePriority es en ca\nForceLanguagePriority Fallback\n\n\n<Directory /var/www>\n    Options MultiViews\n</Directory>\n" >> /etc/apache2/httpd.conf
fi


#Reduce la info proporcionada por el apache en las cabeceras http
sed -i -re "s/(^\s*ServerTokens ).+$/\1Prod/g" /etc/apache2/conf.d/security



#Quitamos los directorios inútiles del servidor web.
sed -i -re '/<Directory "\/usr/,/\/Directory/ d' /etc/apache2/sites-available/000-default.*
sed -i -re 's/^.*Alias \/cgi.*$//g' /etc/apache2/sites-available/000-default.*
sed -i -re 's/^.*Alias \/doc.*$//g' /etc/apache2/sites-available/000-default.*

sed -i -re '/<Directory "\/usr/,/\/Directory/ d' /etc/apache2/mods-enabled/alias.conf
sed -i -re 's/^.*Alias \/icons.*$//g' /etc/apache2/mods-enabled/alias.conf


#Evitamos que se puedan publicar enlaces en el servidor web.
sed -i -re 's/FollowSymLinks//g'  /etc/apache2/sites-available/000-default.*
sed -i -re 's/^\s*Options\s*$//g' /etc/apache2/sites-available/000-default.*



#Ocultamos la página de error estándar. Además redirige a la principal.
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

 
 
 


# Instalamos el script que actualiza la whitelist de la LCN en el firewall cada día a las 0:00
aux=$(cat /etc/crontab | grep firewallWhitelist)
if [ "$aux" == "" ] 
    then
    echo -e "\n0 0 * * * root bash /usr/local/bin/firewallWhitelist.sh  >/dev/null 2>/dev/null\n" >> /etc/crontab  
fi





#Instalamos las locales en un idioma cualquiera, puesto que hace falta para poder usar las locales de mi script (esta func sólo está en ubuntu)
/usr/share/locales/install-language-pack es_ES

#Para cada idioma disponible,
langs=$(ls -p /root/src/localization/ | grep  -oEe "[^/]+/$" | sed -re "s|(.*)/$|\1|g")
for la in $langs
  do
  #copiamos el fichero de locales compilado a su ubicación en el sistema
  cp -f /root/src/localization/$la/*.mo  /usr/share/locale/$la/LC_MESSAGES/
  
  #copiamos las licencias al directorio, con la extension de su idioma
  cp -f /root/src/localization/$la/License  /usr/share/doc/License.$la
  
  #copiamos el Readme de la firma del cert al directorio, con la extension de su idioma
  cp -f /root/src/localization/$la/eLectionLiveCD-README.txt   /usr/share/doc/eLectionLiveCD-README.txt.$la
  
done




#Copiamos el paquete de pm-utils, para distribuirlo con el cd y reinstalarlo en vivo. Parece ser que en el configure realiza acciones dependientes del hardware de la máquina host. Así que la única forma de que funcione es instalarlo sobre el host
#Fallará todas las veces excepto cuando el sistema se construya de cero, porque limpio la cache de paquetes
cp -f /var/cache/apt/archives/pm-utils* /usr/local/bin/



#Crear el usuario vtuji. (El UID será 1000)
adduser --shell /usr/local/bin/wizard-setup.sh --disabled-password --disabled-login vtuji

#adduser [options] [--home DIR] [--shell SHELL] [--no-create-home] [--uid ID] [--firstuid ID] [--lastuid ID] [--ingroup GROUP | --gid ID] [--disabled-password] [--disabled-login] [--gecos GECOS] [--add_extra_groups] user




#######Preparando el estado final del dirdctorio /root ############


ctell "####### Preparando el estado final del dirdctorio /root #########"

rm -r /root/*


#Establecemos el valor por defecto del bloqueo de ejecución de operaciones privilegiadas
# (porm defecto no verifica la llave, porque está en modo setup)
LOCKOPSFILE="/root/lockPrivileged"
echo "*******************$LOCKOPSFILE" 
touch $LOCKOPSFILE
echo -n "0" > $LOCKOPSFILE
chmod 400 $LOCKOPSFILE
chmod 700 /root/
echo "****************"




############ Últimos cambios de permisos y del sistema de ficheros ##################
chmod 750 /sbin/cryptsetup   #////probar


#Aunque el chsh pide autenticarse incluso al root (y ninguno tiene pwd válido), me cargo la lista de login shells válidas, porque al login -f no le afecta y así bloqueo cualquier programa que potencialmente lo use. 
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

