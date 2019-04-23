#! /usr/bin/env python

import os
import sys

VERSION="threshold v3.1"

# if user is checking version
try:
    if sys.argv[1] in ('-v', '--version'):
        print(VERSION)
        sys.exit()
except IndexError:
    pass

# Check if user is sudo
if os.getuid() != 0:
    print('\nPermission ERROR: You must run this tool as a superuser\n' )
    sys.exit()

import re
import signal
import shutil
import sqlite3
import subprocess
import time
import threading
import logging
import getpass
from datetime import datetime


PORT=0
TIMEOUT=1
INTERVAL=5
BACKOFF=60
COUNT=3
LATENCY = 500
KILL=False
LIST=False
PERSIST=False
UNINSTALL=False
VERS=False
IPV6=False
LOGGING='/var/log/threshold.log'


# Verify that at least one argument is used with tool
if len(sys.argv) == 1:
    print('{}: You must specify at least one argument when using this tool:\n\n'
          '\t-d|--destination\n'
		  '\t-t|--timeout\n'
		  '\t-i|--interval\n'
		  '\t-c|--count\n'
		  '\t-a|--action\n'
		  '\t-P|--port\n'
		  '\t-k|--kill\n'
		  '\t-b|--backoff\n'
		  '\t-p|--persist\n'
		  '\t-l|--list\n'
		  '\t-u|--uninstall\n'
		  '\t-6|--ipv6\n'
          '\t-L|--latency\n'
          '\t-o|--logging\n'
          '\t-v|--version\n\n'
          'USAGE SYNTAX\n'
          'sudo threshold [MONITOR OPTIONS] -a "[ACTION TO TAKE]"\n\n'
          'Check out \'man threshold\' for more info' .format (sys.argv[0]))
    sys.exit()



else:
    # Create one dict and one list. The one dict is of flags that require user parameters, the other list is of binary flags
    parameter_flags = {}
    binary_flags = []
    for flag in sys.argv[1::]:
        # Flags requiring user-provided parameters
        accepted_flags = ['-L', '--latency','-d', '--destination','-t','--timeout', '-i','--interval', '-c','--count','-a', '--action','-P', '--port', '-o','--logging','-b', '--backoff'] 
        # Binary Flags
        next_accepted_flags = ['-p', '--persist', '-l', '--list', '-u', '--uninstall', '-6', '--ipv6']

        if flag in accepted_flags:
            try:
                if sys.argv[sys.argv.index(flag) + 1] not in accepted_flags + next_accepted_flags + ['-k', '--kill']:
                    parameter_flags[flag] = sys.argv[sys.argv.index(flag) + 1]
            except:
                print('ERROR: Not all parameters were provided. See \'man threshold\' for assistance.')
                sys.exit()

        # could take optional parameter as well as be binary
        elif flag in ['-k', '--kill']:
            try:
                if re.match(r'\d{2,8}', sys.argv[sys.argv.index(flag) + 1]):
                    KILL = sys.argv[sys.argv.index(flag) + 1]
                else:
                    KILL = 'killall'
            except:
                KILL = 'killall'

        
        elif flag in next_accepted_flags:
            binary_flags.append(flag)


    for flag in parameter_flags:
        if flag in ('-d', '--destination'):
            HOSTIP = parameter_flags[flag]

        elif flag in ('-t','--timeout'):
            TIMEOUT = int(parameter_flags[flag])

        elif flag in ('-i','--interval'):
            INTERVAL = int(parameter_flags[flag])
            
        elif flag in ('-c','--count'):
            COUNT = int(parameter_flags[flag])

        elif flag in ('-a', '--action'):
            ACTION = parameter_flags[flag]
        
        elif flag in ('-P', '--port'):
            PORT = int(parameter_flags[flag])
        
        elif flag in ('-b', '--backoff'):
            BACKOFF = int(parameter_flags[flag])

        elif flag in ('-L', '--latency'):
            LATENCY = int(parameter_flags[flag])

        elif flag in ('-o', '--logging'):
            LOGGING = parameter_flags[flag]

    
    for flag in binary_flags:
        if flag in ('-p', '--persist'):
            PERSIST = True
        
        elif flag in ('-l', '--list'):
            LIST = True
        
        elif flag in ('-u', '--uninstall'):
            UNINSTALL = True
        
        elif flag in ('-6', '--ipv6'):
            IPV6 = True


# Setup DB
username = getpass.getuser()
conn = sqlite3.connect('.threshold.db')
c = conn.cursor()


def close_things():
    conn.commit()
    conn.close()      
    sys.exit()


c.execute('''CREATE TABLE IF NOT EXISTS jobs
            (pid integer, monitor text, criteria text, action text, persistent text, time text, logging text)''')

def killall():
    c.execute('SELECT pid,logging FROM jobs')
    pids = c.fetchall()
    
    if pids:
        print("\nKilling All jobs...")
        for pid in pids:
            # Set up logging
            LOGGING = pid[1]
            logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', filename=LOGGING,level=logging.DEBUG)
            try:
                c.execute('DELETE FROM jobs WHERE pid=?', (pid[0],))
                os.kill(pid[0], signal.SIGTERM)
                logging.info('User killed threshold job: ' + str(pid[0]))
            except:
                pass
    else:
        print("\nThere are no current jobs running...Exiting")


# If user wants to uninstall threshold
if UNINSTALL:
    response = raw_input("\nAre you sure you want to uninstall threshold?\n"
            "Choose Y or N.\n"
            "---------------------------------------------\n"
            "y\\N> ") or "n"

    if response.lower() == 'y':
        killall()
        try:
            os.remove('/usr/bin/threshold')
        except:
            pass
        try:
            os.remove('/usr/local/bin/threshold')
        except:
            pass
        try:
            os.remove('/usr/share/man/man1/threshold.1')
            os.remove('/usr/share/man/man1/threshold.1.gz')
        except:
            pass
        print('\nthreshold has been uninstalled...')

# If user wants to list existing jobs
elif LIST:
    c.execute('SELECT * FROM jobs')
    jobs = c.fetchall()

    if jobs:
        for j in jobs:
            print('\nJobID: {}\n'
                'Monitor Type: {}\n'
                'Failure Criteria: {}\n'
                'Action: {}\n'
                'Persistent: {}\n'
                'Monitor Running Since: {}\n'
                'Threshold Logging: {}\n'
                .format(j[0], j[1], j[2], j[3], j[4], j[5], j[6]))
    else:
        print('\nNo registered jobs.')



# If user wants to kill one or ALL jobs
elif KILL == 'killall':
    response = raw_input("\nAre you sure you want to kill ALL threshold jobs?\n"
                        "Choose Y or N.\n"
                        "---------------------------------------------\n"
                        "y\\N > ") or "n"

    if response.lower() == 'y':
        killall()

elif KILL != False:
    try:
        # Set up logging
        c.execute('SELECT logging FROM jobs WHERE pid=?', (int(KILL),))
        try:
            LOGGING = c.fetchall()[0][0]
            logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', filename=LOGGING,level=logging.DEBUG)
            c.execute('DELETE FROM jobs WHERE pid=?', (int(KILL),))
            os.kill(int(KILL), signal.SIGTERM)
            logging.info('User killed threshold job: ' + KILL)
        except IndexError:
            print('\nThere is no job id {} currently registered with threshold' .format(KILL))
    except:
        pass

# If host ip exists, assume user is setting up a monitor
elif HOSTIP:
    # Set up logging
    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', filename=LOGGING,level=logging.DEBUG)
    # current date and time
    now = datetime.utcnow()

    # fork parent process to start child threshold jobs with
    fork = os.fork()

    # If user wants to set up HTTP/S monitor
    hostip_list = HOSTIP.split('://')
    if len(hostip_list) > 1:
        # Check if user specified Ipv6
        if IPV6:
            args = 'curl -g -6 -o /dev/null -s -k "' + HOSTIP + '"'
        else:
             args = 'curl -o /dev/null -s -k ' + HOSTIP

        def http_monitor(fork_pid):
            # Check if necessary parameters have been filled out
            if TIMEOUT <= 1:
                print('\nERROR: It doesn\'t look like you specified TIMEOUT (\'-t | --timeout\') for the download monitor')
                close_things()

            # Create DB entry 
            try:
                c.execute('''INSERT INTO jobs VALUES
                            (?,?,?,?,?,?,?)''', (fork_pid, 'Loop download of ' + HOSTIP, 'Completes in > ' + str(TIMEOUT) + ' second(s)', ACTION, str(PERSIST), str(now) + ' UTC', LOGGING))
                conn.commit()
            except NameError:
                print('\nERROR: You haven\'t defined an action to take with \'-a | --action\'')
                close_things()

            failed_tcp_handshake = False

            while True:
                time.sleep(int(BACKOFF))
                # Get current time to measure delta in seconds later
                dt_start = datetime.now()
                # Start download
                p = subprocess.Popen(args, shell=True)

                while p.poll() is None:
                    time.sleep(0.1)
                    dt_now = datetime.now()
                    actual_time = abs(dt_now - dt_start).seconds

                    if actual_time <= TIMEOUT:
                        pass
                    else:
                        # Download did not finish within user-defined time. Execute defined action
                        c.execute('SELECT action FROM jobs WHERE pid=?', (fork_pid,))
                        action = c.fetchall()[0][0]

                        # execute it
                        subprocess.Popen(action, shell=True)

                        # Log action
                        logging.warning(str(fork_pid) + ' Monitor failed: ' + args)
                        logging.warning('Took action for ' + str(fork_pid) + ': ' + action)

                        # Remove previous monitor job from since it triggered
                        c.execute('DELETE FROM jobs WHERE pid=?', (fork_pid,))
                        conn.commit()
                        return failed_tcp_handshake
                    
                    if p.returncode == 0:
                        # Remove previous monitor job from since it triggered
                        c.execute('DELETE FROM jobs WHERE pid=?', (fork_pid,))
                        conn.commit()

                        # Kill existing curl test
                        os.kill(fork_pid, signal.SIGTERM)

                        return failed_tcp_handshake
                    
                else:
                    logging.error('HTTP/HTTPS Download Monitor Job (' + str(os.getpid()) + ') FAILED to due to TCP handshake failure of remote host')
                    c.execute('DELETE FROM jobs WHERE pid=?', (fork_pid,))
                    conn.commit()
                    failed_tcp_handshake = True
                    return failed_tcp_handshake

        # Run the monitor
        if not fork:
            while True:
                logging.info('HTTP/HTTPS Download Monitor Job (' + str(os.getpid()) + ') Started...')
                failed = http_monitor(os.getpid())
                if failed:
                    close_things()

                if PERSIST == False:
                    break


    # If user wants to set up a TCP handshake monitor
    elif PORT != 0:
        
        # Check if user specified Ipv6
        if IPV6:
            args = 'nc -w -6 {} {} {} >/dev/null 2>&1' .format(TIMEOUT, HOSTIP, PORT)
        else:
            # Use ipv5
            args = 'nc -w {} {} {} >/dev/null 2>&1' .format(TIMEOUT, HOSTIP, PORT)

        def tcp_monitor(fork_pid):
            # Create DB entry 
            try:
                c.execute('''INSERT INTO jobs VALUES
                            (?,?,?,?,?,?,?)''', (fork_pid, 'TCP handshake with ' + HOSTIP, 'Fails ' + str(COUNT) +' consecutive *OR* ' + str(COUNT) + ' complete with average time > ' + str(TIMEOUT) + ' second(s)', ACTION, str(PERSIST), str(now) + ' UTC', LOGGING))
                conn.commit()
            except NameError:
                print('\nERROR: You haven\'t defined an action to take with \'-a | --action\'')
                close_things()

            # Continuously loop through nc handshake until it fails
            handshake_results = []    
            while True:
                time.sleep(INTERVAL)
                p = subprocess.Popen(args, shell=True)
                while p.poll() is None:
                    time.sleep(0.1)

                handshake_results.append(p.returncode)
                if len(handshake_results) == COUNT:
                    if 0 in handshake_results:
                        pass
                    else:
                        # The monitor has alarmed, take action!!!
                        # Get action from DB
                        c.execute('SELECT action FROM jobs WHERE pid=?', (fork_pid,))
                        action = c.fetchall()[0][0]
                    
                        # execute it
                        subprocess.Popen(action, shell=True)
                        
                        # Log action
                        logging.warning(str(fork_pid) + ' Monitor failed: ' + args)
                        logging.warning('Took action for ' + str(fork_pid) + ' : ' + action)

                        # Remove previous monitor job from since it failed
                        c.execute('DELETE FROM jobs WHERE pid=?', (fork_pid,))
                        conn.commit()
                        break

        # Run the monitor
        if not fork:
            while True:
                logging.info('TCP Handshake Monitor Job (' + str(os.getpid()) + ') Started...')
                tcp_monitor(os.getpid())
                if PERSIST == False:
                    break

    # If user wants to set up a ping monitor
    else:

        # Check if user specified Ipv6
        if IPV6:
            args = 'ping6 -c {} -i {} -W {} {}' .format(COUNT, INTERVAL, TIMEOUT, HOSTIP)
        else:
            args = 'ping -c {} -i {} -W {} {}' .format(COUNT, INTERVAL, TIMEOUT, HOSTIP)

        def ping_monitor(fork_pid):
            # Create DB entry 
            try:
                c.execute('''INSERT INTO jobs VALUES
                            (?,?,?,?,?,?,?)''', (fork_pid, 'Ping ' + HOSTIP, 'Fails ' +str(COUNT) + ' consecutive *OR* ' +str(COUNT)+ ' complete with average latency > ' + str(LATENCY) + ' ms', ACTION, str(PERSIST), str(now) + ' UTC', LOGGING))
                conn.commit()
            except NameError:
                print('\nERROR: You haven\'t defined an action to take with \'-a | --action\'')
                close_things()
            
            # Continuously loop through ping
            while True:
                try:
                    p = subprocess.Popen(args, shell=True, stdout=subprocess.PIPE)
                    while p.poll() is None:
                        time.sleep(0.1)
                    output = p.communicate()[0].decode('utf-8')
                    m = re.search(r'\d+\.?\d*/(\d+\.?\d*)/\d+\.?\d* ms', output)
                    if m:
                        average_latency = m.group(1)
                
                    if p.returncode != 0 or float(average_latency) > float(LATENCY):
                        # The monitor has alarmed, take action!!!
                        # Get action from DB
                        c.execute('SELECT action FROM jobs WHERE pid=?', (fork_pid,))
                        action = c.fetchall()[0][0]
                    
                        # execute it
                        subprocess.Popen(action, shell=True)

                        # Log action
                        logging.warning(str(fork_pid) + ' Ping Latency Monitor failed (avg latency ' + str(average_latency) + ' ms): ' + args)
                        logging.warning('Took action for ' + str(fork_pid) + ' : ' + action)

                        # Remove previous monitor job from since it failed
                        c.execute('DELETE FROM jobs WHERE pid=?', (fork_pid,))
                        conn.commit()
                        break
                except:
                    c.execute('SELECT action FROM jobs WHERE pid=?', (fork_pid,))
                    action = c.fetchall()[0][0]
                
                    # execute it
                    subprocess.Popen(action, shell=True)

                    # Log action
                    logging.warning(str(fork_pid) + ' Ping Monitor failed: ' + args)
                    logging.warning('Took action for ' + str(fork_pid) + ' : ' + action)

                    # Remove previous monitor job from since it failed
                    c.execute('DELETE FROM jobs WHERE pid=?', (fork_pid,))
                    conn.commit()
                    break

        # Run the monitor
        if not fork:
            while True:
                logging.info('Ping Monitor Job (' + str(os.getpid()) + ') Started...')
                ping_monitor(os.getpid())
                if PERSIST == False:
                    break       
            
close_things()