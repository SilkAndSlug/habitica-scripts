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
	echoerr "	accept		Accepts the current quest";
	echoerr "	heal		Casts Blessing";
	echoerr "	sleep		Go to sleep (enter the Tavern)";
	echoerr "	status		Returns the API status (up|down)";
	echoerr "	wake		Stop sleeping (leave the Tavern)";

	return 0;
}


## fetch params from ~/.habitica
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


## accept the current group's current quest
function accept_quest {
	local response="$(curl -s \
		-X POST "https://habitica.com/api/v3/groups/$GROUP_ID/quests/accept" \
		-H "x-api-user: $USER_ID" \
		-H "x-api-key: $API_TOKEN" \
		)";


	if [ 'true' == "$(echo "$response" | jq -r .success)" ]; then
		echo 'accepted';
		return 0;
	fi;


	# extract feedback
	local message="$(echo "$response" | jq -r .message)";


	# 'already questing' error; return success
	if [ 'Your party is already on a quest. Try again when the current quest has ended.' == "$message" ]; then
		echo 'accepted';
		return 0;
	fi;


	# unknown error; pass to caller
	echoerr "$message";
	return 1;
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


## enter the Tavern
function start_sleeping {
	local status="$(toggle_asleep_awake)";


	# if we're now awake, toggle again!
	if [ "asleep" != "$status" ]; then
		local status="$(toggle_asleep_awake)";
	fi;


	if [ "asleep" != "$status" ]; then
		echoerr "Failed to sleep";
		return 1;
	fi;

	echo 'Asleep';
	return 0;
}


## leave the Tavern
function wake {
	local status="$(toggle_asleep_awake)";


	# if we're now asleep, toggle again!
	if [ "awake" != "$status" ]; then
		local status="$(toggle_asleep_awake)";
	fi;


	if [ "awake" != "$status" ]; then
		echoerr "Failed to wake";
		return 1;
	fi;

	echo 'Awake';
	return 0;
}


## toggles awake/asleep
function toggle_asleep_awake {
	local response="$(curl -s \
		-X POST https://habitica.com/api/v3/user/sleep \
		-H "x-api-user: $USER_ID" \
		-H "x-api-key: $API_TOKEN" \
		)";


	local success="$(echo "$response" | jq -r .success)";
	if [ "false" == "$success" ]; then
		echoerr "Failed to change sleep status; skipping...";
		return 1;
	fi;

	local is_asleep="$(echo "$response" | jq -r .data)";
	if [ "true" == "$is_asleep" ]; then
		echo 'asleep';
	else
		echo 'awake';
	fi;

	return 0;
}



## cast Blessing
function heal {
	local response="$(curl -s \
		-X POST https://habitica.com/api/v3/user/class/cast/healAll \
		-H "x-api-user: $USER_ID" \
		-H "x-api-key: $API_TOKEN" \
		)";
	local success="$(echo "$response" | jq -r .success)";
	if [ 'true' == "$success" ]; then
		echo 'healed';
		return 0;
	fi;

	local message="$(echo "$response" | jq -r .message)";

	echoerr "$message";
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

load_config;
main "$@";
exit $?;
