# threshold
A simple tool which allows you to set a ping or TCP-based monitor/threshold, and then executes a user-defined command if triggered

## Installation
\# *download the installation script from Github*<br />
`wget https://raw.githubusercontent.com/secureoptions/threshold/master/install`<br />

\# *Run the installation script*<br />
`sudo sh install`<br />

\# *Verify installation*<br />
`sudo threshold --version`<br />

## Example Syntax and Usage
You can create a monitor/threshold to ping or establish TCP handshakes with a target IP or DNS hostname in a continual loop, and then execute a given command if triggered using the following syntax:

   *threshold -ciPt -d __target__ -a "__action__"*

For example let's say you wanted to ping a target of "192.168.1.1", and create a threshold that considers 5 consecutive ping failures from that target to be a trigger event. Let's also say that you want to run a pcap when this happens:

    $sudo threshold -c 5 -d 192.168.0.1 -a "tcpdump -i eth0 -W 1 -C 10 -w my.pcap"
   
Note that the trigger action (-a) itself must be enclosed in quotes.
  

__-a | --action__<br />
   The user-defined action to take if the threshold is triggered. This can be just about any command that you can execute from the command-line.

__-c | --count__<br />
   Default is 3. The number of consective ping packets that must fail response from target before triggering action. If using with TCP handshakes (-P), it's the number of consecutive handshakes that must fail.

__-d | --destination__<br />
   The target host IP or DNS hostname that you want to monitor. If this host becomes unresponsive, then the defined action (-a) is taken

__-i | --interval__<br />
   Default is 5. The interval in seconds that you want to send out a ping packet. If used with TCP (-P) the interval in seconds that TCP handshakes will be initiated

__-k | --kill__<br />
   Use to kill either a specific trigger/action job (ie. threshold -k 3509), or kill ALL trigger/action jobs (ie. kill -k all)

__-l | --list__<br />
   List the active trigger/action jobs

__-P | --port__<br />
   The TCP port that will be used to establish TCP handshakes on. Using this flag will also cause threshold to use TCP rather than ICMP/ping. Also, successful TCP handshakes are followed by TCP FINs to close the connection when TIMEOUT (-t) expires.

__-t | --timeout__<br />
   Default is 1. The time in seconds to wait for a response back to ping or TCP SYN/ACK from target. If used with (-P) then timeout is not only the amount of time to wait for response for TCP SYN/ACK, but also the time to wait before sending FIN on successful TCP connections.

__-v | --version__<br />
   See the current version of threshold
