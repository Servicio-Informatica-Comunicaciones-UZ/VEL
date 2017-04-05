#!/bin/bash


#Command sequence to output bold text
bold=$(tput bold)

#Command sequence to output normal text
normal=$(tput sgr0)



#Write a log message
tell () {
    echo "["$(date +%T)"] $*"
}

#Write a log message in bold text
warn () {
    echo "${bold}["$(date +%T)"] $*${normal}"
}

#Write a message and exit
die () {
    echo "${bold}["$(date +%T)"] $*${normal}"
    exit 1
}



#Write a log message (use inside chroot)
ctell () {
    echo "CHROOT["$(date +%T)"] $*"
}

#Write a log message in bold text (use inside chroot)
cwarn () {
    echo "${bold}CHROOT["$(date +%T)"] $*${normal}"
}

#Write a message and exit (use inside chroot)
cdie () {
    echo "${bold}CHROOT["$(date +%T)"] $*${normal}"
    exit 1
}







buildNumber () {
    echo $(date +%Y%m%d%H%M)
}


# 1: source filename with extension
getBasename () {
    echo $1 | rev | cut -f 2- -d '.' | rev
}

# 1: source filename with extension
getExtension () {
    echo $1 | grep -e "\." | rev | cut -f 1 -d '.' | rev
}


#TODO revisar
#$1 -> Ruta base
#$2 -> Octal perms for files
#$3 -> Octal perms for dirs

setPerm () {
    dirs="$1 "$(ls -R $1/* | grep -oEe "^.*:$" | sed -re "s/^(.*):$/\1/")
    
    echo -e "Directorios:\n $dirs"

    for dir in $dirs
      do
      
      files=$(ls -p $dir | grep -oEe "^.*[^/]$")
      ds=$(ls -p $dir | grep -oEe "^.*[/]$")
      
      echo -e "=== Dir $dir files: ===\n$files"
      echo -e "=== Dir $dir dirs : ===\n$ds"
      
      for f in $files
	do
	echo "chmod $2 $dir/$f"
	chmod $2 $dir/$f
      done

      for d in $ds
	do
	echo "chmod $3 $dir/$d"
	chmod $3 $dir/$d
      done
    done
}
