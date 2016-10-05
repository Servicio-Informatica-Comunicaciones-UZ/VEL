#!/bin/bash

LOGFILE=/tmp/wizardLog

ROOTTMP="/root/"

DATAPATH="/media/crypStorage"
VARFILE="$DATAPATH/root/vars.conf"



DBPWD=$(cat $DATAPATH/root/DatabaseRootPassword)
DATAPWD=$(cat $ROOTTMP/dataBackupPassword)

#Leer el fich de variables y grep de la correspondiente
SSHBAKSERVER=$(cat $VARFILE | grep -Ee "^SSHBAKSERVER=" | sed -re "s/^.+?=\"(.+)\"$/\1/g")
SSHBAKPORT=$(cat $VARFILE | grep -Ee "^SSHBAKPORT=" | sed -re "s/^.+?=\"(.+)\"$/\1/g")
SSHBAKUSER=$(cat $VARFILE | grep -Ee "^SSHBAKUSER=" | sed -re "s/^.+?=\"(.+)\"$/\1/g")

MGREMAIL=$(cat $VARFILE | grep -Ee "^MGREMAIL=" | sed -re "s/^.+?=\"(.+)\"$/\1/g")



FILESTOBAK="$DATAPATH/webserver/ $DATAPATH/terminalLogs $DATAPATH/root/ $DATAPATH/wizard/ $DATAPATH/rrds/ $DATAPATH/log $LOGFILE"






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

export DISPLAY=none:0.0
export SSH_ASKPASS=/usr/local/bin/askBackupPasswd.sh


#Añadimos las llaves del servidor SSH al known_hosts
mkdir -p /root/.ssh/ 
ssh-keyscan -p "$SSHBAKPORT" -t rsa1,rsa,dsa "$SSHBAKSERVER" > /root/.ssh/known_hosts 2>/dev/null


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
