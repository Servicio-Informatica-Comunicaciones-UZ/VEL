#Useful debugging code snippets for bash

# set -x activates trace mode on bash (like 'bash -x script.sh' ), which will print on stderr and this will go to tty2
exec 2>/dev/tty2
set -x


# Debugging tool: Every time a command return value is non-zero, it will stop and show the prompt on stderr
trap "read -p 'NON ZERO RETURN DETECTED (check if OK). Press return to go on.'" ERR
