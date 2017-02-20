#!/bin/bash


#Common functions for privileged and unprivileged scripts.
. /usr/local/bin/common.sh

#Common functions for privileged scripts
. /usr/local/bin/privileged-common.sh





# TODO backup the whole partition after stopping mysql and apache -->instead of stopping apache, mask the app behind a temp page?
# --> do stop here the services? remember that stopping the services is a maint op too, make reusable code.
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
trap "rm $DATAPATH/dump.$$  2>/dev/null" exit
trap "rm /tmp/backupErrorLog  2>/dev/null" exit



#Dump database onto temp file (in the data partition instead of on
#memory, to avoid overflowing)
mysqldump -u root -p"$DBROOTPWD" eLection > "$DATAPATH/dump.$$"




#Trust the destination ssh server
sshScanAndTrust "$SSHBAKSERVER" "$SSHBAKPORT"



#Gather information for the success e-mail
filelist=$(ls -lR $DATAPATH/)



#Stop all services that may alter the persistent data
stopServers

# TODO SEGUIR MAÑANA integrar el servidor https/s temporal


#stream pack, encrypt and upload the backup file to the backup server
#(not overwriting the previous one)
tar --ignore-failed-read -zcf - $DATAPATH/*  2>/tmp/backupErrorLog |
    openssl enc -aes-256-cfb -pass "pass:$DATAPWD" |
    sshpass -p"$SSHBAKPASSWD" ssh -p "$SSHBAKPORT" "$SSHBAKUSER"@"$SSHBAKSERVER" "cat > vtUJI_backup-$now.tgz.aes" 2>/tmp/backupErrorLog
ret=$?

#Restart services again
startServers


#If error on backup, notify administrator
if [ $ret -ne 0 ] ; then
    log "WARNING: SSH Backup has failed. Errors below: "$(cat /tmp/backupErrorLog)
    
    echo -e "WARNING:\n\nSSH Backup performed on\n\n$(date +%c)\n\nhas failed. Please, check the attached file for errors and then reschedule the backup or do it manually." | mutt -s "vtUJI backup failed" -a /tmp/backupErrorLog --  $MGREMAIL root
    
    exit 1
fi

#Backup successful. Send summary e-mail.
echo -e "Successful SSH Backup performed on\n\n$(date +%c)\n\n. Check the list of backupped files on the attached file. Size of backupped data is as follows: "$(du -hs $DATAPATH)"\n And per directory: "$(du -hs $DATAPATH/*) | mutt -s "vtUJI backup failed" -a /tmp/backupErrorLog --  $MGREMAIL root

exit 0
