#!/bin/bash
# Methods and global variables only common to all non-privileged scripts go here

###############
#  Constants  #
###############

#Actual version number of this voting system
VERSION=$(cat /etc/vtUJIversion)



#############
#  Methods  #
#############



#Wrapper: move logs to privileged location
# $1 ->   'new': new install (just moves logs)
#       'reset': substitutes logs for the previous ones and saves apart current ones
relocateLogs () {
    $PSETUP  relocateLogs "$1"
}





#Configure access to ciphered data
#1 -> 'new': setup new ciphered device
#     reset: load existing ciphered device
configureCryptoPartition () {
    
    if [ "$1" == 'new' ] ; then
	       $dlg --infobox $"Formatting ciphered data device..." 0 0
    else
	       $dlg --infobox $"Accessing ciphered data device..." 0 0
    fi
    sleep 1
    
    #Setup the partition
    $PVOPS configureCryptoPartition "$1"
    local ret=$?
    [ "$ret" -eq 2 ] && $dlg --msgbox  $"Error mounting base drive." 0 0
    [ "$ret" -eq 3 ] && $dlg --msgbox  $"Critical error: no empty loopback device found" 0 0
    [ "$ret" -eq 4 ] && $dlg --msgbox  $"Unknown data access mode. Configuration is corrupted or tampered." 0 0
    [ "$ret" -eq 5 ] && $dlg --msgbox  $"Couldn't encrypt the storage area." 0 0
    [ "$ret" -eq 6 ] && $dlg --msgbox  $"Couldn't access storage area."  0 0
    [ "$ret" -eq 7 ] && $dlg --msgbox  $"Couldn't format the filesystem." 0 0
    [ "$ret" -eq 8 ] && $dlg --msgbox  $"Couldn't mount the filesystem." 0 0
    [ "$ret" -ne 0 -a "$ret" -lt 2 -a "$ret" -gt 8 ] && $dlg --msgbox  $"Error configuring encrypted drive." 0 0
    
    return $ret
}






#Get a password from user
#1 -> mode:  (auth) will ask once, (new) will ask twice and check for equality
#2 -> message to be shown
#3 -> cancel button? 0 no, 1 yes (default)
# Return 0 if ok, 1 if cancelled
# $PASSWD : inserted password (due to dialog handling the stdout)
getPassword () {
    
    exec 4>&1
    
    local nocancelbutton=""    
    [ "$3" == "0" ] && nocancelbutton=" --no-cancel "

    local pass=''
    local pass2=''
    local errmsg=''
    while true; do
        
	       pass=$($dlg $nocancelbutton --max-input 32 --passwordbox "$2" 10 40 2>&1 >&4)
	       [ $? -ne 0 ] && return 1 
	       
	       [ "$pass" == "" ] && continue
        
        #If this is a new password dialog
        if [ $1 == 'new' ] 
	       then
            #Check password strength
            errmsg=$(checkPassword "$pass")
            if [ $? -ne 0 ] ; then
                $dlg --msgbox "$errmsg" 0 0
                continue
            fi
            
	           pass2=$($dlg $nocancelbutton  --max-input 32 --passwordbox $"Vuelva a escribir su contraseña." 10 40 2>&1 >&4)
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
#1 -> 'c': read the config only
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
    [ $? -ne 0 ] && return 1 #Mount error

    #Ask for device password
    while true ; do
        #Returns passowrd in $PASSWD
        getPassword auth $"Please, insert the password for the connected USB device" 1
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Password insertion cancelled." 0 0
            $PVOPS mountUSB umount
            return 2
        fi
	       
        #Access the store on the mounted path and check password
        #(store name is a constant expected by the store handler)
        $PVOPS storops-checkPwd /media/usbdrive/ "$PASSWD" 2>>$LOGFILE
        if [ $? -ne 0 ] ; then
            #Keep asking until cancellation or success
            $dlg --msgbox $"Password not correct." 0 0
            continue
        fi
        break
    done
    
    #Read config
    if [ "$1" != "k" ] ; then
	       $PVOPS storops-readConfigShare /media/usbdrive/ "$PASSWD" >>$LOGFILE 2>>$LOGFILE
        ret=$?
	       if [ $ret -ne 0 ] ; then
	           $dlg --msgbox $"Error ($ret) while reading configuration from USB." 0 0
            $PVOPS mountUSB umount
	           return 3
	       fi

        #Check config syntax
        $PVOPS storops-parseConfig  >>$LOGFILE 2>>$LOGFILE
        if [ $? -ne 0 ] ; then
            $dlg --msgbox $"Configuration file tampered or corrupted." 0 0
            $PVOPS mountUSB umount
            return 4
        fi
        
        #Compare last read config with the one currently considered as
        #valid (if no tampering occurred, all should match perfectly)
        #If different, user will be prompted
	       differences=$($PVOPS storops-compareConfigs)
        if [ $? -eq 1 ]
        then
            $dlg --msgbox $"Found differences between the last configuration file and the previous ones. This is unexpected and should be carefully examined for tampering or corrution" 0 0
            
            #Show the differences
            echo "$differences" | $dlg --programbox 40 80

            #Let the user choose
            $dlg --yes-label $"Current"  --no-label $"New"  --yesno  $"Do you wish to use the current one or the new one?" 0 0
            #Decided to use the new one, set it
            if [ $? -eq  1 ] ; then
		              log "Using new config."
                $PVOPS storops-resolveConfigConflict
            fi
        fi
        
    fi
    
    #Read keyshare
    if [ "$1" != "c" ] ; then
       	$PVOPS storops-readKeyShare /media/usbdrive/ "$PASSWD" >>$LOGFILE 2>>$LOGFILE
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







#Will try to rebuild the key using the shares on the active slot
rebuildKey () {
    
    $PVOPS storops-rebuildKey
    
    #If rebuild failed, try a lengthier approach
    if [ $? -ne 0 ]
    then
        $dlg --msgbox $"Key reconstruction failed. System will try to recover. This might take a while." 0 0 

        $PVOPS storops-rebuildKeyAllCombs 2>>$LOGFILE  #0 ok  1 bad pwd
	       local ret=$?
        local errmsg=''
        #If rebuild failed again, nothing can be done, go back
	       [ $ret -eq 10 ] && errmsg=$"Missing configuration parameters."
        [ $ret -eq 11 ] && errmsg=$"Not enough shares available."
        [ $ret -eq 1  ] && errmsg=$"Some shares may be corrupted. Not enough left."
        if [ $ret -ne 0 ] ; then
            $dlg --msgbox $"Key couldn't be reconstructed. $errmsg" 0 0 
            return 1
	       fi
	   fi
    
    return 0
}







#Will sequentially ask users to insert a usb drive and read the key
#fragment and configuration (optionally) from it to the active slot
# 1 -> By default, will read both the key and the configuration
#        (and settle it to be used)
#      'keyonly' will only read and rebuild the key
#Returns: 0 if OK, 1 if failed, 2 if cancelled
readUsbsRebuildKey () {  # Rename this and all the refs
    
    local readMode="b"
    [ "$1" == "keyonly" ] && readMode="k"
    
    while true
    do
        #Ask to insert a device and read config (optionally) and key share
        readNextUSB $readMode
        ret=$?
        [ $ret -eq 1 ] && continue   #Read error: ask for another usb
        [ $ret -eq 2 ] && continue   #Password error: ask for another usb
        [ $ret -eq 3 ] && continue   #Read config/keyshare error: ask for another usb
        [ $ret -eq 4 ] && continue   #Config syntax error: ask for another usb
        
        #User cancel
        if [ $ret -eq 9 ] ; then
            $dlg --yes-label $"Go on" --no-label $"Back to the menu" \
                 --yesno  $"Do you want to go on or cancel the procedure and go back to the menu?" 0 0  

            [ $? -eq 1 ] && return 2 #Cancel, go back
            #Go on, ask for another usb or start rebuilding
        fi
        
        #Successfully read and removed, ask if any remaining
        $dlg --yes-label $"Insert another device" --no-label $"No more left" \
             --yesno  $"Are there any devices left?" 0 0
        
        [ $? -eq 1 ] && break #None left, go on
        continue #Any left, ask for another usb
    done
    
    #If config was read, set it as the one in use
    if [ "$1" != "keyonly" ] ; then
        #All devices read, set read config as the working config # On keyonly, do not settle
        $PVOPS storops-settleConfig  >>$LOGFILE 2>>$LOGFILE
    fi
    
    #Try to rebuild key (first a simple attempt and then an all combinations)
    $dlg --infobox $"Reconstructing ciphering key..." 0 0
    rebuildKey
    [ $? -ne 0 ] && return 1 #Failed
    
    $dlg --msgbox $"Key successfully rebuilt." 0 0
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
###TODO depués, los valores establecidos aquí se pasarán al  privil. op adecuado donde se parsearán de nuevo y se establecerán si corresponde. Hacer op para leer y preestablecer los valores de estas variables y usarlas como valores default (para los pwd, obviamente, no)
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
                    local hostn=''
                    local domn=''
                    
	                   hostn=$($dlg --cancel-label $"Back"  --inputbox  \
		                               $"Hostname:" 0 0 "$HOSTNM"  2>&1 >&4)
                    #If back, show the mode selector again
                    [ "$?" -ne 0 ] && continue 2
                    
	                   parseInput hostname "$hostn"
	                   [ $? -ne 0 ] && errmsg=""$"Hostname not valid."
                    
	                   domn=$($dlg --cancel-label $"Back"  --inputbox  \
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
            IFS=$BAKIFS
            
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
	   log "IPMODE: "$IPMODE   # TODO guess where these vars are passed to the privileged part and stored on the config (either drive or usbdevs)
	   log "IP:   "$IPADDR  # TODO I guess in dhcp mode, this is not set, and it is used in configureHostDomain, extratc the IP from somewhere (use a function I'll create to parse the certificate auth script, getOwnIP)
	   log "MASK: "$MASK
	   log "GATE: "$GATEWAY
	   log "DNS1: "$DNS1
	   log "DNS2: "$DNS2
	   log "HOSTNM: "$HOSTNM
 	  log "DOMNAME: "$DOMNAME
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
    log "Configuring network: $PVOPS configureNetwork $IPMODE $IPADDR $MASK $GATEWAY $DNS1 $DNS2"
    $dlg --infobox $"Configuring network connection..." 0 0
    
    #On reset, paremetrs will be empty, but will be read from the config fiile
    $PVOPS configureNetwork "$IPMODE" "$IPADDR" "$MASK" "$GATEWAY" "$DNS1" "$DNS2"
    local ret="$?"
    
    if [ "$ret" == "11"  ]; then
	       log "Error: no accessible ethernet interfaces found." 
	       return 1
    elif [ "$ret" == "12"  ]; then
	       log "Error: No destination reach from any interface."
        return 1
    elif [ "$ret" == "13"  ]; then
	       log "Error: DHCP client error."
        return 1
    elif [ "$ret" == "14"  ]; then
	       log "Error: Gateway connectivity error."
        return 1
    elif [ "$ret" == "15"  ]; then
	       log "Error: Internet connectivity error."
        return 2
    fi
    
    return 0
}


#Does all the needed configurations regarding the hostname and domain
#name, also for the mail server
#Will access the following global variables:
# IPADDR
# HOSTNM
# DOMNAME
configureHostDomain () {
    
    $PVOPS configureHostDomain "$IPADDR" "$HOSTNM" "$DOMNAME"
    
    $PVOPS mailServer-domain "$HOSTNM" "$DOMNAME"
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
# ADMINIP
sysAdminParams () {

    #If set, allows edition of password fields only
    local lock=0
    [ "$1" == 'lock' ] && lock=2
    
    local choice=""
    exec 4>&1
	   while true
	   do
	       local formlen=9
	       choice=$($dlg  --cancel-label $"Back"  --mixedform  $"System administrator information" 0 0 23  \
	                      $"Field"              1  1 $"Value"       1  30  17 15   2  \
	                      $"User name"          3  1 "$ADMINNAME"   3  30  17 256  $lock  \
                       $"ID number"          5  1 "$ADMIDNUM"    5  30  17 256  $lock  \
                       $"E-mail address"     7  1 "$MGREMAIL"    7  30  17 256  $lock  \
                       $"Full name"          9  1 "$ADMREALNAME" 9  30  17 256  $lock  \
                       $"Admin's IP address" 12 1 "$ADMINIP"     12 30  17 15   0  \
	                      $"Web APP password"   15 1 "$MGRPWD"      15 30  17 256  1  \
	                      $"Repeat password"    17 1 "$repMGRPWD"   17 30  17 256  1  \
	                      $"Local password"     20 1 "$LOCALPWD"    20 30  17 256  1  \
	                      $"Repeat password"    22 1 "$repLOCALPWD" 22 30  17 256  1  \
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
                
		              "5" ) # ADMINIP
		                  parseInput ipaddr "$item"
				                if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Administrator's IP address not valid."
                    else ADMINIP="$item" ; fi
		                  ;;
                
		              "6" ) # MGRPWD
                    local auxmgrPwd="$item"
                    pwderrmsg=$(checkPassword "$item")
		                  if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Web app password:"" $pwderrmsg"
		                  else MGRPWD="$item" ; fi
				                ;;
	               
		              "7" ) # repMGRPWD
		                  if [ "$item" != "$auxmgrPwd" ] ; then loopAgain=1; errors="$errors\n"$"Web app password: passwords don't match."
		                  else local repMGRPWD="$item" ; fi
		                  ;;
                
		              "8" ) # LOCALPWD
                    local auxlocalPwd="$item"
                    pwderrmsg=$(checkPassword "$item")
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Local password:"" $pwderrmsg"
		                  else LOCALPWD="$item" ; fi
		                  ;;

                "9" ) # repLOCALPWD
		                  if [ "$item" != "$auxlocalPwd" ] ; then loopAgain=1; errors="$errors\n"$"Local password: passwords don't match."
		                  else local repLOCALPWD="$item" ; fi
		                  ;;
	           esac
            
            #Next item, until the number of expected items
	           i=$((i+1))
            IFS=$(echo -en "\n\b")
	       done
        IFS=$BAKIFS
        
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
    log "ADMINNAME:   $ADMINNAME"
    log "MGRPWD:      $MGRPWD"
    log "LOCALPWD:    $LOCALPWD"
    log "ADMIDNUM:    $ADMIDNUM"
    log "MGREMAIL:    $MGREMAIL"
    log "ADMREALNAME: $ADMREALNAME"
    log "ADMINIP:     $ADMINIP"
    #</DEBUG>
    
    return 0
}






#Prompt user to select a partition among those available
#1 -> 'all' to list all available partitions
#     'wfs' to show only those with a valid fs
#2 -> Top message to be shown
#Return: 0 if ok, 1 if cancelled
#DRIVE: name of the selected partition
hddPartitionSelector () {
    
    local partitions=''
    partitions=$($PVOPS listHDDPartitions "$1" fsinfo)
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
    local drive=''
    drive=$($dlg --cancel-label $"Cancel"  \
                 --menu "$2" 0 80 \
                 $(($npartitions)) $partitions 2>&1 >&4)
	   #If canceled, go back to the mode selector
	   [ $? -ne 0 -o "$drive" == "" ]  && return 1;
    
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
                local fsize=''
                fsize=$($dlg --cancel-label $"Back"  --inputbox  \
		                           $"Loopback filesystem file size (in MB):" 0 0 "$FILEFILESIZE"  2>&1 >&4)
                [ $? -ne 0 ] && continue 2  #If back, go to the mode selector
                
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
    log "Crypto drive mode: $DRIVEMODE" 
    log "Local path:        $DRIVELOCALPATH" 
	   log "Local file:        $FILEPATH"
	   log "File system size:  $FILEFILESIZE"
		  log "Filename:          $CRYPTFILENAME"
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
        IFS=$BAKIFS
        
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
    done
    #<DEBUG>
    log "SSH Server:        $SSHBAKSERVER"
	   log "SSH port:          $SSHBAKPORT"
	   log "SSH User:          $SSHBAKUSER"
	   log "SSH pwd:           $SSHBAKPASSWD"
    #</DEBUG>
    
    return 0
}





#Does a test connection to the set SSH backup server
#Return: 0 if OK, non-zero if any problem happened
checkSSHconnectivity () {
    
		  #Set trust on the server
    sshScanAndTrust "$SSHBAKSERVER"  "$SSHBAKPORT"
    if [ $? -ne 0 ] ; then
        log "SSH Keyscan error."
        return 1
		  fi
    
    #Perform test connection
    sshRemoteCommand "$SSHBAKSERVER"  "$SSHBAKPORT"  "$SSHBAKUSER"  "$SSHBAKPASSWD"  >>$LOGFILE 
    return $?
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
	       [ "$MAILRELAY" == "" ] && return 0
        
        #Check input value
	       parseInput ipdn "$MAILRELAY"
	       if [ $? -ne 0 ] ; then
	           $dlg --msgbox $"Mail relay must be a valid domain name or IP address." 0 0
	           continue
	       fi
	  	    break
	   done
    
    #<DEBUG>
    log "Mail relay: $MAILRELAY"
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
        IFS=$BAKIFS
            
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
	   done
    
    #<DEBUG>
    log "SHARES: $SHARES"
    log "THRESHOLD: $THRESHOLD"
    #</DEBUG>

    return 0
}











#Prompts the user to select whether to use lets'encrypt automatic CA
#with certbot or to go for a classical hand installed certificate
#Will set the following global variables:
#USINGCERTBOT
sslModeParameters () {
    
    #Let the user choose
    $dlg --yes-label $"Use Let's Encrypt"  --no-label $"I will handle the certificate manually"  --yesno  $"Do you wish to use a certificate from Let's Encrypt Certification Authority (automatic, instant and free of charge) or do you wish to use a traditional CA? (You may go from one mode to another at any time )" 0 0
    #Decided to use certbot
    if [ $? -eq  0 ] ; then
		      log "Using certbot."
        USINGCERTBOT="1"
    else
        log "Using a traditional CA."
        USINGCERTBOT="0"
    fi
    
    #<DEBUG>
    log "USINGCERTBOT: $USINGCERTBOT"
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
    [ "$DOMNAME" == "" ] && DOMNAME=$(getVar disk DOMNAME)
    
    #Default values
    [ "$DEPARTMENT" == "" ] && DEPARTMENT="-"
    [ "$STATE" == "" ] && STATE="-"
    [ "$LOC" == "" ] && LOC="-"
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
                      $"Contact e-mail"                     15 1 "$SERVEREMAIL" 15 40  20  30  0  \
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
                    if [ "$item" != "-" ] ; then
		                      parseInput x500 "$item"
                        if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Department name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                    else DEPARTMENT="$item" ; fi
                    fi
                    ;;
		              
		              "3" ) #COUNTRY
		                  parseInput cc "$item"
                    if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Country code not valid. Must be a two letter ISO-3166 code."
  		                else COUNTRY="$item" ; fi
                    ;;
		              
		              "4" ) #STATE
                    if [ "$item" != "-" ] ; then
		                      parseInput x500 "$item"
                        if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"State/Province name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                    else STATE="$item" ; fi
                    fi
                    ;;
		              
		              "5" ) #LOC
                    if [ "$item" != "-" ] ; then
                        parseInput x500 "$item"
                        if [ $? -ne 0 ] ; then loopAgain=1; errors="$errors\n"$"Locality name not valid. Can contain any of the following:""\n$ALLOWEDCHARSET"
  		                    else LOC="$item" ; fi
                    fi
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
        IFS=$BAKIFS
            
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
    log "COMPANY: $COMPANY"
    log "DEPARTMENT: $DEPARTMENT"
    log "COUNTRY: $COUNTRY"
    log "STATE: $STATE"
    log "LOC: $LOC"
    log "SERVEREMAIL: $SERVEREMAIL"
    log "SERVERCN: $SERVERCN"
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
lcnRegisterParams () {
    
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
        IFS=$BAKIFS
        
        #Show errors in the form, then loop
	       if [ "$loopAgain" -eq 1 ] ; then
            $dlg --msgbox "$errors" 0 0
            continue
	       fi
        break
	   done
        
    
    #<DEBUG>
    log "SITESEMAIL: $SITESEMAIL"
	   log "SITESPWD: $SITESPWD"
	   log "SITESORGSERV: $SITESORGSERV"
	   log "SITESNAMEPURP: $SITESNAMEPURP"
	   log "SITESCOUNTRY: $SITESCOUNTRY"
    #</DEBUG>
    
    return 0
}






#Generates a certificate request and key that will later be used for
#the anonimity network registration
#Global variables accessed:
#KEYSIZE
#SITESEMAIL
#SITESORGSERV
#SITESNAMEPURP
#SITESCOUNTRY
#Will set the following global variables:
#SITESPRIVK
#SITESCERT
#SITESEXP
#SITESMOD
esurveyGenerateReq () {
    
	   #Generate service's package signing certificate with the provided info
	   local pair=$(openssl req -x509 -newkey rsa:$KEYSIZE -keyout /dev/stdout -nodes -days 3650 \
		                       -subj "/C=$SITESCOUNTRY/O=$SITESORGSERV/CN=$SITESNAMEPURP/emailAddress=$SITESEMAIL" 2>>$LOGFILE)
	   
	   if [ "$pair" == "" ] ; then
        log "Error generating sites cert"
        return 1
    fi
	   
	   SITESPRIVK=$(echo "$pair" | sed -n -e "/PRIVATE/,/PRIVATE/p");
	   SITESCERT=$(echo "$pair" | sed -n -e "/CERTIFICATE/,/CERTIFICATE/p")
	   
    
	   SITESEXP=$(echo -n "$SITESPRIVK" | openssl rsa -text 2>/dev/null | sed -n -e "s/^publicExponent.*(0x\(.*\))/\1/p" | hex2b64)
	   SITESMOD=$(echo -n "$SITESPRIVK" | openssl rsa -text 2>/dev/null | sed -e "1,/^modulus/ d" -e "/^publicExponent/,$ d" | tr -c -d 'a-f0-9' | sed -e "s/^00//" | hex2b64)
    
    #SITESPRIVK=""
    #SITESCERT=""
    #SITESEXP=""
    #SITESMOD=""
}






#Issues a register request to the anonimity network central
#authority. Will produce an authentication token to communicate with
#them.
#Global variables accessed:
#SITESEMAIL
#SITESPWD
#SITESPRIVK
#SITESCERT
#Will set the following global variables:
#SITESTOKEN
esurveyRegisterReq () {
    
    #Generate certificate sign request from the self-signed certificate and then, urlencode it
	   local certReq=$(echo "$SITESCERT" >/tmp/crt$$; echo "$SITESPRIVK" |
		                      openssl x509 -signkey /dev/stdin -in /tmp/crt$$ -x509toreq 2>>$LOGFILE |
                        sed -n -e "/BEGIN/,/END/p" |
		                      sed -e :a -e N -e 's/\//%2F/g;s/=/%3D/g;s/+/%2B/g;s/\n/%0A/;ta' ; rm /tmp/crt$$);
    
    
	   #Urlencode email and pwd:
	   local mail=$($urlenc "$SITESEMAIL" 2>>$LOGFILE)
	   local pwd=$($urlenc "$SITESPWD" 2>>$LOGFILE)
    
    
    #Send the request
	   $dlg --infobox $"Connecting with the Anonimity Network Central Authority..." 0 0
	   
	   #'once' paramater makes it impossible to unregister the service
	   #once confirmed. This way, a malicious administrator cannot deny
	   #anonimity network access on a critical moment (like during an
	   #election)
	   local result=$(wget  -O - -o /dev/null "https://esurvey.nisu.org/sites?mailR=$mail&pwdR=$pwd&req=$certReq&lg=es&once=1")
    log "Anonimity central authority response: $result"  
    
	   if [ "$result" == "" ] ; then
		      $dlg --msgbox $"Error connecting with the Anonimity Network Central Authority." 0 0
        SITESTOKEN=""
        return 1
	   fi
    
    #Process response lines
	   local linenum=1
	   local errmsg=""
    local status=""
	   for line in $(echo "$result")
		  do 
		      case "$linenum" in
		          "1" ) #Status Line
                status="$line"
                [ "$status" == "ERR" ] && errmsg=$"Request error. Probably because of e-mail address already registered with a different password."
			             [ "$status" == "REG" ] && errmsg=$"Request error. Probably because of e-mail address already registered with a different password."
                [ "$status" == "DUP" ] && errmsg=$"Request error. Found a former request with the same information. Please, modify."
			             [ "$status" != "OK" ]  && errmsg=$"Unexpected request error."
		              ;;

		          "2" ) #On ERR,DUP: status message; On OK: service's exponent in b64 extracted from the certificate
                [ "$status" == "ERR" -o "$status" == "DUP" ] && errmsg="$errmsg\n"$"Returned message:""\n$line"
		              [ "$status" == "OK" -a "$SITESEXP" != "$line" ] && errmsg=$"Server error. Response information didn't match request."
                ;;
		          
		          "3" ) #On OK service's modulus in b64 extracted from the certificate
		              [ "$status" == "OK" -a "$SITESMOD" != "$line" ] && errmsg=$"Server error. Response information didn't match request."
                ;;
		          
		          "4" ) #On OK: authentication token for future service-authrotiy communication
		              [ "$status" == "OK" ] && SITESTOKEN="$line"
		              ;;	
		      esac
		      linenum=$(($linenum+1))
    done
    
    if [ "$errmsg" != "" ] ; then
        $dlg --msgbox "$errmsg" 0 0
        SITESTOKEN=""
        return 1
    fi
    
    #<DEBUG>
	   log "SITESTOKEN: $SITESTOKEN"  
	   log "SITESPRIVK: $SITESPRIVK"  
	   log "SITESCERT: $SITESCERT"  
	   log "SITESEXP: $SITESEXP"  
	   log "SITESMOD: $SITESMOD"  
    #</DEBUG>
    
    return 0
}




#Checks all existing shares on the active slot
testForDeadShares () {
    
    $PVOPS storops-testForDeadShares
    local ret="$?"
    
    [ "$ret" -eq 2 ] && $dlg --msgbox $"Internal error. Lacking needed configuration." 0 0
    [ "$ret" -eq 3 ] && $dlg --msgbox $"Can't rebuild. Not enough shares." 0 0
    
    return $ret
}





#Will generate a RSA keypair and then a certificate request to be
#signed by a CA
# 1 -> 'new': will generate the keys and the csr
#    'renew': only a new csr will be generated
#Global variables accessed:
# SERVERCN
# COMPANY
# DEPARTMENT
# COUNTRY
# STATE
# LOC
# SERVEREMAIL
generateCSR () {
    
    $dlg --infobox $"Generating SSL certificate request..." 0 0
    log "$PVOPS generateCSR '$mode' '$SERVERCN' '$COMPANY' '$DEPARTMENT' '$COUNTRY' '$STATE' '$LOC' '$SERVEREMAIL'" 
    
    $PVOPS generateCSR "$mode" "$SERVERCN" "$COMPANY" "$DEPARTMENT" "$COUNTRY" "$STATE" "$LOC" "$SERVEREMAIL"
    if [ $? -ne 0 ]
	   then
		      $dlg --msgbox $"Error generating the SSL certificate request." 0 0
	       return 1
    fi
    
    return 0
}





#Instructs the user to insert a usb device and writes the server csr
#for its signature by a CA
# 1 -> 'cancel' to allow cancel, '' (default) to keep looping
fetchCSR () {
    local ret=0
    
    local cancel=0
    local cancelMsg=$"Start again"
    if [ "$1" == "cancel" ] ; then
        cancel=1
        cancelMsg=$"Cancel"
    fi
    
    while true ; do
        
        #Detect device insertion
        insertUSB $"Insert USB storage device" "$cancelMsg"
        ret=$?
        if [ $ret -eq 1 ] ; then
            [ "$cancel" -eq 1 ] && return 1 #Can cancel, return
            continue #Cannot cancel, just restart this step
        fi
        if [ $ret -eq 2 ] ; then
            #No readable partitions found. Ask to use another one
            $dlg --msgbox $"Device contained no readable partitions. Try another one." 0 0
            continue 
        fi
        
        #Mount the device (will do on /media/usbdrive)
        $PVOPS mountUSB mount $USBDEV
        if [ $? -ne 0 ] ; then
            #Mount error. Try another one
            $dlg --msgbox $"Error mounting the device. Try another one." 0 0
            continue 
        fi
        
        #Write the CSR
        $dlg --infobox $"Writing certificate request..." 0 0 
        $PVOPS fetchCSR
        if [ $? -ne 0 ] ; then
            #Copy error. Try another
            $dlg --msgbox $"Error while copying the certificate request. Try another device." 0 0
            continue
        fi
        
        #Umount the device once done reading
        $PVOPS mountUSB umount
        
        #Detect extraction before returning control to main program
        detectUsbExtraction $USBDEV $"Certificate request stored. Remove device and press RETURN." \
                            $"Didn't remove it. Please, do it and press RETURN."
        
        break
    done
    
    return 0
}





#Detects insertion of a device and writes the config and keyshare from
#the current slot there
#1 -> index number of the share (on the slot) to be written to the usb
#2 -> total number of shares
# Return: 1: mount or format error
#         2: format cancelled
#         9: insertion cancelled
writeNextUSB () {
    
    #Detect device insertion
    current=$(($1+1)) #indexes start at zero, add 1 to make it readable
    insertUSB $"Insert USB key storage device to be written ($current of $2)" $"Cancel"
    [ $? -eq 1 ] && return 9
    if [ $? -eq 2 ] ; then
        #No readable partitions.
        $dlg --msgbox $"Device contained no writable partitions." 0 0
        return 1
    fi
    
    #Mount the device (will do on /media/usbdrive)
    $PVOPS mountUSB mount $USBDEV
    [ $? -ne 0 ] && return 1 #Mount error
    
    #Ask for a new device password (returns password in $PASSWD)
    getPassword new $"Please, insert a password to protect the connected USB device" 1
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Password insertion cancelled." 0 0
        $PVOPS mountUSB umount
        return 2
    fi
    
    $dlg  --infobox $"Writing key secure storage..." 0 0
    
    #Initialise the store
    $PVOPS storops-formatKeyStore /media/usbdrive/ "$PASSWD" 2>>$LOGFILE
    if [ $? -ne 0 ] ; then
        $dlg --msgbox $"Format error." 0 0
        return 1
    fi
    
    #Write key fragment
	   $PVOPS storops-writeKeyShare /media/usbdrive/ "$PASSWD"  "$1"
	   if [ $? -ne 0 ] ; then
        log "Error writing key share on store: "
        $dlg --msgbox $"Write error." 0 0
        $PVOPS mountUSB umount
        return 1
    fi
    
    #Write configuration block
    $PVOPS storops-writeConfigBlock /media/usbdrive/ "$PASSWD"
	   if [ $? -ne 0 ] ; then
        log "Error writing config block on store: "
        $dlg --msgbox $"Write error." 0 0
        $PVOPS mountUSB umount
        return 1
    fi
    
    #Ensure write is complete and umount
	   sync
	   $PVOPS mountUSB umount
    
    #Ask the user to remove the usb device
    detectUsbExtraction $USBDEV $"USB device successfully written. Remove it and press RETURN." \
                        $"Didn't remove it. Please, do it and press RETURN."
    
    return 0
}





#Will sequentially ask users to insert a usb drive and write the key
#fragment and configuration from the active slot there
#1 -> Total number of usbs to be written
#Returns: 0 if OK, 1 if failed, 2 if cancelled
writeUsbs () {

    local i=0
    local total=$1
    
    #While there are usbs left writing
    while [ $i -lt $total ]
    do
        writeNextUSB $i $total
        ret=$?
        [ $ret -eq 1 ] && continue   #Write error: ask for another usb to write the same share
        [ $ret -eq 2 ] && continue   #Cancelled: ask for another usb to write the same share
        
        #If write succeeded, go on to the next usb
        i=$((i+1))
    done
}





# Lets the user select a file path inside the mounted USB
# $1 -> User prompt message
#Return: 0: OK 1: Cancelled
#chosenFilepath: the path selected by the user
selectUsbFilepath() {
    
    local title=$"Select a file: ""\Z2""$1\Z0"

    
    local helpLine=$"(Press F1 for Help)"
    local helpMsg=$"Use tab or arrow keys to move between the windows.
Within the directory or filename windows, use the 
up/down arrow keys to scroll the current selection.
Use the space-bar to copy the current selection 
into the text-entry window."
    echo "$helpMsg" >/tmp/fselectHelper

    #Return global
    chosenFilepath=""
	   
    while true
    do
        #Select the path
        local selPath=""
        selPath=$($dlg --backtitle "$title"  --colors \
                       --hfile /tmp/fselectHelper \
                       --hline "$helpLine" \
                       --fselect /media/usbdrive/ 8 60 2>&1 >&4 )
        [ $? -ne 0 -o "$selPath" == "" ] && return 1 # Cancelled        
		      
        #Syntax check the resulting path
        parseInput path "$selPath"
        if [ $? -ne 0 ]  ; then 
	           $dlg --msgbox $"Bad path. Directory names can contain:""$ALLOWEDCHARSET" 0 0 
	           continue
        fi
        
        #Check that the path is strictly a subdirectory of the mounted
        #usb device
        if ! (echo "$selPath" | grep -Ee "^/media/usbdrive/.+" >>$LOGFILE 2>>$LOGFILE) ; then
	           $dlg --msgbox $"Bad path. Must be a file inside the USB device" 0 0  
	           continue
        fi
        
        #Check that path does not contain directory backreferences (../)
        if (echo "$selPath" | grep -Ee "/\.\.(/| |$)" >>$LOGFILE 2>>$LOGFILE) ; then 
	           $dlg --msgbox $"Bad path. Upper directories not allowed in path." 0 0  
	           continue
        fi
        
        #Check that the path is a file
        if [ ! -f "$selPath" ] ; then
            $dlg --msgbox $"Path is not a file." 0 0  
	           continue
        fi
        
        break
    done
    
    chosenFilepath="$selPath"
    return 0
}





#tries to access and test-read a remote file through SSH
#1 -> Remote file path
#Return: 0 if OK, non-zero if any problem happened (see inside)
checkSSHRemoteFile () {
    
		  #Set trust on the server
    sshScanAndTrust "$SSHBAKSERVER"  "$SSHBAKPORT"
    if [ $? -ne 0 ] ; then
        log "SSH Keyscan error."
        return 1
		  fi
    
    #Check if file exists (and we have permissions to the containing directory)
    sshRemoteCommand "$SSHBAKSERVER"  "$SSHBAKPORT"  "$SSHBAKUSER"  "$SSHBAKPASSWD" "[ -e  '$1' ]" >>$LOGFILE 
    [ $? -ne 0 ] && return 2
    
    #Check if file is not empty
    sshRemoteCommand "$SSHBAKSERVER"  "$SSHBAKPORT"  "$SSHBAKUSER"  "$SSHBAKPASSWD" "[ -s '$1' ]" >>$LOGFILE 
    [ $? -ne 0 ] && return 3
    
    #Check if file can be read
    readProof=$(sshRemoteCommand "$SSHBAKSERVER"  "$SSHBAKPORT"  "$SSHBAKUSER"  "$SSHBAKPASSWD" "head -c 1 '$1'" | wc -c)
    [ $readProof -ne 1 ] && return 4
    
    #All tests passed
    return 0
}
