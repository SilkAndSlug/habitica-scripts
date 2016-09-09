#!/bin/bash



########
## Silk's Habitica Scripts
########
#
# Wrappers for Habitica's v3 API
#
#########


## bootstrap
set -u;	# treat undefined vars as errors
set -e;	# halt on error



########
## Functions
########


## write to stderr
function echoerr {
	if [ 1 -ne $# ]; then return 1; fi;

	echo "$1" 1>&2;
	return 0;
}


## explain options
function echo_usage {
	echoerr "Usage: $0 <command>";

	return 0;
}


## choose between functions
function main {
	if [ 1 -ne $# ]; then
		echoerr "Can't find command; quitting"
		echo_usage;
		exit 1; 
	fi;

	case "$1" in
		* )
			echo_usage;
			return 1;
			;;
	esac;

	init;
	return 0;
}



########
## Main
########

main "$@";
exit $?;
