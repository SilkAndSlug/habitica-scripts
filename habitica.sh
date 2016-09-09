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
	echoerr "";
	echoerr "Where <command> is:";
	echoerr "	status		Returns the API status (up|down)";

	return 0;
}


## return the server's status
function get_api_status {
	local status=$( curl -s -X GET https://habitica.com/api/v3/status | jq -r .data.status );

	if [ 'up' == "$status" ]; then
		echo 'up';
		return 0;
	elif [ 'down' == "$status" ]; then
		echo 'down';
		return 0;
	fi;

	echoerr "Failed to get status; skipping...";
	return 1;
}


## choose between functions
function main {
	if [ 1 -ne $# ]; then
		echoerr "Can't find command; quitting"
		echo_usage;
		exit 1; 
	fi;

	case "$1" in
		'status' )
			get_api_status;
			return $?;
			;;

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
