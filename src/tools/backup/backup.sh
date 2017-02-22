#!/bin/bash


#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh



#Read needed passwords
DBROOTPWD=$(cat $DBROOTPWDFILE)
DATAPWD=$(cat $DATABAKPWDFILE)

#Read the needed variables
getVar disk SSHBAKSERVER
getVar disk SSHBAKPORT
getVar disk SSHBAKUSER
getVar disk SSHBAKPASSWD

getVar disk MGREMAIL





#Read current date
now=$(date +%s)

#Read the date where the next backup is scheduled
backupTime=$(dbQuery "select backup from eVotDat;")

#If zero (no backup scheduled) or still a future date, leave
[ "$backupTime" -eq "0" ] && exit
[ "$backupTime" -gt "$now" ] && exit






#If we are doing a backup, mark the backup as done, so a new run of
#the cron doesn't collide with this one (if it fails, the admin will
#be notified and he will have to reschedule or run it manually)
dbQuery "update  eVotDat set backup=0;"




#Set for the temporary files to be deleted on program exit
trap "rm /tmp/backupLog  2>/dev/null" exit



#Dump database onto temp file (in the data partition instead of on
#memory, to avoid overflowing)
mysqldump -u root -p"$DBROOTPWD" eLection > "$DATAPATH/dump.$$"




#Trust the destination ssh server
sshScanAndTrust "$SSHBAKSERVER" "$SSHBAKPORT"



#Stop all services that may alter the persistent data
stopServers


#Launch a substitution webserver with a static info page
bash /usr/local/share/simpleWeb/simpleHttp.sh start

#Gather information for the success e-mail
filelist=$(ls -lR $DATAPATH/)
overallSize=$(du -hs $DATAPATH)
detailedSize=$(du -hs $DATAPATH/*)


#Stream pack, encrypt and upload the backup file to the backup server
#(not overwriting the previous one)
tar --ignore-failed-read -zcf - $DATAPATH/*  2>>/tmp/backupLog |
    openssl enc -aes-256-cfb -pass "pass:$DATAPWD" |
    sshpass -p"$SSHBAKPASSWD" ssh -p "$SSHBAKPORT" "$SSHBAKUSER"@"$SSHBAKSERVER" "cat > vtUJI_backup-$now.tgz.aes" 2>>/tmp/backupLog
ret=$?


#Stop substitution webserver
bash /usr/local/share/simpleWeb/simpleHttp.sh stop

#Restart services again
startServers


#Delete database dump
rm $DATAPATH/dump.*  2>/dev/null




#If error on backup, notify administrator
if [ $ret -ne 0 ] ; then
    log "WARNING: SSH Backup has failed. Errors below: "$(cat /tmp/backupLog)
    
    echo -e "WARNING:\n\nSSH Backup performed on\n\n$(date +%c)\n\nhas failed. Please, check the attached file for errors and then reschedule the backup or do it manually." | mutt -s "vtUJI backup failed" -a /tmp/backupLog --  $MGREMAIL root
    
    exit 1
fi

#Backup successful. Send summary e-mail.
echo "$filelist" >> /tmp/backupLog
echo -e "Successful SSH Backup performed on\n\n$(date +%c)\n\nCheck the list of backupped files on the attached file.\n\nSize of backupped data is as follows:\n$overallSize\n\nAnd per directory:\n$detailedSize" | mutt -s "vtUJI backup successful" -a /tmp/backupLog --  $MGREMAIL root

exit 0
