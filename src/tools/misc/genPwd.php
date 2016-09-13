#!/usr/bin/php
<?php

#This tool generates a password which is compatible with the ones used
#by the voting webapp (used by the local management interface)

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