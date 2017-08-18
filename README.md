# threshold
A simple tool which allows you to set up a ping or TCP-based monitor against a network host. The monitor will execute a user-defined command if it detects failure to the host.

## Installation
\# *From Linux or Mac OS terminal download the installation script from Github*<br />
`curl -O https://raw.githubusercontent.com/secureoptions/threshold/master/install`<br />

\# *Run the installation script*<br />
`sudo sh install`<br />

\# *Verify installation*<br />
`sudo threshold --version`<br />

## Example Syntax and Usage
(see "man threshold" for detailed info)<br />
You can create a monitor/threshold to ping or establish TCP handshakes with a target IP or DNS hostname in a continual loop, and then execute a given command if triggered using the following syntax:

   *threshold -ciPt -d __target__ -a "__action__"*

For example let's say you want to set up a ping monitor against target "192.168.1.1", which triggers a packet capture (tcpdump) after 5 consecutive failures:

    sudo threshold -c 5 -d 192.168.1.1 -a "tcpdump -i eth0 -c 50000 -w my.pcap"
   
Note that the trigger action (-a) itself must be enclosed in quotes. Also, note that tcpdump is prevented from running forever since "-c 50000" has been set. This tells tcpdump that only 50,000 packets are to be captured before it exits the capture. It is always best to set similar limits like this with actions to keep data from filling up your hard drive (such as might happen if left running over-night).
  

__-a | --action__<br />
   The user-defined action to take if the threshold is triggered. This can be just about any command that you can execute from the command-line.

__-c | --count__<br />
   Default is 3. The number of consective pings that must fail response from target before triggering action. If using with TCP handshakes (-P), it's the number of consecutive handshakes that must fail.

__-d | --destination__<br />
   The target host IP or DNS hostname that you want to monitor. If this host becomes unresponsive for the parameters you define, then the action (-a) is taken

__-i | --interval__<br />
   Default is 5. The interval in seconds that you want to send out a single ping. If used with TCP (-P) the interval in seconds that TCP handshakes will be initiated

__-k | --kill__<br />
   Use to kill either a specific trigger/action job (ie. threshold -k 3509), or kill ALL trigger/action jobs (ie. threshold -k all)

__-l | --list__<br />
   List the active trigger/action jobs

__-P | --port__<br />
   The TCP port that will be used to establish TCP handshakes on. Using this flag will also cause threshold to use TCP rather than ICMP/ping. Also, successful TCP handshakes are followed by TCP FINs to close the connection when TIMEOUT (-t) expires.

__-t | --timeout__<br />
   Default is 1. The time in seconds to wait for a response back to ping or TCP SYN/ACK from target. If used with (-P) then timeout is not only the amount of time to wait for response for TCP SYN/ACK, but also the time to wait before sending FIN on successful TCP connections.

__-v | --version__<br />
   See the current version of threshold

## Listing trigger/action jobs
You can see which thresholds you have active with the following command:<br />
    `sudo threshold -l`
    
...which may return output that looks something like this:<br />

*__Job: 1478<br />
Trigger: Ping 192.168.3.199 every 5 second(s). If 5 consecutive pings fail, trigger action.<br />
Action: my action__*<br />

## Deleting active jobs<br />
You can delete ALL active jobs or a specific job<br />

\# ALL jobs<br />
   `threshold -k all`

\# a specific job<br />
   `threshold -k 1478`
    
