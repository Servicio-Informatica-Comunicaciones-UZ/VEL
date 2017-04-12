#!/bin/bash

# Generates a number of rando users on the tabulated form accepted by
# the voting application

# $1 --> Number of test users to generate


function randN () {
    #$1 -> number of ciphers the random number must have
    
    local ciphers=1

    [ "$1" != "" ] && ciphers=$1


    while [ "$ciphers" -gt 0 ]
      do
      echo -n  $(($RANDOM%10))
      
      ciphers=$((ciphers-1))
    done
}


count=0

if [ "$1" == "" ]
    then
    max=10
elif [ "$1" -le "0" ]
    then
    max=10
else
    max="$1"
fi



while [ "$count" -lt "$max"  ]
  do

  echo "user${count}!$(randN 8)X!Surname, User Name${count}"

  count=$((count+1))

done
