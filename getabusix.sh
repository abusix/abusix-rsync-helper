#!/bin/sh
#
# Abusix Mail Intelligence
# Copyright 2019, Abusix Inc.
#
#################################################################
#  Please do not modify anything in this file.
#################################################################

VERSION=2

LOGGER=$(which logger)

if [ "$1" = "--debug" ]; then
    DEBUG=true
fi

cleanup() {
    rm "$DESTPATH/.lock"
    log "Script interrupted."
    exit 1
}

# RSYNC MODULES
RSYNCMODULE="lists"
BETA_RSYNCMODULE="beta-lists"

# RSYNC ARGUMENTS
# --partial-dir along with --delete-delay and --delay-updates
# ensures that all of the files are written to the partial dir
# first and then moved into place all at once, this is important
# to ensure that rbldnsd sees the updates all at the same time
# and does not get any partial reads.
# The --exclude directives ensure that no temporary files are
# included in the rsync and is important because it ensures the
# lockfile can be in the same directory as the zone files.
# --chmod along with --no-perms and --no-group prevents issues
# with ownership being copied from the rsync server which will
# differ as the uid/gids will be different across different OSes.
# So this ensures that the files will be owned by whatever user
# does the rsync and that files can still be read by anyone
# (including rbldnsd).
RSYNCOPTS="-azivv --partial-dir=.incomplete --delete-delay --exclude=.incomplete/ --exclude=.* --exclude=*.tmp --delay-updates --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r --no-perms --no-group"

# Look for config
if [ -f "/etc/getabusix.conf" ]; then
    CONFIG="/etc/getabusix.conf"
elif [ -f "/usr/local/etc/getabusix.conf" ]; then
    CONFIG="/usr/local/etc/getabusix.conf"
elif [ -f "$(dirname $0)/getabusix.conf" ]; then
    CONFIG="$(dirname $0)/getabusix.conf"
else
    echo "Error: config file not found!  Aborting execution..."
    exit 1
fi

. $CONFIG

# Make sure username and password are set
if [ -z "$USERNAME" ] || [ -z "$USERPASS" ]; then
    echo "Error: USERNAME and/or USERPASS not configured!  Aborting execution..."
    exit 1
fi

if [ -z "$DESTPATH" ]; then
    echo "Error: DESTPATH not configured!  Aborting execution..."
    exit 1
fi

# Set default pool
if [ -z "$RSYNCPOOL" ]; then
    RSYNCPOOL="rsync.abusix.zone"
fi

# Logfile specified by user, prevent logger
if [ -n "$LOGFILE" ]; then
    LOGGER=""
fi

# Make sure BETA_DESTPATH !== DESTPATH
if [ -n "$BETA_DESTPATH" ] && [ "$BETA_DESTPATH" = "$DESTPATH" ]; then
    echo "Error: BETA_DESTPATH cannot be the same as DESTPATH!  Aborting execution..."
    exit 1
fi

# Logging function
log() {
    if ([ -z "$LOGFILE" ] && [ -x "$LOGGER" ]) || [  "$LOGFILE" = "logger" ]; then
        LPARAM="-t getabusix.sh"
        if [ -n "$DEBUG" ]; then
            LPARAM="$LPARAM -s"
        fi
        echo "$1" | while read line
        do
            logger $LPARAM "$line"
        done
    elif [ -z "$LOGFILE" ] || [ "$LOGFILE" = "stdout" ]; then
        echo "$(date +%Y-%m-%d\ %H:%M:%S) - $1"
    else
        echo "$(date +%Y-%m-%d\ %H:%M:%S) - $1" >> $LOGFILE
    fi
}

mkdir -p "$DESTPATH"

# Check for lock.
if [ -f "$DESTPATH/.lock" ]; then
    log "Lock file found. Quiting."
    exit 1
fi

# Catch signals.
trap cleanup HUP INT TERM KILL

touch "$DESTPATH/.lock"

if [ -z "$DEBUG" ]; then
    # Add variable DELAY (Adds random number of seconds between 1 and 20 to decrease the load on the rsync server).
    DELAY=$(shuf -i 1-20 -n 1)
    log "Waiting random delay: $DELAY"
    sleep $DELAY
fi

getfiles() {
    # Get zone files.
    log "Getting files with rsync (module=$1 destpath=$2)"
    OUTPUT="$(RSYNC_PASSWORD=$USERPASS rsync $RSYNCOPTS "$USERNAME@$RSYNCPOOL::$1/" "$2")"
    EXIT=$?
    log "$OUTPUT"
    return $EXIT
}

fetch_with_retry() {
    nretry=0
    gotfiles=0
    getfiles $1 $2
    gotfiles=$?
    while [ "$gotfiles" -ne 0 ] && [ "$nretry" -lt 3 ]; do
        sleep 2
        log "Download error! Retrying... "
        getfiles $1 $2
        gotfiles=$?
        nretry=$(expr $nretry + 1)
        log "Retries: $nretry"
        if [ "$nretry" -eq 3 ]; then
            log "Unsuccessful download! Giving up.. "
            exit 1
        fi
    done
}

fetch_with_retry "$RSYNCMODULE" "$DESTPATH"

# Beta
if [ -n "$BETA_DESTPATH" ]; then
    mkdir -p "$BETA_DESTPATH"
    fetch_with_retry "$BETA_RSYNCMODULE" "$BETA_DESTPATH"
fi

# Check for new version of this script
if [ -e "$DESTPATH/SCRIPT_VERSION" ]; then
    REMOTE_VERSION=$(cat "$DESTPATH/SCRIPT_VERSION")
    # Convert to integer
    REMOTE_VERSION=$(expr $REMOTE_VERSION + 0)
    if [ $REMOTE_VERSION -gt $VERSION ]; then
        log "IMPORTANT: a new version of this script is available for download"
        log "This version: $VERSION < $REMOTE_VERSION"
    fi
fi

rm "$DESTPATH/.lock"
log "Finished Abusix Zone files download."
exit 0
