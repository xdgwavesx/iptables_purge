#!/bin/bash

quit() {
        exit 1
}

# check whether running as root
perm_check() {
        USERID=$(id -u $USER)
        if [[ $USERID -ne 0 ]]
        then
                echo '[!] run this script as root.'
                quit
        fi
}
perm_check


# tables usually manipulated in netfilter
TABLES="filter nat mangle"
TABLES=$(echo $TABLES | tr ' ' '\n') 

VERBOSE=true
BACKUP=false
SAVE_FILE='iptables.rules'
RESET=false
ZERO_COUNTERS=false
FLUSH_RULES=false
DELETE_CHAINS=false

help() {
	echo "################################################"
	echo "                 RESET IPTABLES                #"
	echo "################################################"
	echo ""
        echo "[!] Usage: "
	echo -e "\t\tsudo $0 < -R > | < -Z | -F | -D > [ [-q|--quiet] [-b|--backup] [-h|--help] ]"
        echo "[!] Options: "
        #echo "[*] -y  force delete without any interaction."
	echo -e "\t-R | --reset\t\treset entire firewall to the default state"
	echo -e "\t\t\t(delete all rules and chains and zeroing the counters)"
	echo "[!] custom options for cleaning: "
	echo -e "\t-Z | --zero\t\tzero all the counters in all chains and tables."
	echo -e "\t-F | --flush\t\tflush all the rules in all the tables."
	echo -e "\t-D | --delete\t\tdelete all the chains in all the tables."
	echo ""
        echo -e "\t-h | --help\t\tShow this help."
        echo -e "\t-b | --backup\t\tcreate backup of existing chains and rules."
	echo -e "\t-f | --backup-file <name_or_path_to_file>\t\tcustom filename [Default: iptables.rules]"
        echo -e "\t-q | --quiet\t\tbe quiet!"
	echo ""
	echo "ex: $0 --reset --backup --backup-file router.rules"
        exit 0
}


# parse the command line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help) help;;
        #-y| --yes) FORCE=true;;
        -q|--quiet) VERBOSE=false;;
        -b|--backup) BACKUP=true;;
	-f|--backup-file) SAVE_FILE="$2"; shift;;
	-R|--reset) RESET=true;;
	-Z|--zero) ZERO_COUNTERS=true;;
	-F|--flush) FLUSH_RULES=true;;
	-D|--delete) DELETE_CHAINS=true;;
        *) echo "Unknown parameter passed: $1"; help; exit 1 ;;
    esac
    shift
done

if $RESET; then
	ZERO_COUNTERS=true
	FLUSH_RULES=true
	DELETE_CHAINS=true
fi

if ! $ZERO_COUNTERS && ! $FLUSH_RULES && ! $DELETE_CHAINS; then
	help
fi

print_verbose() {
	if $VERBOSE; then
		echo -e "[!] $1"
	fi
}


backup() {
  # creating backup for all rules first
  print_verbose "saving backup of existing rules -> [$SAVE_FILE]."
  iptables-save > $SAVE_FILE
  print_verbose "done."
  print_verbose
}

zero_counters() {
  # ZERO the counters in all chains in all tables
  print_verbose "ZEROING all the counters in all the tables..."
  for table in $TABLES; do
    iptables -t $table -Z
    print_verbose "\t-> $table..ok"
  done
  print_verbose "done."
}

flush_rules() {
  # flushing all rules in existing chains [nat, mangle, filter]
  print_verbose "FLUSHING all the rules in all the tables..."
  for table in $TABLES; do
    iptables -t $table -F
    print_verbose "\t-> $table..ok"
  done
  print_verbose "done."
}

get_all_chains() {
    # identify all chains in all tables
    print_verbose "DELETING THE CHAINS"
    for table in $TABLES; do
	    print_verbose "$table: "
    iptables -L -nv -t $table | while read line
    do
      # skip empty line after each chain
      if [[ $line == '' ]]; then
        continue
      fi

      # if the line doesn't start with the name Chain, it can either be a rule, empty line or rules heading.
      if [[ ${line:0:5} != 'Chain' ]]; then
        continue
      fi

      # Here we will skip the default chains in iptables.
      chain=$(echo $line | cut -d ' ' -f 2)
      if [[ $chain == 'INPUT' ]] || [[ $chain == 'OUTPUT' ]] || [[ $chain == 'FORWARD' ]] || [[ $chain == 'PREROUTING' ]] || [[ $chain == 'POSTROUTING' ]]; then
        continue
      fi
      iptables -t $table -X $chain
      print_verbose "\t -> $chain..ok"
    done
  done
}

main() {
  
  if $BACKUP; then
    backup
  else 
    read -p "[!] you haven't opted for a backup of all rules? want to create one? [y/n] " choice
    if [[ $choice == 'y' ]]; then
      backup
    fi
    print_verbose
  fi
 
  # #
  if $ZERO_COUNTERS; then
    zero_counters
  fi
  
  
 # FLUSHING RULES MECHANISM 
  if $FLUSH_RULES; then     
  	flush_rules
  fi
  ###########################

  # deleting chains mechanism
  if $DELETE_CHAINS; then
  	get_all_chains
  fi
  #################################
}

welcome() {
  datum="""
##############################################
#                                            #
#         PURGE IPTABLES (netfilter)         #
#					     #
#	 :BACKUP -> $BACKUP		     #
"""
if $BACKUP; then
	datum+="""#	 :BACKUP FILE -> $SAVE_FILE	     #
"""
fi
datum+="""#	 :ZERO COUNTERS -> $ZERO_COUNTERS	         #
"""
datum+="""#	 :FLUSH RULES -> $FLUSH_RULES	     	     #
"""
datum+="""#	 :DELETE CHAINS -> $DELETE_CHAINS	     	     #
"""
datum+="""#	 :VERBOSE -> $VERBOSE		     #
"""
datum+="""##############################################
"""

echo -e "$datum"
}

welcome
main
