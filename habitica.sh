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
## Config & definitions
###############################################################################



########
# Entry-point to the REST-ful API
########

export readonly HABITICA_API='https://habitica.com/api/v3';



########
# Non-standard return values
########

export readonly ASLEEP=2;
export readonly AWAKE=0;



###############################################################################
## Init vars
###############################################################################

export SERVER_RESPONSE='';



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
function echoerr() {
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
function echo_usage() {
	local self;
	self="$(basename "$0")";

	echo "Usage: $self <command>";
	echo;
	echo "Where <command> is:";
	echo "   accept   Accepts the current quest";
	echo "   cast <spell>    See '$self cast help' for more info";
	echo "   sleep    Go to sleep (enter the Tavern)";
	echo "   status   Returns the API status (up|down)";
	echo "   wake     Stop sleeping (leave the Tavern)";

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
function echo_usage_cast() {
	local self;
	self="$(basename "$0")";

	echo "Usage: $self cast <spell>";
	echo;
	echo "Where <spell> is one of:";
	echo "   heal     Heal party [Healer only]";
	echo "   help     Show this text";
	echo "   freeze   Preserve streaks overnight [Mage only, once per day]";

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
function load_config() {
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
#	API_TOKEN			User's password
#	HABITICA_API		Entry-point to the API
#	SERVER_RESPONSE		Message from server
#	USER_ID				User to query
#
# Arguments
#	1			URL to query, relative to $HABITICA_API/
#	2			Which part of the response we care about
#
# Returns
#	0|1			1 on failure, else 0
#	stderr		Error from server
########
function get_from_server() {
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


	## init vars
	local response success;


	## empty the response
	SERVER_RESPONSE='';


	## get JSON from the server
	response="$( \
		curl -s \
			-H "x-api-user: $USER_ID" \
			-H "x-api-key: $API_TOKEN" \
			-X GET \
			"$HABITICA_API/$1" \
		)";


	# if we've failed, return the reason
	success="$(echo "$response" | jq -r .success)";
	message="$(echo "$response" | jq -r .message)";
	if [ 'true' !=  "$success" ]; then
		echoerr "$message";
		return 1;
	fi;


	# pass the response via a GLOBAL
	SERVER_RESPONSE="$(echo "$response" | jq -r "$2")";
	if [ ! $? ]; then
		echoerr "Failed to get $2 from server";
		return 1;
	fi;


	return 0;
}



########
# Send a message to Habitica, using Curl
#
# Globals
#	API_TOKEN			User's password
#	HABITICA_API		Entry-point to the API
#	SERVER_RESPONSE		Message from server
#	USER_ID				User to query
#
# Arguments
#	1			URL to query, relative to $HABITICA_API/
#	2			Which part of the response we care about
#
# Returns
#	0|1			1 on failure, else 0
########
function send_to_server() {
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


	## init vars
	local message response success;


	## empty response
	SERVER_RESPONSE='';


	# get JSON from the server
	response="$( \
		curl \
			--silent \
			--data "" \
			--header "x-api-user: $USER_ID" \
			--header "x-api-key: $API_TOKEN" \
			--request POST \
			"$HABITICA_API/$1" \
		)";
	#echo "send_to_server::response $response";


	# if we've failed, return the reason
	success="$(echo "$response" | jq -r .success)";
	#echo "send_to_server::success $success";
	message="$(echo "$response" | jq -r .message)";
	#echo "send_to_server::message $message";
	if [ 'true' != "$success" ]; then
		echoerr "$message";
		return 1;
	fi;


	# pass the response via a GLOBAL
	SERVER_RESPONSE="$(echo "$response" | jq -r "$2")";
	if [ ! $? ]; then
		echoerr "Failed to get $2 from server";
		return 1;
	fi;


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
########
function accept_quest() {
	local message;


	## accept quest
	message="$(send_to_server "groups/$GROUP_ID/quests/accept" '.message' 2>&1)";	# catch stderr and ignore return, as already-questing is an error
	#echo "accept_quest::message $message";


	## 'no invites' returns 1, so ignore that "error"
	if [ 'No quest invitation found.' = "$message" ]; then
		return 0;
	fi;

	## 'already questing' returns 1, so ignore that "error"
	if [ 'Your party is already on a quest. Try again when the current quest has ended.' = "$message" ]; then
		return 0;
	fi;

	## 'already accepted' returns 1, so ignore that "error"
	if [ 'You already accepted the quest invitation.' = "$message" ]; then
		return 0;
	fi;


	## anything else is an error, so echo and quit
	echoerr "$message";
	return 1;
}



########
# Return the server's status
#
# Globals
#	SERVER_RESPONSE		Message from server
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
#	2			Server is *not* up
########
function get_api_status() {
	get_from_server 'status' '.data.status' || return 1;

	## server may be down -- this is not an error in our script, so don't return 1
	if [ 'up' != "$SERVER_RESPONSE" ]; then
		return 2;
	fi;

	return 0;
}



########
# Enter the Tavern
#
# Globals
#	ASLEEP		Exit-code from sleeping_toggle()
#	AWAKE		Exit-code from sleeping_toggle()
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
########
function sleeping_start() {
	local state;


	# toggle state; returns state
	state=0;	# default to 0
	sleeping_toggle || state=$?;
	if [ 1 -eq $state ]; then return 1; fi;


	# if we're now awake, toggle again!
	if [ $ASLEEP -ne $state ]; then
		state=0;	# default to 0
		sleeping_toggle || state=$?;
		if [ 1 -eq $state ]; then return 1; fi;
	fi;


	if [ $ASLEEP -ne $state ]; then
		return 1;
	fi;

	return 0;
}



########
# Leave the Tavern
#
# Globals
#	ASLEEP		Exit-code from sleeping_toggle()
#	AWAKE		Exit-code from sleeping_toggle()
#
# Arguments
#	None
#
# Returns
#	0|1			1 on failure, else 0
########
function sleeping_stop() {
	local state;


	# toggle state; returns state
	state=0;	# default to 0
	sleeping_toggle || state=$?;
	if [ 1 -eq $state ]; then return 1; fi;


	# if we're now asleep, toggle again!
	if [ $ASLEEP -eq $state ]; then
		state=0;	# default to 0
		sleeping_toggle || state=$?;
		if [ 1 -eq $state ]; then return 1; fi;
	fi;


	if [ $AWAKE -ne $state ]; then
		return 1;
	fi;

	return 0;
}



########
# Toggles awake/asleep
#
# Globals
#	SERVER_RESPONSE		Reply from the server; should be 'true' or 'false'
#
# Arguments
#	None
#
# Returns
#	0			Awake
#	1			Failure
#	2			Asleep
########
function sleeping_toggle() {
	local response return;

	send_to_server 'user/sleep' '.data' || return 1;

	if [ 'true' = "$SERVER_RESPONSE" ]; then
		return $ASLEEP;
	fi;

	return $AWAKE;
}



########
# Cast Chilling Frost on self
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
function cast_freeze() {
	send_to_server 'user/class/cast/frost' '.success' || return 1;
	if [ 'true' != "$SERVER_RESPONSE" ]; then return 1; fi;

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
########
function cast_heal() {
	send_to_server 'user/class/cast/healAll' '.success' || return 1;
	if [ 'true' != "$SERVER_RESPONSE" ]; then return 1; fi;

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
	if [ 1 -gt $# ]; then
		echoerr "Can't find command; quitting";

		echo;
		echo_usage;

		return 1;
	fi;


	## init vars
	local command return subcommand;

	command="$1";
	#echo "route_command::command $command";

	subcommand="${2-}";	# if $2 is unset, set to ""
	#echo "route_command::subcommand $subcommand";


	## route command
	case "$command" in
		'accept' )
			accept_quest || {
				echoerr 'Failed to accept quest';
				return 1;
			};

			echo 'Accepted';
			;;


		'cast' )
			case "$subcommand" in
				'freeze' )
					cast_freeze || {
						echoerr 'Failed to freeze streaks';
						return 1;
					};

					echo 'Streaks frozen';
					;;


				'heal' )
					cast_heal || {
						echoerr 'Failed to heal';
						return 1;
					};

					echo 'Healed';
					;;


				'help' | '--help' )
					echo_usage_cast;
					;;


				* )
					echoerr "Command '$command $subcommand' not recognised; quitting";

					echo;
					echo_usage_cast;

					return 1;
					;;
			esac;
			;;	# end 'cast'


		'help' | '--help' )
			echo_usage;
			;;


		'sleep' )
			sleeping_start || {
				echoerr 'Failed to sleep';
				return 1;
			};

			echo 'Asleep';
			;;


		'status' )
			return=0;
			get_api_status || return=$?;

			if [ 1 -eq $return ]; then 
				echoerr 'Failed to get server status';
				return 1;
			fi;

			if [ 2 -eq $return ]; then 
				echo 'Down';
				return 2;
			fi;

			echo 'Okay';
			;;


		'wake' )
			sleeping_stop || {
				echoerr 'Failed to wake';
				return 1;
			}

			echo 'Awake';
			;;


		* )
			echoerr "Command '$command' not recognised; quitting";

			echo;
			echo_usage;

			return 1;
			;;
	esac;


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

main "$@" || exit $?;
exit 0;
