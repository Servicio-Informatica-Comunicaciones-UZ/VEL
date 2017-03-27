#Useful debugging code snippets for bash

#Breakpoint
echo "Press RETURN to continue..." && read


# set -x activates trace mode on bash (like 'bash -x script.sh' ), which will print on stderr and this will go to tty2
exec 2>/dev/tty2
set -x


# Debugging tool: Every time a command return value is non-zero, it will stop and show the prompt on stderr
#   ERR , on every non-zero return/exit
#  EXIT , on every zero return/exit
# DEBUG , on every simple command
#RETURN , on every function return
trap "read -p 'NON ZERO RETURN DETECTED (check if OK). Press return to go on.'" ERR



#To limit execution time
function launch () { (eval "$1" & p=$! ; (sleep $2; kill $p 2>/dev/null) & wait $p) ; }


#To set $? to the desired value (if at some point we need to reset that value, or when debugging to simulate the output of a previous call)
dummyretval() { return $1; }


#Scans for RAID volumes.
mdadm --examine --scan --config=partitions >/tmp/mdadm.conf  2>>$LOGFILE


#Load an array
#Changed --run by --no-degraded to avoid loading degraded arrays
mdadm --assemble --scan --no-degraded --config=/tmp/mdadm.conf --auto=yes >>$LOGFILE 2>>$LOGFILE


#Create a RAID (create a superblock in each disk)
mdadm --create /dev/md0 --level=raid1 --raid-devices=2 /dev/hda1 /dev/hdc1
#Create partition table:
fdisk /dev/md0 # c(dos compatibility off) u(units to sectors) o (new table) n (new partition) w

#Check RAID status or of each disk
mdadm --detail /dev/md0
mdadm --examine /dev/sda
cat /proc/mdstat #instead of the string [UU] you will see [U_] if you have a degraded RAID1 array.

#Check state of operations:
cat /proc/mdstat
    
#Rebuild degraded RAID:
mdadm --fail /dev/md0 /dev/hdc1    #Mark disk as failed
mdadm --remove /dev/md0 /dev/hdc1  #Delete disk from array
# **shutdown and replace disk**
mdadm --zero-superblock /dev/hdc1  #Just in case the disk came from another RAID
mdadm --add /dev/md0 /dev/hdc1     #Add the disk to the array




#Convert cert from  der to pem
openssl x509 -inform DER -outform PEM -in "$1" -out /tmp/cert.pem



# Change kernel log level so it only prints the most critical messages
# on the perminals (currently, default debian value)
echo "1  1  1  1" > /proc/sys/kernel/printk



#     ##Validate trust in cert##
#     validated=0
#     for cacert in $(find /usr/share/ca-certificates/ -iname "*.crt")
#  	  do
#	        iserror=$(openssl verify -CAfile "$cacert" -purpose sslserver "$c"|grep -ioe "error")	
#	        #if no error string, it has been verified
#         [ "$iserror" == ""  ] && validated=1 && break
#     done
#        
#     if [ $validated -eq 0 ] 
#	    then
#         $dlg --msgbox $"Error: certificate signed by non-trusted CA." 0 0 
#	        return 1
#     fi



#To validate any domain name
#  /^([a-z0-9]([-a-z0-9]*[a-z0-9])?\\.)+((a[cdefgilmnoqrstuwxz]|aero|arpa)|(b[abdefghijmnorstvwyz]|biz)|(c[acdfghiklmnorsuvxyz]|cat|com|coop)|d[ejkmoz]|(e[ceghrstu]|edu)|f[ijkmor]|(g[abdefghilmnpqrstuwy]|gov)|h[kmnrtu]|(i[delmnoqrst]|info|int)|(j[emop]|jobs)|k[eghimnprwyz]|l[abcikrstuvy]|(m[acdghklmnopqrstuvwxyz]|mil|mobi|museum)|(n[acefgilopruz]|name|net)|(om|org)|(p[aefghklmnrstwy]|pro)|qa|r[eouw]|s[abcdeghijklmnortvyz]|(t[cdfghjklmnoprtvwz]|travel)|u[agkmsyz]|v[aceginu]|w[fs]|y[etu]|z[amw])$/i


#To check syntax of a iscsi target name
#"iscsitar" )
#	           echo "$2" | grep -oEe "(^eui\.[0-9A-Fa-f]+|iqn\.[0-9]{4}-[0-9]{2}\.([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+[a-z]+(:[^ ]*?)?)$" 2>&1 >/dev/null
#	           [ $? -ne 0 ] && ret=1
#	           ;;

#Email parsing regexps:
#Deprecated e-mail regexp. issues with openssl. "^[-A-Za-z0-9!#%\&\`_=\/$\'*+?^{}|~.]+@[-.a-zA-Z]+$"
#Too weird, no-one uses it: "^[-A-Za-z0-9!#%\&\`_=$*+?^{}|~.]+@[-.a-zA-Z]+$"



#Cast list to array
parts=( $(echo -n $parts | grep -oEe "/dev/[a-z]+[0-9]+") )
echo ${parts[1]}


#Strip the partition number from a dev path to return the dev only
getPartitionDev () {
    local dirn=$(dirname $1)
    local devn=$(basename $1)
    
    echo -n $dirn/$(echo $devn | sed -re  "s/(^[a-z]+)[0-9]+$/\1/g")
}


#Shows info of the loop dev,exits with 0 if it can be shown (it is an occupied loop dev) or with 1 if it fails to show the info (it is a free loop dev)
losetup /dev/loop$X



#Putting - before EOF, will ignore TABs at the beginning of the
#here file (notice that TABs will be ignored, but not SPC)
#Delimiter for the here file is not only the string ('EOF'), but ALL
#the string (including trailing spaces and tabs)
cryptsetup luksFormat $cryptdev   >>$LOGFILE 2>>$LOGFILE  <<-EOF
$PARTPWD
EOF





#Workaround. This directory may not be listable despite the proper permissions
mv /var/www /var/aux >>$LOGFILE 2>>$LOGFILE
mkdir /var/www >>$LOGFILE 2>>$LOGFILE
chmod a+rx /var/www >>$LOGFILE 2>>$LOGFILE
mv /var/aux/* /var/www/  >>$LOGFILE 2>>$LOGFILE
chmod 550 /var/www/ >>$LOGFILE 2>>$LOGFILE
chown root:www-data /var/www/  >>$LOGFILE 2>>$LOGFILE



#Get length of string
len=${#StrVar} #strlen(StrVar)



#Array operations
arr=($list)
length=${#arr[@]} 
item=${arr[1]}

#Generate pseudo-random number in a range of 2
$((RANDOM % 2))



gotoMenu(){ return 1;}; gotoMenu


#Get the IP
IPADDR=$(ifconfig | grep -Ee "eth[0-9]+" -A 1 \
                | grep -oEe "inet addr[^a-zA-Z]+" \
                | grep -oEe "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")

IPADDR=$(host "$HOSTNM" | grep -e "has address" | sed -re "s/^.*address\s+([0-9.]+).*$/\1/g")



# Warning: what we get here is the FS block size, not
# kernel sector size. Kernel always uses a 1K minimum
# sector size (even if it is 512byte)
#echo -n "a" > /media/testpart/blocksizeprobe      
#blocksize=$(ls -s /media/testpart/blocksizeprobe | cut -d " " -f1) #block size in Kb
#rm -f /media/testpart/blocksizeprobe




#Urlencode implemented with Sed:
#* Defines a tag 'a'
#* Reads next line and replaces = with %3D, etc. on said line
#* Then it jumps to 'a' again.
local certReq=$(echo "$SITESCERT" >/tmp/crt$$; echo "$SITESPRIVK" |
		                  openssl x509 -signkey /dev/stdin -in /tmp/crt$$ -x509toreq 2>>$LOGFILE |
                    sed -n -e "/BEGIN/,/END/p" |
		                  sed -e :a -e N -e 's/\//%2F/g;s/=/%3D/g;s/+/%2B/g;s/\n/%0A/;ta' ; rm /tmp/crt$$);





#Check all bash scripts syntax:
for i in $(ls ./data/config-tools/*.sh);
do
    echo "-->Syntax checking script $i";
    bash -n $i;
    if [ $? -ne 0 ];
    then
        errorsFound=1;
    fi;
done;





#Don't ask me why, but if the path below (with the asterisk) is encircled in quotes, it doesn't do the rm and doesn't print any error
rm -rf $ROOTTMP/slot$i/*  >>$LOGFILE 2>>$LOGFILE




#Create unprivileged user tmp directory
createUserTempDir (){
    #If it doesn't exist, create
    [ -e "$TMPDIR" ] || mkdir "$TMPDIR"
    #if it's not a dir, delete and create
    [ -d "$TMPDIR" ] || (rm "$TMPDIR" && mkdir "$TMPDIR") 
    #If it exists, empty it
    [ -e "$TMPDIR" ] && rm -rf "$TMPDIR"/*
}    



#Buffer to pass return strings between the privileged script and the
#user script when stdout is locked by dialog
RETBUFFER=$TMPDIR/returnBuffer # TODO see if it is used anymore


#Function to pass return strings between the privileged script and the
#user script when stdout is locked by dialog
# $1 -> return string
doReturn () {
    rm -f $RETBUFFER     >>$LOGFILE 2>>$LOGFILE
    touch $RETBUFFER >>$LOGFILE 2>>$LOGFILE    
    chmod 644 $RETBUFFER >>$LOGFILE 2>>$LOGFILE    
    echo -n "$1" > $RETBUFFER
}


#Print and delete the last string returned by a privileged op   # TODO probably will be useless. check usage, and try to delete it
getReturn () {
    if [ -e "$RETBUFFER" ]
	   then
	       cat "$RETBUFFER"  2>>$LOGFILE
        rm -f $RETBUFFER  >>$LOGFILE 2>>$LOGFILE
    fi
}







#Download node list and check if there are at least two active nodes
wget https://esurvey.nisu.org/sites?lstnodest=1 -O /tmp/nodelist 2>/dev/null
ret=$?

if [ "$ret" -ne  0  ]
then
		  $dlg --msgbox $"Error downloading list." 0 0
else
		  numnodes=$(wc -l /tmp/nodelist | cut -d " " -f 1)
    
		  [ "$numnodes" -lt "2"  ] && $dlg --msgbox $"Not enough nodes." 0 0
    
fi
rm /tmp/tempdlg /tmp/nodelist 2>/dev/null




#Workaround. This directory may not be listable despite the proper permissions
# TODO If problems detected, uncomment, otherwise, delete
#    mv /var/www /var/aux >>$LOGFILE 2>>$LOGFILE
#    mkdir /var/www >>$LOGFILE 2>>$LOGFILE
#    chmod a+rx /var/www >>$LOGFILE 2>>$LOGFILE
#    mv /var/aux/* /var/www/  >>$LOGFILE 2>>$LOGFILE
#    chmod 550 /var/www/ >>$LOGFILE 2>>$LOGFILE
#    chown root:www-data /var/www/  >>$LOGFILE 2>>$LOGFILE



#Subject structure (must be this way, with the eMail upfront)
#"/emailAddress=XXX/C=XX/ST=XXXX/L=XXXXX/O=XXXXXX/OU=XXXX/CN=XX.XX.XX"



    	   
#</DEBUG>
echo "***** Written Share$1 ($(ls -l $shareFilePath | cut -d \" \" -f 5))*****"
hexdump shareFilePath
echo "******************************"
#</DEBUG>


#<DEBUG>      
echo -e "CHECK1: cfg:  --" >>$LOGFILE 2>>$LOGFILE
cat "$configFilePath" >>$LOGFILE 2>>$LOGFILE
echo "--" >>$LOGFILE 2>>$LOGFILE
#</DEBUG>




#Iterate a number sequence
for i in $(seq 0 $(($1-1)) ) ; do
    :
done




#Syntax check all bash scripts
for s in $(find src/ -iname "*.sh") ; do bash -n $s ; done;



#To detach a process from its terminal (for example, a bash launched on a tty, to prevent it from hanging up)
disown -h PID # Will ignore HANGUP signal
disown -h -ar # Do as above, but to all running jobs belonging to ths terminal




#Dialog:
# --no-collapse

# Normally dialog converts tabs to spaces and reduces multiple spaces
# to a single space for text which is displayed in a message boxes,
# etc.  Use this option to disable that feature.  Note that dialog
# will still wrap text, subject to the "--cr-wrap" and "--trim"
# options.


# --trim

# Eliminate leading blanks, trim literal newlines and repeated blanks
# from message text. See also the "--cr-wrap" and "--no-collapse"
# options.


# --cr-wrap

# Interpret embedded newlines in the dialog text as a newline on the
# screen.  Otherwise, dialog will only wrap lines where needed to fit
# inside the text box.

# Even though you can control line breaks with this, Dialog will still
# wrap any lines that are too long for the width of the box.  Without
# cr-wrap, the layout of your text may be formatted to look nice in
# the source code of your script without affecting the way it will
# look in the dialog.

# See also the "--no-collapse" and "--trim" options.




#If apache is running, stop it temporarily (for when this is
#called in maintenance)
stoppedApache=0
if (ps aux | grep apache | grep -v grep >>$LOGFILE 2>>$LOGFILE) ; then
    stoppedApache=1
    /etc/init.d/apache2 stop >>$LOGFILE 2>>$LOGFILE
fi

#Test renewal
certbot --standalone certonly -n  -d "$SERVERCN"  --dry-run  >>$LOGFILE 2>>$LOGFILE
ret=$?

if [ "$stoppedApache" -eq 1 ] ; then
    /etc/init.d/apache2 start >>$LOGFILE 2>>$LOGFILE
fi

if [ $ret -ne 0 ] ; then
    log "failed certbot certificate renewal test. Check."
    exit 1
fi



#Not archiving anymore, as it is a persistent link and would add one
#entry on every enable/reboot
#If there's any previous cert, archive it
if [ -e $DATAPATH/webserver/server.key ] ; then
    archive="$DATAPATH/webserver/archive/ssl"$(date +%s)
    mkdir -p "$archive"           >>$LOGFILE 2>>$LOGFILE
    cp -f $DATAPATH/webserver/* "$archive/"  >>$LOGFILE 2>>$LOGFILE # Only copy the files
    rm -f $DATAPATH/webserver/*              >>$LOGFILE 2>>$LOGFILE # Only remove the files
fi
