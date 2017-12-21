# threshold
A simple tool which allows you to set up a ping, TCP-based, or HTTP/HTTPs file transfer monitor against a network host. The monitor will execute a user-defined command if it detects failure to the host.

## Installation
\# *From Linux or Mac OS terminal download the installation script from Github*<br />
`curl -O https://raw.githubusercontent.com/secureoptions/threshold/master/install`<br />

\# *Run the installation script*<br />
`sudo sh install`<br />

\# *Verify installation*<br />
`sudo threshold --version`<br />

## Usage and Syntax
(see "man threshold" for detailed info)<br />
You can create a monitor/threshold to ping, establish TCP handshakes, or download files from with a target IP or DNS hostname in a continual loop, and then execute a given command if triggered.

For example let's say you want to set up a ping monitor against target "192.168.1.1", which triggers a packet capture (tcpdump) after 5 consecutive failures:

    sudo threshold -c 5 -d 192.168.1.1 -a "tcpdump -i eth0 -c 50000 -w my.pcap" -p
   
Note that the trigger action (-a) itself must be enclosed in quotes. Also, note that tcpdump is prevented from running forever since "-c 50000" has been set. This tells tcpdump that only 50,000 packets are to be captured before it exits the capture. It is always best to set similar limits like this with actions to keep data from filling up your hard drive (such as might happen if left running over-night).
  

__-a | --action__<br />
   The user-defined action to take if the threshold is triggered. This can be just about any command that you can execute from the command-line.

__-c | --count__<br />
   Default is 3. The number of consective pings that must fail response from target before triggering action. If using with TCP handshakes (-P), it's the number of consecutive handshakes that must fail. 

__-d | --destination__<br />
   The target host IP or DNS hostname that you want to monitor. If this host becomes unresponsive for the parameters you define, then the action (-a) is taken. __Important Note:__ if you use a prefix of http:// or https:// the monitor will attempt to download the URL page which you define in destination (ie. http://mywebsite.com/somelargefile.zip). When doing a file transfer all other arguments are ignored except for -a, -t, and -b.  You can define (-t) which tells how long in seconds a transfer has to complete before triggering an action (default is 60). (-b) can be used to define a backoff interval in seconds between downloads. This is sometimes necessary when using with webservers that subsequent throttle web requests for security.

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
   
__-b | --backoff__<br /> 
   Default is 60. Only used when specifying a http:// or https:// before target host (-d). This is the interval in seconds between consecutive download tests. It sometimes needed if a target webserver throttles consecutive web requests from the same source.

__-v | --version__<br />
   See the current version of threshold
   
__-p | --persist__<br />
    When setting this argument, your threshold jobs will remain persistent even if their monitor is breached. In that case threshold will execute the action you define, and then start itself again with same job parameters. This argument MUST be set after the action parameter, or you will receive an error. Correct syntax should be:
    threshold -d <target> -a "<my action to take>" -p
    
__-u | --uninstall__<br />
    Uninstall threshold from you system. This will also stop any current jobs you have running.
   
## Use cases and examples
__(Example: Setting a ping monitor)__ Client machines have been experiencing sporadic connection timeouts when trying to SSH into a linux server (192.168.3.10). You suspect potential packet loss or high latency somewhere in the network. For troubleshooting you choose to use MTR to check the network path when the issue occurs again (credits:https://github.com/traviscross/mtr). MTR will run from one of the impacted client's machines:

    sudo threshold -c 5 -d 192.168.3.10 -a "mtr -r -c 100 192.168.3.10 >> mtr-results.txt"
   
The above example sets a simple ping monitor against (-d) *192.168.3.10*. If the host fails to respond to 5 consecutive pings (-c), the MTR tool will execute with its own arguments (-a), etc.

__(Example: Setting a TCP handshake monitor)__ After troubleshooting some application issues, you noticed that you are getting occasional connection timeouts between your app server and database, "mydb.organization.org" (SQL/TCP 1433). You want to determine if this problem is due to a network issue or perhaps something higher up the stack. A packet capture with tcpdump may be appropriate at the next occurence of the issue (credits:http://www.tcpdump.org/):

    sudo threshold -c 6 -d mydb.organization.org -P 1433 -a "tcpdump -i eth0 host mydb.organization.org -c 1000000 -w db_capture.pcap"
    
 The above example will continually monitor TCP handshakes with *mydb.organization.org*. If this host fails to respond to 6 consecutive handshakes (-c) on TCP port 1433 (-P) then a tcpdump packet capture will run and export results to a wireshark readable file (-a). Note that setting the -P argument tells threshold to use TCP handshakes instead of pings
 
 __(Example: Setting an HTTP/HTTPS file transfer monitor)__ You noticed that when downloading content from your webserver to your workstation, it sometimes takes longer than expected. From your particular network it usually takes about 5 minutes to complete a 100MB, but lately this is less frequently the case. You decided that running an iperf3 client on your workstation to a iperf3 server on the webserver may be most appropriate to determine raw throughput capabilities of your network the next time the issue occurs (credits: https://iperf.fr/iperf-download.php)

    sudo threshold -d http://mywebserver.com/some/100MBfile.zip -t 300 -b 10 -a "iperf3 -c mywebserver.com -time 300 --logfile iperf3-results.txt"
    
The above will download a "100MBfile.zip" file from your webserver. The download must complete in 5min or 300 seconds (-t) or the iperf3 action will be taken (-a). The interval between downloads is every 10 seconds (-b). 

Also, note that threshold will know that it should use downloads as monitor rather than ping and TCP handshakes since you have prefixed the host with *http://*, telling it that it's monitoring a webserver. 

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
    
