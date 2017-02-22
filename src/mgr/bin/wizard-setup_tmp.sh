







# TODO 

#design recovery to be simpler: start as a new system setup but ask the ssh recovery params (limit the params to be configured to network and data drive? the rest should be inside the recovery just steps 2-4, maybe make another flow and duplicate them). once there is network and a data drive, retrieve the bak file and untar on it. Then, go on with setup. remember to read the vars from disk as if it was a restart, also ask for the usbs to get the recovery key and at the end rewrite them? --> drive and network params must be updated on the recovered config files/usbs, so the order is:
# * get usbs and rebuild key
# * Get new network info,
# * setup network
# * get new drive info
# * get recovery ssh info.
# * check recovery info
# * regenerate drive key or use the same?? --> regenerate
# * setup new drive --> remember: only setup the dev and mount. No file creation. --> we delete before recovery
# * download recovery file on the new drive and pipe extract recovery file on its location
# * update **disk** variables regarding network
# * update **usb** variables regarding drive
# * go on with the normal setup after the load drive part (including reading the variables). -->check all the process to find holes
# * write the usbs with the updated drive config --> at the same point as on install, at the end


cat bakfile.tgz.aes | openssl enc -d  -aes-256-cfb  -pass "pass:$PASS" | tar xzf - -C /dest_base_folder/
#Ojo! en destbasefolder descomprime el árbol que hay en el tar, que es probable que sea /media/crypStorage, así que el base_folder debería ser /
#Si el pwd es incorrecto, falla con return 2, broken  pipe, porque el tar no indetifica la entrada como un gzip



    #Si se está ejecutando una restauración
    if [ "$DORESTORE" -eq 1 ] ; then #////probar

        # TODO asegurarme de que se hace el trust antes de descargar el backup
        
	       while true; do 
	           
	           $dlg --msgbox $"Prepare ahora los Clauers del sistema anterior. Vamos a recuperar los datos." 0 0

            #La llave y la config a restaurar las metemos en el slot 2
	           $PVOPS storops-switchSlot 2

	           

            #Pedir Clauers con la config y rebuild key
	           readUsbsRebuildKey
	           ret=$?

	           if [ $ret -ne 0 ] 
		          then 
		              $dlg --msgbox $"Error durante la recuperación del backup. Vuelva a intentarlo." 0 0 
		              continue
	           fi


	           #Recuperamos el fichero y lo desciframos
	           $PSETUP recoverSSHBackup_phase1 
	           if [ $? -ne 0 ] 
		          then
		              $dlg --msgbox $"Error durante la recuperación del backup. Vuelva a intentarlo." 0 0
		              continue
	           fi
	           
	           
	           #Volvemos al Slot de la instalación nueva (sobre la que estamso restaurando la vieja)
	           $PVOPS storops-switchSlot 1


	           break
	       done


    fi
    
   if [ "$DORESTORE" -eq 1 ] ; then

	$PSETUP recoverSSHBackup_phase2
	
    fi

    


