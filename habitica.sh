#!/bin/bash
########
# Silk's Habitica Scripts
#
# Wrapper for Habitica's v3 API
########



###############################################################################
## bootstrap
###############################################################################

set -u;	# treat undefined vars as errors
set -e;	# exit on (uncaught) error



###############################################################################
## Functions
###############################################################################



########
# Write <msg> to stderr
#
# Globals
#	None
#
# Arguments
#	1			Message to write to stderr
#
# Returns
#	0|1			1 on failure, else 0
########
function echoerr {
	if [ 1 -ne $# ]; then return 1; fi;

	echo -e "$1" 1>&2;
	return 0;
}



########
# Output parameters to stdout
#
# Globals
#	None
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
########
function echo_usage {
	echo "";
	echo "Usage: $(basename "$0") <command>";
	echo "";
	echo "Where <command> is:";
	echo "   accept   Accepts the current quest";
	echo "   heal     Casts Blessing";
	echo "   sleep    Go to sleep (enter the Tavern)";
	echo "   status   Returns the API status (up|down)";
	echo "   wake     Stop sleeping (leave the Tavern)";

	return 0;
}



########
# Fetch params from ~/.habitica
#
# Globals
#	API_TOKEN	32-char unique ID; from config file
#	GROUP_ID	32-char unique ID; from config file
#	HOME		Where to find the config file; set by the shell
#	USER_ID		32-char unique ID; from config file
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
########
function load_config {
	if [ ! -f "$HOME/.habitica" ]; then
		echoerr "Can't find ~/.habitica; quitting"
		exit 1;
	fi;


	## initialise vars (because of set -u)
	local api_token='';
	local group_id='';
	local user_id='';


	## load config file
	source "$HOME/.habitica";


	## check configs
	local is_all_okay=true;
	if [ 36 -ne ${#group_id} ]; then
		echoerr "Can't find group_id=<hash> in ~/.habitica";
		is_all_okay=false;
	fi;
	if [ 36 -ne ${#user_id} ]; then
		echoerr "Can't find user_id=<hash> in ~/.habitica";
		is_all_okay=false;
	fi;
	if [ 36 -ne ${#api_token} ]; then
		echoerr "Can't find api_token=<hash> in ~/.habitica";
		is_all_okay=false;
	fi;
	if ! $is_all_okay ; then
		echoerr "Configs missing; quitting"
		exit 1;
	fi


	## make configs readonly
	export readonly GROUP_ID="$group_id";
	export readonly USER_ID="$user_id";
	export readonly API_TOKEN="$api_token";


	return 0;
}



########
# Fetch & output a message from the server
#
# Globals
#	API_TOKEN	User's password
#	USER_ID		User to query
#
# Arguments
#	1			URL to fetch
#	2			Which part of the response we care about
#
# Returns
#	0|1			1 on failure, else 0
#	stdout		Value of $2 in $1
########
function get_from_server {
	if [ 2 -ne $# ]; then
		echoerr "Usage: get_from_server <relative URL> <response filter>";
		return 1;
	fi;


	if [ -z "$1" ]; then
		echoerr "URL not passed";
		return 1;
	fi;
	if [ -z "$2" ]; then
		echoerr "filter not passed";
		return 1;
	fi;


	# get JSON from the server
	local response="$( \
		curl -s \
			-H "x-api-user: $USER_ID" \
			-H "x-api-key: $API_TOKEN" \
			-X GET \
			"https://habitica.com/api/v3/$1" \
		)";


	# if we've failed, return the reason
	if [ 'true' != "$(echo "$response" | jq -r .success)" ]; then
		echoerr "$(echo "$response" | jq -r .message)";
		return 1;
	fi;


	# filter the JSON to the desired keys
	echo "$response" | jq -r "$2";
	return 0;
}



########
# Send a message to Habitica, using Curl
#
# Globals
#	API_TOKEN	User's password
#	USER_ID		User to query
#
# Arguments
#	1			URL to send to
#	2			Which part of the response we care about
#
# Returns
#	0|1			1 on failure, else 0
########
function send_to_server {
	if [ 2 -ne $# ]; then
		echoerr "Usage: send_to_server <relative URL> <response filter>";
		return 1;
	fi;


	if [ -z "$1" ]; then
		echoerr "URL not passed";
		return 1;
	fi;
	if [ -z "$2" ]; then
		echoerr "filter not passed";
		return 1;
	fi;


	# get JSON from the server
	local response="$( \
		curl -s \
			-H "x-api-user: $USER_ID" \
			-H "x-api-key: $API_TOKEN" \
			-X POST \
			"https://habitica.com/api/v3/$1" \
		)";


	# if we've failed, return the reason
	if [ 'true' != "$(echo "$response" | jq -r .success)" ]; then
		echo "$response" | jq -r .message >&2;
		return 1;
	fi;


	# filter the JSON to the desired keys
	echo "$response" | jq -r "$2";
	return 0;
}



########
# Accept the current group's current quest
#
# Globals
#	GROUP_ID	Which group's quest we're accepting
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
#	stdout		Server's response
########
function accept_quest {
	local message="$(send_to_server groups/$GROUP_ID/quests/accept .message 2>&1)";	# catch stderr, as already-questing is an error
	local return=$?;

	# 'already questing' error; return success
	if [ 'Your party is already on a quest. Try again when the current quest has ended.' == "$message" ]; then
		echo 'accepted';
		return 0;
	fi;

	echo "$message";
	return $return;
}



########
# Return the server's status
#
# Globals
#	None
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
#	stdout		Status
########
function get_api_status {
	local status="$(get_from_server status .data.status)";
	local return=$?;

	echo "$status";
	return $return;
}



########
# Enter the Tavern
#
# Globals
#	None
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
#	stdout		'Asleep'
########
function start_sleeping {
	local status="$(toggle_asleep_awake)";


	# if we're now awake, toggle again!
	if [ 'Asleep' != "$status" ]; then
		local status="$(toggle_asleep_awake)";
	fi;


	if [ 'Asleep' != "$status" ]; then
		echoerr "Failed to sleep";
		return 1;
	fi;

	echo 'Asleep';
	return 0;
}



########
# Leave the Tavern
#
# Globals
#	None
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
#	stdout		'Awake'
########
function wake {
	local status="$(toggle_asleep_awake)";


	# if we're now asleep, toggle again!
	if [ 'Awake' != "$status" ]; then
		local status="$(toggle_asleep_awake)";
	fi;


	if [ 'Awake' != "$status" ]; then
		echoerr "Failed to wake";
		return 1;
	fi;

	echo 'Awake';
	return 0;
}



########
# Toggles awake/asleep
#
# Globals
#	None
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
#	stdout		'Asleep'|'Awake'
########
function toggle_asleep_awake {
	local response="$(send_to_server user/sleep .data)";
	local return=$?;

	if [ 0 -ne $return ]; then return $return; fi;


	if [ "true" == "$response" ]; then
		echo 'Asleep';
	else
		echo 'Awake';
	fi;

	return 0;
}



########
# Cast Blessing
#
# Globals
#	None
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
#	stdout		'Healed'
########
function heal {
	local response="$(send_to_server user/class/cast/healAll .success)";

	if [ 'true' != "$response" ]; then return 1; fi;

	echo 'Healed';
	return 0;
}



########
# Choose between commands
#
# Globals
#	None
#
# Arguments
#	1			Requested command
#	2			Requested sub-command
#
# Returns
#	0|1			1 on failure, else 0
########
function route_command() {
	if [ 1 -gt $# ] || [ 2 -lt $# ]; then
		echoerr "Can't find command; quitting"
		echo_usage;
		exit 1;
	fi;


	# if $2 is unset, set to ""
	${2-}


	case "$1" in
		'accept' )
			accept_quest;
			return $?;
			;;


		'heal' )
			heal;
			return $?;
			;;


		'sleep' )
			start_sleeping;
			return $?;
			;;


		'status' )
			get_api_status;
			return $?;
			;;


		'wake' )
			wake;
			return $?;
			;;


		* )
			echoerr "Command '$1' not recognised; quitting";
			echoerr "";
			echo_usage;
			return 1;
			;;
	esac;


	init;
	return 0;
}



########
# Main()
#
# Globals
#	None
#
# Arguments
#	@		Passed to route_command()
#
# Returns
#	0|1			1 on failure, else 0
########
function main() {
	load_config || return 1;
	route_command "$@" || return 1;
	return 0;
}



###############################################################################
## Main
###############################################################################

main "$@" || exit 1;
exit $?;
