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


	# Prepend a sequential number to each PID lock file so that we can run multiple instances if needed
	EXISTING_FILES_COUNT=$(ls -1 /etc/threshold/triggers | wc -l)
	SEQUENCE="$(($EXISTING_FILES_COUNT + 1))"
	
		# If the user wants job to run persistently we need to store the variables for later use
	if [ $PERSIST -eq 1 ]
	then
		cat << EOF > /etc/threshold/persistjobs/${SEQUENCE}
export PORT=${PORT}
export TIMEOUT=${TIMEOUT}
export INTERVAL=${INTERVAL}
export BACK=${BACK}
export COUNT=${COUNT}
export KILL=${KILL}
export LIST=${LIST}
export VERS=${VERS}
export PERSIST=${PERSIST}

EOF
		if [ -n "$HOSTIP" ]
		then
			echo "$HOSTIP" >> /etc/threshold/persistjobs/${SEQUENCE}
		fi
		if [ -n "$COMMAND" ]
		then
			echo "$COMMAND" >> /etc/threshold/persistjobs/${SEQUENCE}
		fi
		echo "sh /etc/threshold/autoscript/threshold_persist.sh" >> /etc/threshold/persistjobs/${SEQUENCE}
	fi
		
		

	
	    # Get the command that user wants to execute if trigger is breached, and set it to execute as background job
	if [ -n "$COMMAND" ]
	then
		if [ -n "$HOSTIP" ]
		then
			USERCOMMAND="/etc/threshold/actions/${SEQUENCE}"
			echo "${COMMAND}" >> ${USERCOMMAND}
			echo "sh /etc/threshold/persistjobs/${SEQUENCE}" >> ${USERCOMMAND}
			echo "rm -f /etc/threshold/pids/${SEQUENCE}" >> ${USERCOMMAND}
			echo "rm -f /etc/threshold/triggers/${SEQUENCE}" >> ${USERCOMMAND}
			echo "rm -f /etc/threshold/persistjobs/${SEQUENCE}" >> ${USERCOMMAND}
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

