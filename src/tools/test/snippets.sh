#Useful debugging code snippets for bash

# set -x activates trace mode on bash (like 'bash -x script.sh' ), which will print on stderr and this will go to tty2
exec 2>/dev/tty2
set -x


# Debugging tool: Every time a command return value is non-zero, it will stop and show the prompt on stderr
trap "read -p 'NON ZERO RETURN DETECTED (check if OK). Press return to go on.'" ERR



#To limit execution time
function launch () { (eval "$1" & p=$! ; (sleep $2; kill $p 2>/dev/null) & wait $p) ; }


#Create a RAID (create a superblock in each disk)
# mdadm --create /dev/md0 --level=raid1 --raid-devices=2 /dev/hda1 /dev/hdc1
#Create partition table:
#$fdisk /dev/md0  c(dos compatibility off) u(units to sectors) o (new table) n (new partition) w

#Check RAID status or of each disk
#mdadm --detail /dev/md0
#mdadm --examine /dev/sda
#cat /proc/mdstat and instead of the string [UU] you will see [U_] if you have a degraded RAID1 array.

#Check state of operations:
# cat /proc/mdstat
    
#Rebuild degraded RAID:
# mdadm --fail /dev/md0 /dev/hdc1    #Mark disk as failed
# mdadm --remove /dev/md0 /dev/hdc1  #Delete disk from array
# **shutdown and replace disk**
# mdadm --zero-superblock /dev/hdc1  #Just in case the disk came from another RAID
# mdadm --add /dev/md0 /dev/hdc1     #Add the disk to the array
