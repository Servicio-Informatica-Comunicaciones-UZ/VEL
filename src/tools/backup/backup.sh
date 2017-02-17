#!/bin/bash


#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh




# TODO Add here any new file or directory that needs backup: or simply backup the whole partition after stopping mysql and apache?
#-->instead of stopping apache, mask the app behind a temp page?
#do stop here the services? remember that stopping the services is a maint op too, make reusable code.
#Store full mysql dir and also the dump? just in case?
#design recovery to be simpler: start as a new system setup but ask the ssh recovery params (limit the params to be configured to network and data drive? the rest should be inside the recovery just steps 2-4, maybe make another flow and duplicate them). once there is network and a data drive, retrieve the bak file and untar on it. Then, go on with setup. remember to read the vars from disk as if it was a restart, also ask for the usbs to get the recovery key and at the end rewrite them? --> drive and network params must be updated on the recovered config files/usbs, so the order is:
# * Get new network info,
# * setup network
# * get new drive info
# * setup new drive
# * get recovery ssh info.
# * download recovery file on the new drive
# * get usbs and rebuild key
# * extract recovery file on its location and delete the file
# * update disk variables regarding network
# * update usb variables regarding drive
# * go on with the normal setup after the load drive part (including reading the variables)
# * write the usbs with the updated drive config (or do this earlier? No, reuse the code)
FILESTOBAK="$DATAPATH/webserver/ $DATAPATH/terminalLogs $DATAPATH/root/ $DATAPATH/wizard/ $DATAPATH/rrds/ $DATAPATH/log $LOGFILE"





#Read needed passwords
DBPWD=$(cat $DBROOTPWDFILE)
DATAPWD=$(cat $DATABAKPWDFILE)

#Read the needed variables
getVar disk SSHBAKSERVER
getVar disk SSHBAKPORT
getVar disk SSHBAKUSER
getVar disk SSHBAKPASSWD

getVar disk MGREMAIL











#Mira la fecha y la marca (una fecha) de la bd que indica si se debe hacer el backup
now=$(date +%s)
bck=$(echo "select backup from eVotDat;"| mysql -u root -p"$DBPWD"  eLection | grep -Ee "[0-9]+" )


#Si el valor leido es 0 o es una fecha del futuro, salimos
[ "$bck" -eq "0" ] && exit
[ "$bck" -gt "$now" ] && exit


#Sino, hace el bak

ser="$SSHBAKSERVER"
us="$SSHBAKUSER"

#Borra el dump de la bd en cuanto el programa acabe
trap "rm $ROOTTMP/dump.$$  2>/dev/null" exit

#Saca el dump de la bd
mysqldump -u root -p"$DBPWD" eLection >$ROOTTMP/dump.$$


#Añadimos las llaves del servidor SSH al known_hosts
mkdir -p /root/.ssh/ 
ssh-keyscan -p "$SSHBAKPORT" -t rsa1,rsa,dsa "$SSHBAKSERVER" > /root/.ssh/known_hosts 2>/dev/null



# # TODO use sshpass -p pwd ssh...



#Ejecuta el empaquetado
tar --ignore-failed-read -zcf - $FILESTOBAK $ROOTTMP/dump.$$ 2>/dev/null | openssl enc -aes-256-cfb -pass "pass:$DATAPWD" | ssh -p "$SSHBAKPORT" $us@$ser "cat > vtUJI_backup.tgz.aes" 2>/dev/null


#Error? enviar e-mail al admin
if [ $? -ne 0 ] ; then

    echo  -e "WARNING:\n\nSSH Backup performed on\n\n$(date +%c)\n\nhas failed. Please, check remote server connectivity or change backup parameters on the election server." | mail  -s "vtUJI election server WARNING" $MGREMAIL

    echo  -e "WARNING:\n\nSSH Backup performed on\n\n$(date +%c)\n\nhas failed. Please, check remote server connectivity or change backup parameters on the election server." | mail  -s "vtUJI election server WARNING" root
    
    echo  -e "WARNING:\n\nSSH Backup performed on\n\n$(date +%c)\n\nhas failed. Please, check remote server connectivity or change backup parameters on the election server." >> $LOGFILE


    rm -f $ROOTTMP/dump.$$ 2>/dev/null

    
    exit 1

else
    #Si no falla, marcamos el backup como completado. (Así, si falla se reintentará de nuevo.)
    echo "update  eVotDat set backup=0" | mysql -u root -p"$DBPWD"  eLection
    
fi


rm -f $ROOTTMP/dump.$$


exit 0
