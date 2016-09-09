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
