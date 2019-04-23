#! /bin/bash

# Installation script must be run with superuser
if [ "$(id -u)" -ne 0 ]
then 
	echo ""
	echo "Permission denied (run with 'sudo'). Installation exiting..."
	echo ""
    exit 1
fi

# Check if python 2.7 is installed
python --version > /dev/null 2>1

result=$?

if [ $result -ne 0 ]
then
    echo ""
    echo 'You must have Python 2.7 installed before running this script'
    echo ""
    exit 1
fi

# Check if local system is a Mac
sw_vers > /dev/null 2>1

result=$?
if [ $result -eq 0 ]
then
    mv threshold.py /usr/local/bin/threshold
else
    mv threshold.py /usr/bin/threshold
fi

mkdir -p /etc/threshold
mv threshold.1.man /usr/share/man/man1/threshold.1
gzip -f /usr/share/man/man1/threshold.1

echo ""
echo "Installation sucessful! You now safely remove this directory and install script"
echo ""