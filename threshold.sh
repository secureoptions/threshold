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


if [ $(id -u) -ne 0 ]
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
KILL="0"
LIST=0
VERS=0
VERSION="threshold v1.0"

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
			-l|--list)
				LIST=1
				shift;shift
				;;
			-v|--version)
				VERS=1
				shift;shift
				;;
			-b|--backoff)
				BACK="${2}"
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
	
	# Prepend a sequential number to each PID lock file so that we can run multiple instances if needed
	EXISTING_FILES_COUNT=$(ls -1 /etc/threshold/triggers | wc -l)
	SEQUENCE="$(($EXISTING_FILES_COUNT + 1))"
	
	# Check if user wants to kill previous background trigger or action
	if [ "$KILL" != "0" ]
	then
		if [ "$KILL" == "all" ]
		then
			if [ $(ls -1 /etc/threshold/pids/ | wc -l) -ge 1 ]
			then 
				echo "Deleting all trigger/action jobs..."
				for file in /etc/threshold/pids/*; do
					PID="$(cat $file)"
					kill -9 $PID
					rm -f $file
				done
				rm -f /etc/threshold/triggers/*
				rm -f /etc/threshold/actions/*
				echo "Done!"
			else
				echo "There are no trigger/action jobs to kill"
			fi
		elif [[ "$KILL" =~ [0-9]+ ]]
		then
			echo "Deleting trigger/action job ${KILL}"
			kill -9 $KILL
			if [ $(ls -1 /etc/threshold/pids/ | wc -l) -ge 1 ]
			then
				for pid in /etc/threshold/pids/*; do
					compare=$(cat $pid)
					if [ "$compare" == "$KILL" ]
					then 
						for trigger in /etc/threshold/triggers/*; do
							if [ "$(echo ${pid##*/})" == "$(echo ${trigger##*/})" ]
							then
								rm -f "$trigger"
							fi
						done
						for action in /etc/threshold/actions/*; do
							if [ "$(echo ${pid##*/})" == "$(echo ${action##*/})" ]
							then
								rm -f "$action"
							fi
						done
						rm -f "$pid"
					fi
				done
			fi
		else
			echo "You must choose an job ID # to kill, or choose 'threshold -k all' to kill ALL trigger/actions jobs"
			exit
		fi
	fi
	
	# Check if user wants to list jobs
	if [ $LIST -eq 1 ]
	then
		if [ $(ls -1 /etc/threshold/triggers/ | wc -l) -ge 1 ]
		then
			for trigger in /etc/threshold/triggers/*; do
				for action in /etc/threshold/actions/*; do
					if [ "$(echo ${trigger##*/})" == "$(echo ${action##*/})" ]
					then 
						for pid in /etc/threshold/pids/*; do
							if [ "$(echo ${trigger##*/})" == "$(echo ${pid##*/})" ]
							then
								echo ""
								PIDOUTPUT="$(cat $pid)"
								TRIGGEROUTPUT="$(cat $trigger)"
								ACTIONOUTPUT="$(head -1 $action)"
								
								echo "Job: ${PIDOUTPUT}"
								echo "Trigger: ${TRIGGEROUTPUT}"
								echo "Action: ${ACTIONOUTPUT}"
							fi
						done
					fi
				done
			done
		else
			echo "You have no pending trigger/action jobs"
			exit
		fi
	
	fi

	
	    # Get the command that user wants to execute if trigger is breached, and set it to execute as background job
	if [ -n "$COMMAND" ]
	then
		if [ -n "$HOSTIP" ]
		then
			USERCOMMAND="/etc/threshold/actions/${SEQUENCE}"
			echo "${COMMAND}" >> ${USERCOMMAND}
			echo "rm -f /etc/threshold/pids/${SEQUENCE}" >> ${USERCOMMAND}
			echo "rm -f /etc/threshold/triggers/${SEQUENCE}" >> ${USERCOMMAND}
			echo "rm -- \$0" >> ${USERCOMMAND}
			
			# Run the trigger in a loop as a background job
			if [[ $HOSTIP =~ [h,H][t,T][t,T][p,P]+ ]]
			then
				if [ $TIMEOUT -eq 1 ]
				  then
					  TIMEOUT=60
			    fi
				echo "Download ${HOSTIP}. If transfer takes longer than ${TIMEOUT} sec, trigger action." > /etc/threshold/triggers/${SEQUENCE}
				curl_loop() {
						curl -o /dev/null -s -k ${HOSTIP} &
						PID=$!
						echo $PID > /etc/threshold/curlpids/${SEQUENCE}
						EXIST=$(cat /etc/threshold/curlpids/${SEQUENCE})			
						TIME=0
						while true; do
							   sleep 1
							  ((TIME++))
							   if [ $TIME -gt $TIMEOUT ]
							   then
									if [ "$(ps -p ${EXIST} | tail -1 | awk '{print $1}')" == "${EXIST}" ]
									then
									   nohup sh ${USERCOMMAND} > /dev/null 2>&1 &
									   kill -9 ${EXIST}
									   rm -f /etc/threshold/curlpids/${SEQUENCE}
									   break
									fi
								elif [ "$(ps -p ${EXIST} | tail -1 | awk '{print $1}')" != "${EXIST}" ]
								then
									rm -f /etc/threshold/curlpids/${SEQUENCE}
									sleep ${BACK}
									curl_loop
									break
								fi
							done &
							PID=$! 
							echo $PID > /etc/threshold/pids/${SEQUENCE}	
					}
					curl_loop
						
			elif [ $PORT -eq 0 ]
			then
				echo "Ping $HOSTIP every $INTERVAL second(s). If $COUNT consecutive pings fail, trigger action." > /etc/threshold/triggers/${SEQUENCE}
				while true; do
					ping -c $COUNT -i $INTERVAL -W $TIMEOUT $HOSTIP > /dev/null 2>&1
					result=$?
					if [ $result -ne 0 ]
					then 
						nohup sh ${USERCOMMAND} > /dev/null 2>&1 &
						break
					fi
				done &
				PID=$!
				echo $PID > /etc/threshold/pids/${SEQUENCE}
			else
				echo "TCP handshake with ${HOSTIP}:${PORT} every $INTERVAL seconds. If $COUNT consecutive handshake(s) fail, trigger action'" > /etc/threshold/triggers/${SEQUENCE}
				while true; do
					i=0
					while [ $i -lt $COUNT ]; do
						nc -w $TIMEOUT $HOSTIP $PORT > /dev/null 2>&1
						result=$?
						if [ $result -ne 0 ]
						then 
							i=$((i+1))
							sleep $INTERVAL
						else
							i=0
							sleep $INTERVAL
						fi
					done	
					nohup sh ${USERCOMMAND} > /dev/null 2>&1 &
					break
				done &
				PID=$!
				echo $PID > /etc/threshold/pids/${SEQUENCE}
			fi
		else 
			echo "you must specify a destination (-d) target IP or hostname to create a trigger"
			echo "see \"man threshold\" for usage details"
		fi
			
	fi
fi
