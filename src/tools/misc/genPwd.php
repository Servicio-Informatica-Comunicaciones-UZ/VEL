#!/usr/bin/php
<?php

#This tool generates a password which is compatible with the ones used
#by the voting webapp (used by the local management interface)

#Generates a salted password by applying md5 5 times on the concatenation
#of the password (plain at first, the oputput of the previous salting
#later) and the salt.

#Salt can be specified or it generates a random 10 character salt each time.

#Return is a concatenation of the salt and the salted password.
#salt+saltedPwd

#To validate it (10 is the length of the standard salt):
#$PasswordToCompare=genPwd($inputClearPassword,substr($storedSaltedPassword,0,10));

function genPwd($pwd,$sal='') {
  if (!$sal)
    $sal=substr(md5(uniqid('',true)),0,10);
  for ($i=0; $i<5; $i++)
    $pwd=md5($sal.$pwd);
  return $sal.$pwd;
}

if(sizeof($argv)>1)
  echo genPwd($argv[1]);


?>