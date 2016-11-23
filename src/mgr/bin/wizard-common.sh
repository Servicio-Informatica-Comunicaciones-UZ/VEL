#!/bin/bash
# Methods and global variables only common to all non-privileged scripts go here

###############
#  Constants  #
###############

#Actual version number of this voting system
VERSION=$(cat /etc/vtUJIversion)

#Block id used in the secure store for the key fragment
KEYBID='eSurvey_eLection_keyshare'

#Block id used in the secure store for the configuration
CONFBID='eSurvey_eLection_config'




#############
#  Methods  #
#############



#Wrapper: move logs to privileged location
# $1 ->   'new': new install (just moves logs)
#       'reset': substitutes logs for the previous ones and saves apart current ones
relocateLogs () {
    $PSETUP  relocateLogs "$1"
}



#Create unprivileged user tmp directory # TODO I think this and all its references can be deleted, as it is not used, or if used, it can go to /tmp, just overwrite the variable
createUserTempDir (){
    #If it doesn't exist, create
    [ -e "$TMPDIR" ] || mkdir "$TMPDIR"
    #if it's not a dir, delete and create
    [ -d "$TMPDIR" ] || (rm "$TMPDIR" && mkdir "$TMPDIR") 
    #If it exists, empty it
    [ -e "$TMPDIR" ] && rm -rf "$TMPDIR"/*
}    




#Configure access to ciphered data
#1 -> 'new': setup new ciphered device
#     'reset': load existing ciphered device
configureCryptoPartition () {
    
    if [ "$1" == 'new' ]
	   then
	       $dlg --infobox $"Creating ciphered data device..." 0 0
    else
	       $dlg --infobox $"Accessing ciphered data device..." 0 0
    fi
    sleep 1
    
    #Setup the partition
    $PVOPS configureCryptoPartition "$1"
    local ret=$?
    [ "$ret" -eq 2 ] && systemPanic $"Error mounting base drive."
    [ "$ret" -eq 3 ] && systemPanic $"Critical error: no empty loopback device found"
    [ "$ret" -ne 4 ] && systemPanic $"Unknown data access mode. Configuration is corrupted or tampered."
    [ "$ret" -ne 5 ] && systemPanic $"Couldn't encrypt the storage area."
    [ "$ret" -ne 6 ] && systemPanic $"Couldn't access storage area." 
    [ "$ret" -ne 7 ] && systemPanic $"Couldn't format the filesystem."
    [ "$ret" -ne 8 ] && systemPanic $"Couldn't mount the filesystem."
    [ "$ret" -ne 0 ] && systemPanic $"Error configuring encrypted drive."
    
}






#Get a password from user
#1 -> mode:  (auth) will ask once, (new) will ask twice and check for equality
#2 -> message to be shown
#3 -> cancel button? 0 no, 1 yes
# Return 0 if ok, 1 if cancelled
# $PASSWD : inserted password (due to dialog handling the stdout)
getPassword () {
    
    exec 4>&1
    
    local nocancelbutton=" --no-cancel "    
    [ "$3" == "0" ] && nocancelbutton=""
    
    while true; do
        
	       local pass=$($dlg $nocancelbutton --max-input 32 --passwordbox "$2" 10 40 2>&1 >&4)
	       [ "$?" -ne 0 ] && return 1 
	       
	       [ "$pass" == "" ] && continue
        
        #If this is a new password dialog
        if [ $1 == 'new' ] 
	       then
            #Check password strength
            local errmsg=$(checkPassword "$pass")
            if [ "$?" -ne 0 ] ; then
                $dlg --msgbox "$errmsg" 0 0
                continue
            fi
            
	           local pass2=$($dlg $nocancelbutton  --max-input 32 --passwordbox $"Vuelva a escribir su contrase�a." 10 40 2>&1 >&4)
	           [ $? -ne 0 ] && return 1 

            #If not matching, ask again
            if [ "$pass" != "$pass2" ] ; then
                $dlg --msgbox $"Passwords don't match." 0 0
	               continue
            fi
	    	  fi
        
        break
    done
    
    PASSWD=$pass
    return 0
}







#Check validity and strength of password
#1 -> password to check
#Returns 0 if OK, 1 if error
#Stdout: Error message to be displayed
checkPassword () {
    local pass=$1
    
    if [ ${#pass} -lt 8 ] ; then
		      echo $"Password too short (min. 8 chars)."
	       return 1
	   fi
    
	   if [ ${#pass} -gt 32 ] ; then
    		  echo $"Password too long (max. 32 chars)."
		      return 1
	   fi
    
	   if $(parseInput pwd "$pass") ; then
		      :
	   else    
		      echo $"Password not valid. Use: ""$ALLOWEDCHARSET"
		      return 1
	   fi
    
    return 0
}







#Detects insertion of a device and reads the config/keyshare/both to the current slot 
#1 -> 'c': read the config olny
#     'k': read the keyshare only
#     'b' or '': read both
#Returns  0: OK
#         1: read error
#         2: password error
#         9: cancelled
readNextUSB () {
    
    #Detect device insertion
    insertUSB $"Insert USB key storage device" $"Cancel"
    [ $? -eq 1 ] && return 9
    if [ $? -eq 2 ] ; then
        #No readable partitions.
        $dlg --msgbox $"Device contained no readable partitions." 0 0
        return 1 
    fi
    
    #Mount the device (will do on /media/usbdrive)
    $PVOPS mountUSB mount $USBDEV

    #Ask for device password
    while true ; do
        #Returns passowrd in $PASSWD
        getPassword auth $"Please, insert the password for the connected USB device" 0
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Password insertion cancelled." 0 0
            $PVOPS mountUSB umount
            return 2
        fi
	       
        #Access the store on the mounted path and check password
        #(store name is a constant expected by the store handler)
        $PVOPS storops checkPwd /media/usbdrive/ "$PASSWD" 2>>$LOGFILE
        if [ $? -ne 0 ] ; then
            #Keep asking until cancellation or success
            $dlg --msgbox $"Password not correct." 0 0
            continue
        fi
        break
    done
    
    #Read config
    if [ "$1" != "k" ] ; then
	       $PVOPS storops readConfigShare /media/usbdrive/ "$PASSWD" >>$LOGFILE 2>>$LOGFILE
        ret=$?
	       if [ $ret -ne 0 ] ; then
	           $dlg --msgbox $"Error ($ret) while reading configuration from USB." 0 0
            $PVOPS mountUSB umount
	           return 3
	       fi

        #Check config syntax
        $PVOPS storops parseConfig  >>$LOGFILE 2>>$LOGFILE
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Configuration file tampered or corrupted." 0 0
            $PVOPS mountUSB umount
            return 4
        fi
        
        #Compare last read config with the one currently considered as
        #valid (if no tampering occurred, all should match perfectly)
        #If different, user will be prompted
	       $PVOPS storops compareConfigs        
    fi
    
    #Read keyshare
    if [ "$1" != "c" ] ; then
       	$PVOPS storops readKeyShare /media/usbdrive/ "$PASSWD" >>$LOGFILE 2>>$LOGFILE
	       ret=$?
       	if [ $ret -ne 0 ] ; then
	           $dlg --msgbox $"Error ($ret) while reading keyshare from USB." 0 0
            $PVOPS mountUSB umount
	           return 3
	       fi
	   fi
    
    #Umount the device once done reading
    $PVOPS mountUSB umount
    
    #Detect extraction before returning control to main program
    detectUsbExtraction $USBDEV $"USB device successfully read. Remove it and press RETURN." \
                        $"Didn't remove it. Please, do it and press RETURN."
    
    return 0
}







#Grant admin user a privileged admin status on the web app
#1-> 'grant' or 'remove'
grantAdminPrivileges () {
    echo "Setting web app privileged admin status to: $1"  >>$LOGFILE 2>>$LOGFILE
	   $PVOPS  grantAdminPrivileges "$1"	
}



#Will try to rebuild the key using the shares on the active slot
rebuildKey () {
    
    $PVOPS storops rebuildKey
    
    #If rebuild failed, try a lengthier approach
    if [ $? -ne 0 ]
    then
        $dlg --msgbox $"Key reconstruction failed. System will try to recover. This might take a while." 0 0 
        
        $PVOPS storops rebuildKeyAllCombs 2>>$LOGFILE  #0 ok  1 bad pwd
	       local ret=$?
        local errmsg=''
        #If rebuild failed again, nothing can be done, back to the menu
	       [ "$ret" -eq 10 ] && errmsg=$"Missing configuration parameters."
        [ "$ret" -eq 11 ] && errmsg=$"Not enough shares available."
        [ "$ret" -eq 1  ] && errmsg=$"Some shares may be corrupted. Not enough left."
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Key couldn't be reconstructed. $errmsg" 0 0 
            return 1
	       fi
	   fi
    
    return 0
}







        
#### Network connection parameters ####
# Will read the user input parameters and set them to their
# destination global variables. Notice that since an empty field is
# ignored and all values are shifted, we will only update the
# variables if all the values are set.
#Set variables:
#  IPMODE
#  IPADDR
#  MASK
#  GATEWAY
#  DNS1
#  DNS2
#  HOSTNM
#  DOMNAME
###TODO depu�s, los valores establecidos aqu� se pasar�n al  privil. op adecuado donde se parsear�n de nuevo y se establecer�n si corresponde. Hacer op para leer y preestablecer los valores de estas variables y usarlas como valores default (para los pwd, obviamente, no)
networkParams () {
    
    selectIPMode () {
                
        #Default value
        isDHCP=on
        isUserSet=off
        
       	exec 4>&1 
	       local choice=""
	       while true
	       do
            [ "$IPMODE" == "dhcp" ]   && isDHCP=on && isUserSet=off
            [ "$IPMODE" == "static" ] && isDHCP=off && isUserSet=on
            
	           choice=$($dlg --cancel-label $"Menu"   --radiolist  $"Network connection mode" 0 0 2  \
	                         1 $"Automatic (DHCP)" "$isDHCP"  \
	                         2 $"User set" "$isUserSet"  \
	                         2>&1 >&4 )
	           #If cancelled, exit
            [ $? -ne 0 ] && return 1
            
            #If none selected, ask again
            [ "$choice" == "" ] && continue
            
            #If static config is chosen
	           if [ "$choice" -eq 2 ] ; then
	               IPMODE="static"
                
                #Show the parameter form
                selectIPParams
                
                #If back, show the mode selector again
                [ "$?" -eq '2' ] && continue
            else
                #DHCP mode selected
                IPMODE="dhcp"
                while true ; do
                    local errmsg=""
                    
	                   local hostn=$($dlg --cancel-label $"Back"  --inputbox  \
		                                     $"Hostname:" 0 0 "$HOSTNM"  2>&1 >&4)
                    #If back, show the mode selector again
                    [ "$?" -ne 0 ] && continue 2
                    
	                   parseInput hostname "$hostn"
	                   [ $? -ne 0 ] && errmsg=""$"Hostname not valid."
                    
	                   local domn=$($dlg --cancel-label $"Back"  --inputbox  \
		                                    $"Domain name:" 0 0 "$DOMNAME"  2>&1 >&4)
                    #If back, continue to go to the previous prompt
                    [ "$?" -ne 0 ] && continue
                    
	                   parseInput dn "$domn"
                    [ $? -ne 0 ] && errmsg="$errmsg\n"$"Domain not valid."
                    
                    #If errors, go to the first prompt
                    if [ "$errmsg" != "" ] ; then
		                      $dlg --msgbox "$errmsg" 0 0
		                      continue
	                   fi
                    #If all set ad correct, set the globals
                    HOSTNM="$hostn"
                    DOMNAME="$domn"
                    break
                done
            fi
            break
	  	    done
        return 0
    }
    
    selectIPParams () {
        
        #Preset values are on the global variables. Will only be
        #updated if value is correct; and if some field is left empty,
        #none will be update (due to dialog limitations)
        local choice=""
        exec 4>&1

	       while true
	       do
	           local formlen=7
	           choice=$($dlg  --cancel-label $"Back"  --mixedform  $"Network connection parameters" 0 0 20  \
	                          $"Field"            1  1 $"Value"   1  30  17 15   2  \
	                          $"IP Address"       3  1 "$IPADDR"  3  30  17 15   0  \
	                          $"Net Mask"         5  1 "$MASK"    5  30  17 15   0  \
	                          $"Gateway Address"  7  1 "$GATEWAY" 7  30  17 15   0  \
	                          $"Primary DNS"      10 1 "$DNS1"    10 30  17 15   0  \
	                          $"Secondary DNS"    12 1 "$DNS2"    12 30  17 15   0  \
	                          $"Hostname"         15 1 "$HOSTNM"  15 30  17 256  0  \
                           $"Domain"           17 1 "$DOMNAME" 17 30  17 256  0  \
	                          2>&1 >&4 )
            
	           #If cancelled, exit
            [ $? -ne 0 ] && return 2

            #Check that all fields have been filled in (choice must
            #have the expected number of items), otherwise, loop
            local BAKIFS=$IFS
            IFS=$(echo -en "\n\b") #We need this to avoid interpreting a space as an entry 
            local clist=($choice)
            IFS=$BAKIFS
            if [ ${#clist[@]} -le "$formlen" ] ; then
            	   $dlg --msgbox $"All fields are mandatory" 0 0
	               continue 
	           fi
            
            #Parse each entry before setting it
     	      local i=0
	           local loopAgain=0
            local errors=""
            IFS=$(echo -en "\n\b")
	           for item in $choice
	           do
                IFS=$BAKIFS
	               case "$i" in
				                "1" ) #IP
		                      parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"IP address not valid"
  		                    else IPADDR="$item" ; fi
		                      ;;
		                  
		                  "2" ) #MASK
                        parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Net mask not valid"
		                      else MASK="$item" ; fi
		                      ;;
	                   
		                  "3" ) #Gateway
		                      parseInput ipaddr "$item"
				                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Gateway address not valid"
                        else GATEWAY="$item" ; fi
		                      ;;
	                   
		                  "4" ) #Primary DNS
		                      parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Primary DNS address address not valid"
		                      else DNS1="$item" ; fi
				                    ;;
		                  
		                  "5" ) #Secondary DNS
 	                      parseInput ipaddr "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Secondary DNS address address not valid"
		                      else DNS2="$item" ; fi
				                    ;;
	                   
		                  "6" ) # Hostname
		                      parseInput hostname "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Host name not valid"
		                      else HOSTNM="$item" ; fi
		                      ;;
		                  "7" ) # Domain for the host
		                      parseInput dn "$item"
		                      if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Domain name not valid"
		                      else DOMNAME="$item" ; fi
		                      ;;
	               esac
                
                #Next item, until the number of expected items
	               i=$((i+1))
                IFS=$(echo -en "\n\b")
	           done
            
            #Show errors in the form, then loop
	           if [ "$loopAgain" -eq 1 ] ; then
                $dlg --msgbox "$errors" 0 0
                continue
	           fi
            break
        done
	   } #SelectIPParams
    
    
    selectIPMode
    local ret=$?
    
    #<DEBUG>
	   echo "IPMODE: "$IPMODE  >>$LOGFILE 2>>$LOGFILE  # TODO guess where these vars are passed to the privileged part and stored on the config (either drive or usbdevs)
	   echo "IP:   "$IPADDR >>$LOGFILE 2>>$LOGFILE
	   echo "MASK: "$MASK >>$LOGFILE 2>>$LOGFILE
	   echo "GATE: "$GATEWAY >>$LOGFILE 2>>$LOGFILE
	   echo "DNS1: "$DNS1 >>$LOGFILE 2>>$LOGFILE
	   echo "DNS2: "$DNS2 >>$LOGFILE 2>>$LOGFILE
	   echo "HOSTNM: "$HOSTNM >>$LOGFILE 2>>$LOGFILE
 	  echo "DOMNAME: "$DOMNAME >>$LOGFILE 2>>$LOGFILE
   #</DEBUG>
    
    return $ret
} #NetworkParams









#Configure and check network connectivity
#Will access the following global variables:
# IPMODE
# IPADDR
# MASK
# GATEWAY
# DNS1
# DNS2
configureNetwork () {
    echo "Configuring network: $PSETUP configureNetwork $IPMODE $IPADDR $MASK $GATEWAY $DNS1 $DNS2" >>$LOGFILE 2>>$LOGFILE
    $dlg --infobox $"Configuring network connection..." 0 0
    
    #On reset, paremetrs will be empty, but will be read from the config fiile
    $PSETUP configureNetwork "$IPMODE" "$IPADDR" "$MASK" "$GATEWAY" "$DNS1" "$DNS2"
    local ret="$?"
    
    if [ "$ret" == "11"  ]; then
	       echo "Error: no accessible ethernet interfaces found."  >>$LOGFILE 2>>$LOGFILE
	       return 1
    elif [ "$ret" == "12"  ]; then
	       echo "Error: No destination reach from any interface." >>$LOGFILE 2>>$LOGFILE
        return 1
    elif [ "$ret" == "13"  ]; then
	       echo "Error: DHCP client error." >>$LOGFILE 2>>$LOGFILE
        return 1
    elif [ "$ret" == "14"  ]; then
	       echo "Error: Gateway connectivity error." >>$LOGFILE 2>>$LOGFILE
        return 1
    fi
    
    #Check Internet connectivity
    $dlg --infobox $"Checking Internet connectivity..." 0 0
	   ping -w 5 -q 8.8.8.8  >>$LOGFILE 2>>$LOGFILE 
	   if [ $? -eq 0 ] ; then
        return 2
    fi
    return 0
}






#Will ask the personal and authentication information for the system
#administrator, so it will be added to the database
#1 -> if 'lock', it will lock all fields except for passwords
#Returns 0 if parameters have been set and match the syntax, 1 if back button pressed
#Will set the following variables:
# ADMINNAME
# ADMIDNUM
# MGREMAIL
# ADMREALNAME
# MGRPWD
# LOCALPWD
sysAdminParams () {

    #If set, allows edition of password fields only
    local lock=0
    [ "$1" == 'lock' ] && lock=2
    
    local choice=""
    exec 4>&1
	   while true
	   do
	       local formlen=8
	       choice=$($dlg  --cancel-label $"Back"  --mixedform  $"System administrator information" 0 0 21  \
	                      $"Field"            1  1 $"Value"       1  30  17 15   2  \
	                      $"User name"        3  1 "$ADMINNAME"   3  30  17 256  $lock  \
                       $"ID number"        5  1 "$ADMIDNUM"    5  30  17 256  $lock  \
                       $"E-mail address"   7  1 "$MGREMAIL"    7  30  17 256  $lock  \
                       $"Full name"        9  1 "$ADMREALNAME" 9  30  17 256  $lock  \
	                      $"Web APP password" 12 1 "$MGRPWD"      12 30  17 256  1  \
	                      $"Repeat password"  14 1 "$repMGRPWD"   14 30  17 256  1  \
	                      $"Local password"   17 1 "$LOCALPWD"    17 30  17 256  1  \
	                      $"Repeat password"  19 1 "$repLOCALPWD" 19 30  17 256  1  \
	                      2>&1 >&4 )
        
	       #If cancelled, exit
        [ $? -ne 0 ] && return 1
        
        #Check that all fields have been filled in (choice must
        #have the expected number of items), otherwise, loop
        local BAKIFS=$IFS
        IFS=$(echo -en "\n\b") #We need this to avoid interpreting a space as an entry 
        local clist=($choice)
        IFS=$BAKIFS
        if [ ${#clist[@]} -le "$formlen" ] ; then
            $dlg --msgbox $"All fields are mandatory" 0 0
	           continue 
	       fi
        
        #Parse each entry before setting it
     	  local i=0
	       local loopAgain=0
        local errors=""
        local pwderrmsg=""
        IFS=$(echo -en "\n\b")
	       for item in $choice
	       do
            IFS=$BAKIFS
         	  case "$i" in
				            "1" ) # ADMINNAME
		                  parseInput user "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"User name not valid. Can contain the following characters:"" $ALLOWEDCHARSET"
  		                else ADMINNAME="$item" ; fi
		                  ;;
		              
		              "2" ) # ADMIDNUM
                    parseInput dni "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"User ID number not valid. Can contain the following characters:"" $ALLOWEDCHARSET"
		                  else ADMIDNUM="$item" ; fi
		                  ;;
	               
		              "3" ) # MGREMAIL
		                  parseInput email "$item"
				                if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"E-mail address not valid."
                    else MGREMAIL="$item" ; fi
		                  ;;
	               
		              "4" ) # ADMREALNAME
		                  parseInput freetext "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"User real name string not valid. Can contain the following characters:"" $ALLOWEDCHARSET"
		                  else ADMREALNAME="$item" ; fi
				                ;;
		              
		              "5" ) # MGRPWD
                    local auxmgrPwd="$item"
                    pwderrmsg=$(checkPassword "$item")
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Web app password:"" $pwderrmsg"
		                  else MGRPWD="$item" ; fi
				                ;;
	               
		              "6" ) # repMGRPWD
		                  if [ "$item" != "$auxmgrPwd" ] ; then loopAgain=1; errors="$errors\n"$"Web app password: passwords don't match."
		                  else local repMGRPWD="$item" ; fi
		                  ;;
                
		              "7" ) # LOCALPWD
                    local auxlocalPwd="$item"
                    pwderrmsg=$(checkPassword "$item")
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Local password:"" $pwderrmsg"
		                  else LOCALPWD="$item" ; fi
		                  ;;

                "8" ) # repLOCALPWD
		                  if [ "$item" != "$auxlocalPwd" ] ; then loopAgain=1; errors="$errors\n"$"Local password: passwords don't match."
		                  else local repLOCALPWD="$item" ; fi
		                  ;;
	           esac
            
            #Next item, until the number of expected items
	           i=$((i+1))
            IFS=$(echo -en "\n\b")
	       done
        
        #One more check: local and web password shouldn't be the same,
        #for security reasons
        if [ "$MGRPWD" == "$LOCALPWD" ] ; then
            loopAgain=1
            errors="$errors\n"$"Local password and Web app password mustn't be the same."
        fi
        
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
    done
    
    #<DEBUG>
    echo "ADMINNAME:   $ADMINNAME" >>$LOGFILE 2>>$LOGFILE
    echo "MGRPWD:      $MGRPWD" >>$LOGFILE 2>>$LOGFILE
    echo "LOCALPWD:    $LOCALPWD" >>$LOGFILE 2>>$LOGFILE
    echo "ADMIDNUM:    $ADMIDNUM" >>$LOGFILE 2>>$LOGFILE
    echo "MGREMAIL:    $MGREMAIL" >>$LOGFILE 2>>$LOGFILE
    echo "ADMREALNAME: $ADMREALNAME" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
}





#Wrapper for the privileged operation to set a variable
# $1 -> Destination: 'disk' persistent disk;
#                    'mem'  (default) or nothing if we want it in ram;
#                    'usb'  if we want it on the usb config file;
#                    'slot' in the active slot configuration
# $2 -> variable
# $3 -> value
setVar () {    
    $PVOPS vars setVar "$1" "$2" "$3"
}



#Wrapper for the privileged operation to get a variable value	
# $1 -> Where to read the var from 'disk' disk;
#                                  'mem' or nothing if we want it from volatile memory;
#                                  'usb' if we want it from the usb config file;
#                                  'slot' from the active slot's configuration
# $2 -> var name (to be read)
#STDOUT: the value of the read variable, empty string if not found
#Returns: 0 if it could find the variable, 1 otherwise.
getVar () {
    $PVOPS vars getVar $1 $2
    return $?
}











#Prompt user to select a partition among those available
#1 -> 'all' to list all available partitions
#     'wfs' to show only those with a valid fs
#2 -> Top message to be shown
#Return: 0 if ok, 1 if cancelled
#DRIVE: name of the selected partition
hddPartitionSelector () {
    
    local partitions=$($PVOPS listHDDPartitions "$1" fsinfo)
    local npartitions=$?
    
    #Error
    if [ $npartitions -eq 255 ] ; then
        $dlg --msgbox $"Error accessing drives. Please check." 0 0
        return 1
        #No partitions available
    elif [ $npartitions -eq 0 ] ; then
        $dlg --msgbox $"No drive partitions available. Please check." 0 0
        return 1
    fi
    local drive=$($dlg --cancel-label $"Cancel"  \
                       --menu "$2" 0 80 \
                       $(($npartitions)) $partitions 2>&1 >&4)
	   #If canceled, go back to the mode selector
	   [ $? -ne 0 ]  && return 1;
    
    DRIVE="$drive"
    return 0
}



#Select which method should be used to setup an encrypted drive
#Will set the follwong global variables:
#DRIVEMODE
#DRIVELOCALPATH
#FILEPATH
#FILEFILESIZE
#CRYPTFILENAME
selectCryptoDriveMode () {
    
    local isLocal=on
    local isLoop=off
    
    exec 4>&1     
	   local choice=""
	   while true
	   do
        [ "$DRIVEMODE" == "local" ]   && isLocal=on  && isLoop=off
        [ "$DRIVEMODE" == "file" ]    && isLocal=off && isLoop=on
        
        choice=$( $dlg --cancel-label $"Menu" \
                       --radiolist  $"Ciphered filesystem location:" 0 0 2  \
	                      1 $"Local drive partition"      "$isLocal" \
	                      2 $"Local drive loopback file"  "$isLoop"  \
	                      2>&1 >&4 )
        
        #If cancelled, exit
        [ $? -ne 0 ] && return 1
        
        #If none selected, ask again
        [ "$choice" == "" ] && continue
        
        
        
	       if [ "$choice" -eq 1 ] #### Local partition
        then
	           DRIVEMODE="local"
            
            #Choose partition
            hddPartitionSelector all $"Choose a partition (WARNING: ALL INFORMATION ON THE SELECTED PARTITION WILL BE LOST)."
            [ $? -ne 0 ] && continue
            
            #Set the selected partition
	           DRIVELOCALPATH=$DRIVE
	           
        else #### Loopback filesystem
	          	DRIVEMODE="file"
	           
            #Choose partition
            hddPartitionSelector wfs $"Choose a partition. Loop filesystem will be written on a file in its root directory."
            [ $? -ne 0 ] && continue
            
            #Set the selected partition
            FILEPATH=$DRIVE

            #Ask additional parameters to create the loopback filesystem
	           while true
		          do
                local fsize=$($dlg --cancel-label $"Back"  --inputbox  \
		                                 $"Loopback filesystem file size (in MB):" 0 0 "$FILEFILESIZE"  2>&1 >&4)

                #If back, go to the mode selector
                [ "$?" -ne 0 ] && continue 2
                
	               parseInput int "$fsize"
                if [ $? -ne 0 ] ; then
                    $dlg --msgbox $"Value not valid. Must be a positive integer." 0 0
		                  continue
	               fi
                
                FILEFILESIZE="$fsize"
                break
	           done
            
            #Generate a unique name for the loopback file
	           CRYPTFILENAME="$CRYPTFILENAMEBASE"$(date +%s) # TODO Do not use as global in functions. make sure it is written in config before gbiulding the ciph part. -Also, try to move this to the privileged part (as they are written there, if I remember well)
        fi
        break
	   done
    #<DEBUG>
    echo "Crypto drive mode: $DRIVEMODE"  >>$LOGFILE 2>>$LOGFILE
    echo "Local path:        $DRIVELOCALPATH"  >>$LOGFILE 2>>$LOGFILE
	   echo "Local file:        $FILEPATH" >>$LOGFILE 2>>$LOGFILE
	   echo "File system size:  $FILEFILESIZE" >>$LOGFILE 2>>$LOGFILE
		  echo "Filename:          $CRYPTFILENAME" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
} #selectCryptoDriveMode





#Will prompt the user to select the ssh backup server connection
#parameters
#Will set the following globals:
#SSHBAKSERVER
#SSHBAKPORT
#SSHBAKUSER
#SSHBAKPASSWD
sshBackupParameters () {
    
    #Defaults
    [ "$SSHBAKPORT" == "" ] && SSHBAKPORT=$DEFSSHPORT
    
    local choice=""
    exec 4>&1
    while true
    do
		      local formlen=4
	       choice=$($dlg  --cancel-label $"Menu" --mixedform  $"SSH backup parameters" 0 0 12  \
		                     $"Field"              1  1 $"Value"        1  30  17 15   2  \
		                     $"SSH server (IP/DN)" 3  1 "$SSHBAKSERVER" 3  30  30 2048 0  \
		                     $"Port"               5  1 "$SSHBAKPORT"   5  30  20  6   0  \
		                     $"Username"           7  1 "$SSHBAKUSER"   7  30  20 256  0  \
		                     $"Password"           9  1 "$SSHBAKPASSWD" 9  30  20 256  1  \
		                     2>&1 >&4 )        
        
	       #If cancelled, exit
        [ $? -ne 0 ] && return 2
        
        #All mandatory, ask again if any empty
        local BAKIFS=$IFS
        IFS=$(echo -en "\n\b")
        local clist=($choice)
        IFS=$BAKIFS
        if [ ${#clist[@]} -le "$formlen" ] ; then
            $dlg --msgbox $"All fields are mandatory" 0 0
	           continue 
	       fi
        
	       #Parse each entry before setting it
     	  local i=0
	       local loopAgain=0
        local errors=""
        IFS=$(echo -en "\n\b")
	       for item in $choice
	       do
            IFS=$BAKIFS
        	   case "$i" in
				            "1" ) #IP or DN of the SSH server
		                  parseInput ipdn "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"SSH server address IP or domain not valid"
  		                else SSHBAKSERVER="$item" ; fi
		                  ;;
		              
				            "2" ) #SSH server port
		                  parseInput port "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Server port number not valid"
  		                else SSHBAKPORT="$item" ; fi
		                  ;;

                "3" ) #Remote username
		                  parseInput user "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Username not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else SSHBAKUSER="$item" ; fi
		                  ;;

                "4" ) #Remote password
		                  parseInput pwd "$item"
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Password not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else SSHBAKPASSWD="$item" ; fi
		                  ;;
            esac
            i=$((i+1))
            IFS=$(echo -en "\n\b")
		      done
        
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
    done
    #<DEBUG>
    echo "SSH Server:        $SSHBAKSERVER" >>$LOGFILE 2>>$LOGFILE
	   echo "SSH port:          $SSHBAKPORT" >>$LOGFILE 2>>$LOGFILE
	   echo "SSH User:          $SSHBAKUSER" >>$LOGFILE 2>>$LOGFILE
	   echo "SSH pwd:           $SSHBAKPASSWD" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
}





#Does a test connection to the set SSH backup server
#Return: 0 if OK, non-zero if any problem happened
checkSSHconnectivity () {
    
		  #Set trust on the server
    sshScanAndTrust "$SSHBAKSERVER"  "$SSHBAKPORT"
    if [ $? -ne 0 ] ; then
        echo "SSH Keyscan error." >>$LOGFILE 2>>$LOGFILE
        return 1
		  fi
    
    #Perform test connection
    return sshTestConnect "$SSHBAKSERVER"  "$SSHBAKPORT"  "$SSHBAKUSER"  "$SSHBAKPASSWD"
}





#Will prompt the user to select needed
#mail server configuration parameters
#Will set the following global variables:
# MAILRELAY
mailerParams () {
	   
	   while true
    do
        MAILRELAY=$($dlg --cancel-label $"Menu" --inputbox \
	                        $"Name of the mail relay server (leave it empty if no relay is needed)." 0 50 "$MAILRELAY"  2>&1 >&4)
        #Go to menu
	       [ $? -ne 0 ] &&  return 1
        
	       #No relay needed, go on
	       [ "$MAILRELAY" -ne 0== "" ] && return 0
        
        #Check input value
	       parseInput ipdn "$MAILRELAY"
	       if [ $? -ne 0 ] ; then
	           $dlg --msgbox $"Mail relay must be a valid domain name or IP address." 0 0
	           continue
	       fi
	  	    break
	   done
    
    #<DEBUG>
    echo "Mail relay: $MAILRELAY" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
}







#Will prompt the user to select how many people will form the key
#holding comission (and the minimum quorum to rebuild it)
#Will set the following global variables:
# SHARES
# THRESHOLD
selectSharingParams () {
	   
    #Default minimum values
    [ "$SHARES" == "" ] && SHARES=2
    [ "$THRESHOLD" == "" ] && THRESHOLD=2
    
    local choice=""
    exec 4>&1
	   while true
	   do
		      local formlen=2
        choice=$($dlg --cancel-label $"Menu" --mixedform  $"Key sharing parameters" 0 0 8  \
	                     $"Field"                                              1  1 $"Value"     1  60  17 15 2  \
	                     $"How many people will keep a share of the key"       3  1 "$SHARES"    3  60  5  3  0  \
	                     $"Minimum number of them required to rebuild the key" 5  1 "$THRESHOLD" 5  60  5  3  0  \
	                     2>&1 >&4 )
        #If cancelled, exit
        [ $? -ne 0 ] && return 1
	      
	       #Check that all fields have been filled in (choice must
        #have the expected number of items), otherwise, loop
        local BAKIFS=$IFS
        IFS=$(echo -en "\n\b")
        local clist=($choice)
        IFS=$BAKIFS
        if [ ${#clist[@]} -le "$formlen" ] ; then
            $dlg --msgbox $"All fields are mandatory" 0 0
	           continue 
	       fi
        
        #Parse each entry before setting it
        local i=0
	       local loopAgain=0
        local errors=""
        local aux=""
        IFS=$(echo -en "\n\b")
	       for item in $choice
	       do
            IFS=$BAKIFS
         	  case "$i" in 
		              "1" ) #SHARES
                    parseInput int "$item"
                    if [ $? -ne 0 ] ; then
                        loopAgain=1
                        errors="$errors\n"$"Number of shares must be a positive integer"
                    fi
                    if [ "$item" -lt 2 ] ; then
                        loopAgain=1
                        errors="$errors\n"$"Number of shares must be greater than 2"
                    fi
                    
                    aux="$item"
                    [ $loopAgain -eq 0 ] && SHARES="$item"
                    ;;
		              
		              "2" ) #THRESHOLD
		                  parseInput int "$item"
		                  if [ $? -ne 0 ] ; then
                        loopAgain=1
                        errors="$errors\n"$"Threshold must be a positive integer"
                    fi
                    if [ "$item" -lt 2 ] ; then
                        loopAgain=1
                        errors="$errors\n"$"Threshold must be greater than 2"
                    fi
                    if [ "$item" -gt "$aux" ] ; then
                        loopAgain=1
                        errors="$errors\n"$"Threshold must be smaller than the total number of shares"
                    fi
                    
                    [ $loopAgain -eq 0 ] && THRESHOLD="$item"
                    ;;
		          esac
		          i=$((i+1))
            IFS=$(echo -en "\n\b")
	       done
            
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
	   done
    
    #<DEBUG>
    echo "SHARES: $SHARES" >>$LOGFILE 2>>$LOGFILE
    echo "THRESHOLD: $THRESHOLD" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>

    return 0
}














#Prompts the user to select the content of the SSL certificate request
#for the HTTP and mail servers
#Will set the following global variables:
#COMPANY
#DEPARTMENT
#COUNTRY
#STATE
#LOC
#SERVEREMAIL
#SERVERCN
sslCertParameters () {

    #As this might be called during maintenance, we read the default
    #values if not set yet
    [ "$HOSTNM" == "" ] && HOSTNM=$(getVar disk HOSTNM)
    [ "$DOMNAME" == "" ] && DOMNAME=$(getVar disk DOMNAME) # TODO revisar todos los getvar y setvar, que el origne est� bien. cambiar origen para minimizar usb
    
    #Default values
    [ "$DEPARTMENT" == "" ] && DEPARTMENT="-"
    [ "$STATE" == "" ] && STATE="-"
    [ "$LOC" == "" ] && LOC="-"
    [ "$SERVEREMAIL" == "" ] && SERVEREMAIL="-"
    [ "$SERVERCN" == "" ] && SERVERCN="$HOSTNM.$DOMNAME"
    
    local choice=""
    exec 4>&1
	   while true
	   do
		      local formlen=7
        choice=$($dlg --cancel-label $"Menu" --mixedform  $"SSL certificate (optional field's value must be a dash)" 0 0 20  \
	                     $"Field"                              1  1 $"Value"       1  40  17 15   2  \
	                     $"Name of your organisation"          3  1 "$COMPANY"     3  40  20  30  0  \
	                     $"Name of your department (optional)" 5  1 "$DEPARTMENT"  5  40  20  30  0  \
	                     $"Two letter code of your contry"     8  1 "$COUNTRY"     8  40  3   2   0  \
                      $"State or province (optional)"       10 1 "$STATE"       10 40  20  30  0  \
                      $"Locality (optional)"                12 1 "$LOC"         12 40  20  30  0  \
                      $"Contact e-mail (optional)"          15 1 "$SERVEREMAIL" 15 40  20  30  0  \
                      $"Server domain name"                 18 1 "$SERVERCN"    18 40  20  50  0  \
                      2>&1 >&4 )
        #If cancelled, exit
        [ $? -ne 0 ] && return 1
	      
	       #Check that all fields have been filled in (choice must
        #have the expected number of items), otherwise, loop
        local BAKIFS=$IFS
        IFS=$(echo -en "\n\b")
        local clist=($choice)
        IFS=$BAKIFS
        if [ ${#clist[@]} -le "$formlen" ] ; then
            $dlg --msgbox $"All fields are mandatory (if a field is marked as optional, write a single dash)" 0 0
	           continue 
	       fi
        
        #Parse each entry before setting it
        local i=0
	       local loopAgain=0
        local errors=""
        IFS=$(echo -en "\n\b")
	       for item in $choice
	       do
            IFS=$BAKIFS
         	  case "$i" in 
		              "1" ) #COMPANY
                    parseInput x500 "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Company name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else COMPANY="$item" ; fi
                    ;;
		              
		              "2" ) #DEPARTMENT
		                  parseInput x500 "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Department name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else DEPARTMENT="$item" ; fi
                    ;;
		              
		              "3" ) #COUNTRY
		                  parseInput cc "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Country code not valid. Must be a two letter ISO-3166 code."
  		                else COUNTRY="$item" ; fi
                    ;;
		              
		              "4" ) #STATE
		                  parseInput x500 "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"State/Province name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else STATE="$item" ; fi
                    ;;
		              
		              "5" ) #LOC
		                  parseInput x500 "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Locality name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else LOC="$item" ; fi
                    ;;
		              
		              "6" ) #SERVEREMAIL
		                  parseInput email "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Contact e-mail not valid."
  		                else SERVEREMAIL="$item" ; fi
                    ;;
		              
		              "7" ) #SERVERCN
		                  parseInput dn "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Server domain name not valid."
  		                else SERVERCN="$item" ; fi
                    ;;
		          esac
		          i=$((i+1))
            IFS=$(echo -en "\n\b")
        done
            
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
	   done
    
    #Restore empty fields
    [ "$DEPARTMENT" == "-" ] && DEPARTMENT=""
    [ "$STATE" == "-" ] && STATE=""
    [ "$LOC" == "-" ] && LOC=""
    [ "$SERVEREMAIL" == "-" ] && SERVEREMAIL=""
    
    #<DEBUG>
    echo "COMPANY: $COMPANY" >>$LOGFILE 2>>$LOGFILE
    echo "DEPARTMENT: $DEPARTMENT" >>$LOGFILE 2>>$LOGFILE
    echo "COUNTRY: $COUNTRY" >>$LOGFILE 2>>$LOGFILE
    echo "STATE: $STATE" >>$LOGFILE 2>>$LOGFILE
    echo "LOC: $LOC" >>$LOGFILE 2>>$LOGFILE
    echo "SERVEREMAIL: $SERVEREMAIL" >>$LOGFILE 2>>$LOGFILE
    echo "SERVERCN: $SERVERCN" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
}





#Prompts the user to select the info to request
#access to the anonimity network
#Will set the following global variables:
#SITESEMAIL
#SITESPWD
#SITESORGSERV
#SITESNAMEPURP
#SITESCOUNTRY
lcnRegisterParams () { #SEGUIR ma�ana. probar esta func y luego seguir con el registro
    
    #Default values
    [ "$SITESCOUNTRY" == "" ] && SITESCOUNTRY="$COUNTRY"
    [ "$SITESORGSERV" == "" ] && SITESORGSERV="$COMPANY"
    [ "$SITESEMAIL" == "" ] && SITESEMAIL="$SERVEREMAIL"
    
    #Self-generate a password (in case user is new, he can edit it anyhow)
    [ "$SITESPWD" == "" ] && SITESPWD=$(randomPassword 10)
    [ "$repSITESPWD" == "" ] && repSITESPWD="$SITESPWD"
    
    local choice=""
    exec 4>&1
	   while true
	   do
		      local formlen=6
        choice=$($dlg --cancel-label $"Menu" --mixedform  $"Anonimity Network registration.""\n* "$"If you are new, you can leave the suggested password, which will be sent to your e-mail.""\n* "$"If you already have registered any server, set the same password you used with this e-mail. Also, server name must be different from any previous one.""\n* "$"If you perform several registrations by mistake, don't confirm them later and they will be automatically discarded" 0 0 17  \
	                     $"Field"                           1  1 $"Value"         1  40  17 15   2  \
	                     $"Contact e-mail (user ID)"        3  1 "$SITESEMAIL"    3  40  20  30  0  \
	                     $"eSurvey user password"           5  1 "$SITESPWD"      5  40  20  30  1  \
                      $"Repeat password"                 7  1 "$repSITESPWD"   7  40  20  30  1  \
	                     $"Two letter code of your contry"  10 1 "$SITESCOUNTRY"  10 40  3   2   0  \
                      $"Name of your organisation"       12 1 "$SITESORGSERV"  12 40  20  30  0  \
                      $"Name of the service"             15 1 "$SITESNAMEPURP" 15 40  20  30  0  \
                      2>&1 >&4 )
        #If cancelled, exit
        [ $? -ne 0 ] && return 1
	       
	       #Check that all fields have been filled in (choice must
        #have the expected number of items), otherwise, loop
        local BAKIFS=$IFS
        IFS=$(echo -en "\n\b")
        local clist=($choice)
        IFS=$BAKIFS
        if [ ${#clist[@]} -le "$formlen" ] ; then
            $dlg --msgbox $"All fields are mandatory." 0 0
	           continue 
	       fi
        
        #Parse each entry before setting it
        local i=0
	       local loopAgain=0
        local errors=""
        local aux=""
        IFS=$(echo -en "\n\b")
	       for item in $choice
	       do
            IFS=$BAKIFS
         	  case "$i" in 
		              "1" ) #SITESEMAIL
                    parseInput email "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Contact e-mail address not valid."
  		                else SITESEMAIL="$item" ; fi
                    ;;
		              
		              "2" ) #SITESPWD
                    aux="$item"
		                  parseInput pwd "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Password not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else SITESPWD="$item" ; fi
                    ;;
		              
		              "3" ) #repSITESPWD
		                  if [ "$item" != "$aux" ] ; then loopAgain=1; errors="$errors\n"$"Passwords don't match."
		                  else local repSITESPWD="$item" ; fi
                    ;;
		              
		              "4" ) #SITESCOUNTRY
		                  parseInput cc "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Country code not valid. Must be a two letter ISO-3166 code"
  		                else SITESCOUNTRY="$item" ; fi
                    ;;
		              
		              "5" ) #SITESORGSERV
		                  parseInput freetext "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Organisation name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else SITESORGSERV="$item" ; fi
                    ;;
		              
		              "6" ) #SITESNAMEPURP
		                  parseInput freetext "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Service name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                else SITESNAMEPURP="$item" ; fi
                    ;;
		          esac
		          i=$((i+1))
            IFS=$(echo -en "\n\b")
        done
        
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
	   done
        
    
    #<DEBUG>
    echo "SITESEMAIL: $SITESEMAIL" >>$LOGFILE 2>>$LOGFILE
	   echo "SITESPWD: $SITESPWD" >>$LOGFILE 2>>$LOGFILE
	   echo "SITESORGSERV: $SITESORGSERV" >>$LOGFILE 2>>$LOGFILE
	   echo "SITESNAMEPURP: $SITESNAMEPURP" >>$LOGFILE 2>>$LOGFILE
	   echo "SITESCOUNTRY: $SITESCOUNTRY" >>$LOGFILE 2>>$LOGFILE
    #</DEBUG>
    
    return 0
}














#SEGUIR









# $1 --> 'new' o 'renew'  #///Cambiar en las llamadas
fetchCSR () {
    
    $PVOPS fetchCSR "$1"
    
}


# 1 -> 'new' o 'renew'	
generateCSR () { #*-*-adaptando al  nuevo conjunto de datos
    

    
    $dlg --infobox $"Generando petici�n de certificado..." 0 0

    $PVOPS configureServers generateCSR "$mode" "$SERVERCN" "$COMPANY" "$DEPARTMENT" "$COUNTRY" "$STATE" "$LOC" "$SERVEREMAIL"
    ret=$?

    echo "$PVOPS configureServers generateCSR '$mode' '$SERVERCN' '$COMPANY' '$DEPARTMENT' '$COUNTRY' '$STATE' '$LOC' '$SERVEREMAIL' ret:$ret"  >>$LOGFILE 2>>$LOGFILE

    if [ "$ret" -ne 0 ]
	then
	$dlg --msgbox $"Error generando la petici�n de certificado." 0 0
	return 1
    fi
    

    return 0
}







#Comprueba todas las shares existentes en el slot activo
testForDeadShares () {
    
    $PVOPS storops testForDeadShares
    local ret="$?"

    [ "$ret" -eq 2 ] && systemPanic $"Error interno. Faltan datos de configuraci�n para realizar la resconstrucci�n."
      
    [ "$ret" -eq 3 ] && systemPanic $"No se puede reconstruir la llave. No hay suficientes piezas."

    return $ret
}




#1 -> Modo de acceso a la partici�n cifrada "$DRIVEMODE"
#2 -> Ruta donde se monta el dev que contiene el fichero de loopback "$MOUNTPATH" (puede ser cadena vac�a)
#3 -> Nombre del mapper device donde se monta el sistema cifrado "$MAPNAME"
#4 -> Path donde se monta la partici�n final "$DATAPATH"
#5 -> Ruta al dev loop que contiene la part cifrada "$CRYPTDEV"  (puede ser cadena vac�a)  # TODO this var is no maintained on the private part. just ignore it
umountCryptoPart () {

    $PVOPS umountCryptoPart "$1" "$2" "$3" "$4" "$5"

}





genNfragKey () {

    $dlg   --infobox $"Generando llave para la unidad cifrada..." 0 0

    $PVOPS genNfragKey
}


#1-> el dev
#2-> el pwd
formatearClauer () {

    $PVOPS formatearClauer "$1" "$2"
    local retval="$?"

    [ "$retval" -eq 11 ] &&  $dlg --msgbox $"No existe el dispositivo" 0 0
    [ "$retval" -eq 12 ] &&  $dlg --msgbox $"Error durante el particionado: Dispositivo inv�lido." 0 0
    [ "$retval" -eq 13 ] &&  $dlg --msgbox $"Error durante el particionado" 0 0
    [ "$retval" -eq 14 ] &&  $dlg --msgbox $"Error durante el formateo" 0 0

    echo "formatearClauer: retval: ---$retval---"  >>$LOGFILE 2>>$LOGFILE
	
    return "$retval"
}


#1->currShare
#2->numShares
#3->first clauer? 1 - Si   0 - No
#4->'config' -> only writes config 'share' -> only writes share  '' -> writes both
writeNextClauer () {

    member=$(($1+1))
         
    success=0
    while [ "$success" -eq  "0" ]
      do
      
      clauerpos=$"el siguiente"
      [ "$3" -eq 1 ] && clauerpos=$"el primer"
      
      insertUSB $"Inserte $clauerpos Clauer a escribir ($member de $2) y pulse INTRO." "none"
      # TODO comprobar con nuevo funcionamiento de esta func , entre otras cosas, no hay loop infinito. si ret 1, pedir de nuevo
     
      
      #Pedir pasword nuevo
      
      #Acceder  # TODO esto es un mount, checkdev y getpwd (y format usb + format store), adem�s esto coincide con lo visto fuera, seguramente lo pueda meter todo en una func y/o hacer un bucle
      storeConnect $DEV "newpwd" $"Miembro n�mero $member:\nIntroduzca una contrase�a nueva:"
      ret=$?
      
      #Si el acceso se cancela, pedimos que se inserte otro
      if [ "$ret" -eq 1 ] 
	  then
	  $dlg --msgbox $"Ha abortado el formateo del presente Clauer. Inserte otro para continuar" 0 0
	  continue
      fi
      
      #Formatear y particionar el dev        
      $dlg   --infobox $"Preparando Clauer..." 0 0

      formatearClauer "$DEV" "$PASSWD"   
      retf="$?"

      if [ "$retf" -ne 0  ]
	  then
	  continue
      fi

      sync
      
      #escribir fragmento de llave
      if [ "$4" == "" -o "$4" == "share" ]
	  then

	  $dlg   --infobox $"Escribiendo fragmento de llave..." 0 0
          #0 succesully set  1 write error
	  $PVOPS storops writeKeyShare "$DEV" "$PASSWD"  "$1"
	  ret=$?
	  sync
	  sleep 1
	  
          #Si falla la escritura
	  if [ $ret -eq 1 ] 
	      then
	      $dlg --msgbox $"Ha fallado la escritura del fragmento de llave. Inserte otro Clauer para continuar" 0 0 
	      continue
	  fi
      fi
      
      #escribir config
      if [ "$4" == "" -o "$4" == "config" ]
	  then
	  
	  $dlg   --infobox $"Almacenando la configuraci�n del sistema..." 0 0

	  $PVOPS storops writeConfig "$DEV" "$PASSWD"
	  ret=$?
	  sync
	  sleep 1
	  
          #Si falla la escritura
	  if [ $ret -eq 1 ] 
	      then
	      $dlg --msgbox $"Ha fallado la escritura de la configuraci�n. Inserte otro Clauer para continuar" 0 0
	      continue
	  fi
      fi
      
      success=1
      
    done

    detectUsbExtraction $DEV $"Clauer escrito con �xito. Ret�relo y pulse INTRO." $"No lo ha retirado. H�galo y pulse INTRO."
}


writeClauers () {
  

    
    #for i in {0..23} -> no acepta sustituci�n de variables
    firstloop=1
    for i in $(seq 0 $(($SHARES-1)) )
      do
      writeNextClauer $i $SHARES $firstloop
      sync

      [ "$firstloop" -eq "1" ] && firstloop=0
      
    done


}


    


#//// revisar el uso correcto en modo mant  --> no veo la diferencia. probarlo en funcionamiento y seguir el proceso.
#Reconstruye la clave, con fines de comprobar la autorizaci�n de realizar acciones 
# de mantenimiento sin reiniciar el equipo o para recuperar los datos del backup

# 1 -> el modo de readClauer (k, c, o b (ambos))  # Quiz� pasar al flujo directo, ver d�nde se usa
getClauersRebuildKey () {
    
    
    ret=0
    firstcl=1
    #mientras queden dispositivos
    while [ $ret -ne 1 ]
      do
      
      readNextUSB  "$1"  
      status=$?
      
      [ "$firstcl" -eq 1 ] && firstcl=0
      
      if [ "$status" -eq 9 ]
	  then
	  $dlg --yes-label $"Reanudar" --no-label $"Finalizar"  --yesno  $"Ha cancelado la inserci�n de un Clauer.\n�Desea finalizar la inserci�n de dispositivos?" 0 0  
	  
	  #Si desea finalizar, salimos del bucle
	  [ $? -eq 1 ] && break;
	  
      fi
      
      #Error
      if [ "$status" -ne 0  ]
	  then
	  $dlg --msgbox $"Error de lectura. Pruebe con otro dispositivo" 0 0
	  ret=0
	  continue
      fi
      

      #Si todo ha ido bien y ha leido config, compararlas
      if [ "$1" == "c" -o "$1" == "b" ] ; then
	  $PVOPS storops compareConfigs
      fi
      
      #Preguntar si quedan m�s dispositivos
      $dlg   --yes-label $"S�" --no-label $"No" --yesno  $"�Quedan m�s Clauers por leer?" 0 0  
      ret=$?
      
    done
	


    
    $dlg   --infobox $"Reconstruyendo la llave de cifrado..." 0 0
        
rebuildKey 
	ret=$?

	#Si no se logra con ninguna combinaci�n, p�nico y adi�s.
        if [ "$ret" -ne 0 ] 
	    then
	    $dlg --msgbox  $"No se ha podido reconstruir la llave." 0 0 
	    return 1
	fi
	
    fi

    $dlg --msgbox $"Se ha logrado reconstruir la llave." 0 0 

    return 0
}

