
systemMonitorScreen () {

    refresh=true
    while $refresh ;
    do
        
        $PVOPS stats > /tmp/stats  2>>$LOGFILE
        
        # 0 -> refrescar
        # 3 -> volver
        #No me vale un msgbox pq s�lo puede llevar un button, y el yesno tampoco porque no hace scroll
        $dlg --ok-label $"Refrescar" --extra-button  --extra-label $"Volver" --no-cancel --textbox /tmp/stats 0 0
        
        [ $? -ne 0 ] && refresh=false
    done
    
    rm -f /tmp/stats  >>$LOGFILE  2>>$LOGFILE
}


        ######### Resetea las RRD de estad�ticas del sistema ########
        "resetrrds" )
            
            $dlg  --yes-label $"S�"  --no-label $"No"   --yesno  $"�Seguro que desea reiniciar la recogida de estaditicas del sistema?" 0 0 
	           [ "$?" -ne "0" ] && return 1
            
	           #Resetemaos las estad�sticas
	           $PVOPS stats resetLog
	           
	           $dlg --msgbox $"Reinicio completado con �xito." 0 0
	           
            ;;
