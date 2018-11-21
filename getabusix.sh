#!/bin/sh
#
# Abusix Mail Intelligence
# Copyright 2018, Abusix Inc.
#
#################################################################
# Please modify the variables below to suit your configuration
#################################################################

# Add your username and password here as provided by Abusix.
USERNAME=""
USERPASS=""
# Working directory path
# Please make sure it is writable by the user executing this script.
# This is used as the location where the zones are downloaded and 
# checked before they are moved into place, it will also contain
# the lockfile to prevent multiple copies of this script for running.
WORKDIR="./"
# Full destination path of where the zone files should be placed
# once they have been downloaded an verified.  This should be a
# directory that is referenced by your rbldnsd configuration.
DESTPATH="$WORKDIR/zonefiles"
# Full path to log file (Example: /var/log/abusix-rsync-$(date +%Y-%m-%d).log)
LOGFILE="$WORKDIR/abusix-rsync-$(date +%Y-%m-%d).log"
# RSYNC pool to get data from.
# rsync.abusix.zone uses geo-location to determine the closest server to you.
# rsync-na.abusix.zone is server pool in North America.
# rsync-eu.abusix.zone is server pool in Europe.
RSYNCPOOL="rsync.abusix.zone"


###### Please do not modify anyting below this line. ######
# Catch signals.
trap "rm $WORKDIR/.lock; echo 'Script interrupted.' >> $LOGFILE; exit 1" HUP INT TERM KILL

# RSYNC MODULE
RSYNCMODULE="lists"

# CHECK AND VALIDATION URL's
BLOCKURL="http://$RSYNCPOOL:8873/block.html"
CHECKURL="http://$RSYNCPOOL:8873/check.html"

RSYNCOPTS="-tlazivv --partial-dir=.incomplete --delete --exclude=.incomplete/ --exclude=*.tmp --delay-updates"

mkdir -p "$WORKDIR/.incomplete"
mkdir -p "$WORKDIR/.tmp"
mkdir -p "$DESTPATH"

echo "" >> $LOGFILE
echo "   ------  " >> $LOGFILE
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Starting Abusix Zone files download." >> $LOGFILE

if [ -f $WORKDIR/.lock ]; then
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - Lock file found. Quiting." >> $LOGFILE
    exit 1
fi

touch $WORKDIR/.lock

# Add variable DELAY (Adds random number of seconds between 1 and 20 to decrease the load on the rsync server).
DELAY=$(shuf -i 1-20 -n 1)
echo "Waiting random delay: $DELAY" >> $LOGFILE
sleep $DELAY

export RSYNC_PASSWORD=$USERPASS

res=$(wget --spider -q $BLOCKURL -O /dev/null)
status=$?
# echo $res
if [ "$status" -eq 0 ]
then
    sleep 2
    res=$(wget --spider -q $BLOCKURL -O /dev/null)
    status=$?
    echo $res
    if [ "$status" -eq 0 ]; then
        #  Write to log file.
        echo "$(date +%Y-%m-%d\ %H:%M:%S) - Update blocked! Will retry next time. Result:$res" >> $LOGFILE
        rm $WORKDIR/.lock
        exit 1
    else
        echo "No block file" >> $LOGFILE
    fi
fi

nretry=0
gotfiles=0
getfiles() {
    # Get zone files.
    echo "Getting files with rsync" >> $LOGFILE
    rsync $RSYNCOPTS $USERNAME@$RSYNCPOOL::$RSYNCMODULE/* $WORKDIR >> $LOGFILE 2>&1
    echo "Verifying files" >> $LOGFILE

    # Verify zone files.
    # Get local files md5 checksum.
    cd $WORKDIR
    md5sum *.zone > localmd5sum.txt
    # Get remote files md5 checksum.
    wget -q $CHECKURL -O remotemd5sum.txt
    # Compare checksums.
    diff localmd5sum.txt remotemd5sum.txt >/dev/null 2>&1
    return $?
}

getfiles
gotfiles=$?
while [ "$gotfiles" -ne 0 ] && [ "$nretry" -lt 3 ]; do
    sleep 2
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - Checksum mismatch! Retriying.. " >> $LOGFILE
    getfiles
    gotfiles=$?
    nretry=`expr $nretry + 1`
    echo "Retries: $nretry"
    if [ "$nretry" -eq 3 ]; then
        echo "$(date +%Y-%m-%d\ %H:%M:%S) - Checksum mismatch! Giving up.. " >> $LOGFILE
        rm $WORKDIR/.lock
        exit 1
    fi
done
echo "Files checksum Ok! Moving to destination" >> $LOGFILE
# Move to destination directory
cp $WORKDIR/*.zone $WORKDIR/.tmp/
mv $WORKDIR/.tmp/*.zone $DESTPATH
rm $WORKDIR/.lock
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Finished Abusix Zone files download." >> $LOGFILE
exit 0
