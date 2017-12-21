#! /bin/bash

# Copyright (C) 2007, 2010-2017 Free Software Foundation, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.


if [ "$(id -u)" -ne 0 ]
then 
	echo ""
	echo "Permission denied (must be superuser)"
	echo ""
    exit
fi

PORT=0
TIMEOUT=1
INTERVAL=5
BACK=60
COUNT=3
KILL=0
LIST=0
PERSIST=0
UNINSTALL=0
VERS=0
VERSION="threshold v2.0"

# Make sure there is at least one argument being used
if [ $# -eq 0 ]
then
	echo ""
	echo "$0: You must choose at least one argument"
	echo "usage example: threshold -d 127.0.0.1 -a \"my action to take upon trigger\""
	echo "see \"man threshold\" for more details"
else
	while [ $# -gt 0 ]; do
		case ${1} in
			-d|--destination)
				HOSTIP="${2}"
				shift;shift
				;;
			-t|--timeout)
				TIMEOUT="${2}"
				shift;shift
				;;
			-i|--interval)
				INTERVAL="${2}"
				shift;shift
				;;
			-c|--count)
				COUNT="${2}"
				shift;shift
				;;
			-a|--action)
				COMMAND="${2}"
				shift;shift
				;;
			-P|--port)
				PORT="${2}"
				shift;shift
				;;
			-k|--kill)
				KILL="${2}"
				shift;shift
				;;
			-b|--backoff)
				BACK="${2}"
				shift;shift
				;;
			-p|--persist)
				PERSIST=1
				shift;shift
				;;
			-l|--list)
				LIST=1
				shift;shift
				;;
			-v|--version)
				VERS=1
				shift;shift
				;;
			-u|--uninstall)
				UNINSTALL=1
				shift;shift
				;;

			*)
				echo "$0: Unknown argument \"${1}\"" >&2
				echo "see \"man threshold\" for usage details" >&2
				exit 1
				;;
		esac
	done
	
# Check if user wants to see version
if [ "$VERS" == "1" ]
then
   echo "$VERSION"
exit
fi


# Check if user wants to uninstall threshold
if [ "$UNINSTALL" -eq 1 ]
then
		read -p "Are you sure you want to uninstall threshold (N/y)? " answer
			answer=${answer:-N}
			answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
			if [ "$answer" == "y" ]
			then
				echo "Cleaning up any running jobs..."
				MYPID=$BASHPID
				for PID in $(pgrep threshold)
				do
					if [ $MYPID -ne $PID ]
					then
						kill -9 $PID
					fi
				done
	            echo "Uninstalling threshold..."
				rm -Rf /etc/threshold/
				rm -f /usr/share/man/man1/threshold.1.gz
				rm -- $0
				echo "Done!"
				exit 0	
			else 
				exit 0
			fi	
fi


# Prepend a sequential number to each PID lock file so that we can run multiple instances if needed
SEQUENCE=$$

# Job directory and files for tracking
TRIGGERDIR=/etc/threshold/triggers/*
TRIGGER=/etc/threshold/triggers/$SEQUENCE
ACTIONDIR=/etc/threshold/actions/*
USER_COMMAND=/etc/threshold/actions/$SEQUENCE



# Does the customer want to list existing jobs?
if [ $LIST -eq 1 ]
then
	if [ "$(ls -1 /etc/threshold/triggers/ | wc -l)" -gt 0 ]
	then
		for file in $TRIGGERDIR
		do 
			tail -n 4 $file
		done
		exit 0
	else
		echo "There are currently no pending monitors/actions..."
		exit 0
	fi
fi



# Does the customer want to kill a specific job or perhaps ALL jobs?
if [ "$KILL" != "0" ]
then


	  # Create a reusable function for deleting user monitor/actions below

			   delete_job()
			   {

							for action in $ACTIONDIR
							do

								ACTIONID=$(head -n 1 $action)
								ACTIONID=$(echo "$ACTIONID" | grep -oP [0-9]+)
								if [ "$PARENTID" == "$ACTIONID" ]
								then
									rm -f $action
								fi
							done

						kill -9 "$JOBID" 
						kill -9 "$PARENTID"
						rm -f $file
					
				}
	# Take out leading and trailing whitespaces
	KILL="${KILL// /}"

	# Find out if user is trying to kill a specific job id
	if ! [[ "$KILL" =~ [0-9]+ ]]
	then 
		# If not specific id then all jobs
		if [ "$KILL" == "" ]
		then
			read -p "This will kill ALL of your current threshold jobs. Do you wish to continue (N/y)? " answer
			answer=${answer:-N}
			answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
			if [ "$answer" == "n" ]
			then
				echo "Nothing done, exiting..."
				exit 0
			elif [ "$answer" == "y" ]
			then
				if [ "$(ls -1 /etc/threshold/triggers/ | wc -l)" -gt 0 ]
				then
					echo "killing ALL threshold jobs..."
				    for file in $TRIGGERDIR
					do
					    JOBID=$(sed -n '2 p' < $file)
						JOBID=$(echo "$JOBID" | grep -oP [0-9]+)
						PARENTID=$(head -n 1 $file)
						delete_job
					done

					echo "Done!"
					exit 0
				else
					echo "There are no jobs to stop..."
					exit 0
				fi
			else
				echo "Exiting...please choose 'Y' or 'N'"
				exit 0
			fi	
		else
			echo "You must choose a valid job id to kill (ie. kill -9 1234)"
		fi
	else
		# handle deletion of individual job, and remove residual tracking data
		for file in $TRIGGERDIR
		do
			JOBID=$(sed -n '2 p' < $file)
			JOBID=$(echo "$JOBID" | grep -oP [0-9]+)
			if [ "$KILL" -eq "$JOBID" ]
			then 
				PARENTID=$(head -n 1 $file)
				delete_job
				echo "Killed job: ${KILL}..."
				exit 0
			fi
		done
		echo "Job $KILL no longer seems to exist..."
		exit 0
	fi
fi

main_script(){

    # Get the commmand that user wants to run, and save it to file. Threshold will run this if later triggered
	if [ -n "$COMMAND" ]
	then
		echo "$COMMAND" >> "$USER_COMMAND"

		# have the action file delete itself after the action has run
		echo "rm -- \$0" >> "$USER_COMMAND"

		if [ -n "$HOSTIP" ]
		then
			# Monitor to run if target host is an HTTP or HTTPs URL, and user wants to continually download from this address
			if [[ "$HOSTIP" =~ [h,H][t,T][t,T][p,P]+ ]]
			then
				if [ $TIMEOUT -eq 1 ]
				  then
					  TIMEOUT=60
			    fi
           job_data(){
				echo "Job Id: $PID" >> "$TRIGGER"
				echo "Monitor: Download $HOSTIP in a loop. Download takes longer than $TIMEOUT sec, breach alarm" >> "$TRIGGER"
				echo "Action: $COMMAND" >> "$TRIGGER"
				echo "" >> "$TRIGGER"
				}
				curl_loop() {

						# Now do the actual transfer monitor
						curl -o /dev/null -s -k "$HOSTIP" &
						EXIST=$!
						TIME=0
						while true; do
							   sleep 1
							  ((TIME++))
							   if [ $TIME -gt $TIMEOUT ]
							   then
									if [ "$(ps -p "$EXIST" | tail -1 | awk '{print $1}')" == "$EXIST" ]
									then
									   nohup sh "$USER_COMMAND" &
									   kill -9 "$EXIST"
									   rm -f "$TRIGGER"
									   rm -f "$USER_COMMAND"

									   if [ $PERSIST -eq 1 ]
									   then
									   		sleep "$BACK"
									   fi
									   break
									fi
								elif [ "$(ps -p "$EXIST" | tail -1 | awk '{print $1}')" != "${EXIST}" ]
								then	
										if [ -f /usr/bin/threshold ]
										then
											sleep "$BACK"
											curl_loop
											break
										else
											exit 0
										fi
								fi
							done > /dev/null 2>&1
					}		
					curl_loop &
					PID=$!
					job_data
						
			# Monitor to run if user wants to ping target
			elif [ $PORT -eq 0 ]
			then
				while true; do
					ping -c "$COUNT" -i "$INTERVAL" -W "$TIMEOUT" "$HOSTIP" 
					result=$?
					if [ $result -ne 0 ]
					then 
						nohup sh "$USER_COMMAND" &
						rm -f "$TRIGGER"
						break
					fi
				done > /dev/null 2>&1 &
				PID=$!
				echo "Job Id: $PID" >> "$TRIGGER"
				echo "Monitor: Ping $HOSTIP every $INTERVAL second(s). $COUNT consecutive failures, breach alarm" >> "$TRIGGER"
				echo "Action: $COMMAND" >> "$TRIGGER"
				echo "" >> "$TRIGGER"

			# Monitor to run if user wants to initiate TCP handshakes with target in a loop
			else
				while true; do
					i=0
					while [ $i -lt $COUNT ]; do
						nc -w "$TIMEOUT" "$HOSTIP" "$PORT" 
						result=$?
						if [ $result -ne 0 ]
						then 
							i=$((i+1))
							sleep "$INTERVAL"
						else
							i=0
							sleep "$INTERVAL"
						fi
					done	
					nohup sh "$USER_COMMAND" &
					rm -f "$TRIGGER"
					break
				done > /dev/null 2>&1 &
				PID=$!
				echo "Job Id: $PID" >> "$TRIGGER"
				echo "TCP handshake with ${HOSTIP}:${PORT} every $INTERVAL seconds. $COUNT consecutive failed handshakes, breach alarm" >> "$TRIGGER"
				echo "Action: $COMMAND" >> "$TRIGGER"
				echo "" >> "$TRIGGER"

			fi
		else 
			echo "you must specify a destination (-d) target IP or hostname to create a trigger"
			echo "see \"man threshold\" for usage details"
		fi
			
	fi
	# Now continually check to see if a job exists, before proceeding through rest of this script
	while [ -f "$TRIGGER" ]
	do 
		sleep 1
	done

	# If the user has chosen to make this job persistent, then run the main script again once the previous one has finished
	if [ $PERSIST -eq 1 ]
	then
	    main_script > /dev/null &
	    PID=$!
	    echo "$PID" >> "$TRIGGER"
	    echo "#${PID}" >> "$USER_COMMAND"
	    exit
	fi
}
main_script > /dev/null &

# We must save this main script PID to terminate it if user chooses to delete its child process
PID=$!
echo $PID >> "$TRIGGER" 
echo "#${PID}" >> "$USER_COMMAND"

fi

