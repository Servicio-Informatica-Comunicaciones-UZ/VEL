#Useful debugging code snippets for bash

#Breakpoint
echo "Press RETURN to continue..." && read


# set -x activates trace mode on bash (like 'bash -x script.sh' ), which will print on stderr and this will go to tty2
exec 2>/dev/tty2
set -x


# Debugging tool: Every time a command return value is non-zero, it will stop and show the prompt on stderr
trap "read -p 'NON ZERO RETURN DETECTED (check if OK). Press return to go on.'" ERR



#To limit execution time
function launch () { (eval "$1" & p=$! ; (sleep $2; kill $p 2>/dev/null) & wait $p) ; }





#Scans for RAID volumes.
mdadm --examine --scan --config=partitions >/tmp/mdadm.conf  2>>$LOGFILE


#Load an array
#Changed --run by --no-degraded to avoid loading degraded arrays
mdadm --assemble --scan --no-degraded --config=/tmp/mdadm.conf --auto=yes >>$LOGFILE 2>>$LOGFILE


#Create a RAID (create a superblock in each disk)
mdadm --create /dev/md0 --level=raid1 --raid-devices=2 /dev/hda1 /dev/hdc1
#Create partition table:
fdisk /dev/md0  c(dos compatibility off) u(units to sectors) o (new table) n (new partition) w

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
