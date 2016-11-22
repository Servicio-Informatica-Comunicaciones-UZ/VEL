#!/bin/bash


DATAPATH="/media/crypStorage"
VARFILE="$DATAPATH/root/vars.conf"


#Lee la password dela cuenta ssh y la imprime
#Leer el fich de variables y grep de la correspondiente
SSHBAKPASSWD=$(cat $VARFILE | grep -Ee "^SSHBAKPASSWD=" | sed -re "s/^.+?=\"(.+)\"$/\1/g")


echo $SSHBAKPASSWD
