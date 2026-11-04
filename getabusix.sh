#!/bin/sh
#
# Abusix Mail Intelligence
# Copyright 2019, Abusix Inc.
#
#################################################################
#  Please do not modify anything in this file.
#################################################################

VERSION=2

LOGGER=$(command -v logger)

if [ "$1" = "--debug" ]; then
    DEBUG=true
fi

# Set to 1 once this run owns the lock file, so that we never remove a
# lock that belongs to another run.
LOCKED=""

release_lock() {
    if [ -n "$LOCKED" ]; then
        rm -f "$DESTPATH/.lock"
        LOCKED=""
    fi
}

# Runs on HUP, INT and TERM. The EXIT trap then releases the lock.
# shellcheck disable=SC2329
on_signal() {
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
elif [ -f "$(dirname "$0")/getabusix.conf" ]; then
    CONFIG="$(dirname "$0")/getabusix.conf"
else
    echo "Error: config file not found!  Aborting execution..."
    exit 1
fi

# shellcheck source=/dev/null
. "$CONFIG"

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
    if { [ -z "$LOGFILE" ] && [ -x "$LOGGER" ]; } || [ "$LOGFILE" = "logger" ]; then
        LPARAM="-t getabusix.sh"
        if [ -n "$DEBUG" ]; then
            LPARAM="$LPARAM -s"
        fi
        echo "$1" | while read -r line
        do
            # LPARAM holds several words and must be split.
            # shellcheck disable=SC2086
            logger $LPARAM "$line"
        done
    elif [ -z "$LOGFILE" ] || [ "$LOGFILE" = "stdout" ]; then
        echo "$(date +%Y-%m-%d\ %H:%M:%S) - $1"
    else
        echo "$(date +%Y-%m-%d\ %H:%M:%S) - $1" >> "$LOGFILE"
    fi
}

mkdir -p "$DESTPATH"

# Create the lock file atomically (noclobber fails if it already exists)
# and record our process ID in it. If the file is left behind by a run
# that no longer exists, for example after a crash or a reboot, it is
# detected and removed instead of blocking all future runs.
create_lock() {
    ( set -C; echo "$$" > "$DESTPATH/.lock" ) 2>/dev/null
}

acquire_lock() {
    if create_lock; then
        LOCKED=1
        return 0
    fi

    holder=$(cat "$DESTPATH/.lock" 2>/dev/null)
    case "$holder" in
        ''|*[!0-9]*)
            # Lock files written by older versions of this script are empty.
            log "Lock file found without a process ID, probably from an older version of this script."
            log "If no other getabusix.sh is running, remove $DESTPATH/.lock. Quitting."
            return 1
            ;;
    esac

    if ps -p "$holder" > /dev/null 2>&1; then
        log "Lock file found, process $holder is still running. Quitting."
        return 1
    fi

    log "Removing stale lock file from process $holder, which is no longer running."
    rm -f "$DESTPATH/.lock"
    if create_lock; then
        LOCKED=1
        return 0
    fi
    log "Lock file found. Quitting."
    return 1
}

# Release the lock on any exit, and turn signals into a clean exit.
# KILL cannot be trapped, a lock left behind by it is handled above.
trap release_lock EXIT
trap on_signal HUP INT TERM

acquire_lock || exit 1

if [ -z "$DEBUG" ]; then
    # Add variable DELAY (Adds random number of seconds between 1 and 20 to decrease the load on the rsync server).
    # shuf is not available everywhere (for example FreeBSD), so fall back
    # to the process ID and the clock, which differ between hosts and runs.
    if command -v shuf > /dev/null 2>&1; then
        DELAY=$(shuf -i 1-20 -n 1)
    else
        DELAY=$(( ($$ + $(date +%s)) % 20 + 1 ))
    fi
    log "Waiting random delay: $DELAY"
    sleep "$DELAY"
fi

getfiles() {
    # Get zone files.
    log "Getting files with rsync (module=$1 destpath=$2)"
    # RSYNCOPTS holds several options and must be split.
    # shellcheck disable=SC2086
    OUTPUT="$(RSYNC_PASSWORD=$USERPASS rsync $RSYNCOPTS "$USERNAME@$RSYNCPOOL::$1/" "$2")"
    EXIT=$?
    log "$OUTPUT"
    return $EXIT
}

fetch_with_retry() {
    nretry=0
    gotfiles=0
    getfiles "$1" "$2"
    gotfiles=$?
    while [ "$gotfiles" -ne 0 ] && [ "$nretry" -lt 3 ]; do
        sleep 2
        log "Download error! Retrying... "
        getfiles "$1" "$2"
        gotfiles=$?
        nretry=$((nretry + 1))
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
    REMOTE_VERSION=$(tr -d '[:space:]' < "$DESTPATH/SCRIPT_VERSION")
    # Ignore anything that is not a plain integer
    case "$REMOTE_VERSION" in
        ''|*[!0-9]*) ;;
        *)
            if [ "$REMOTE_VERSION" -gt "$VERSION" ]; then
                log "IMPORTANT: a new version of this script is available for download"
                log "This version: $VERSION < $REMOTE_VERSION"
            fi
            ;;
    esac
fi

release_lock
log "Finished Abusix Zone files download."
exit 0
