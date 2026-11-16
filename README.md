# Abusix rsync Helper

`getabusix.sh` is a shell script that downloads the Abusix Mail Intelligence zone files over rsync, so that a local DNS server such as rbldnsd can serve them.

The script needs a username and password to access the zone files. If you do not have a username or password yet, please reach out to sales@abusix.com or use our free online query service available at https://abusix.ai.

## How it works

Each run:

1. Reads `getabusix.conf` from `/etc`, then `/usr/local/etc`, then the script's own directory, and stops at the first one it finds.
2. Creates `DESTPATH/.lock` containing its process ID, so two runs never overlap. If the lock exists and its process is still running, the script exits. If that process is gone, for example after a crash or reboot, the stale lock is removed and the run continues. A lock file without a process ID comes from an older version of the script and is never removed automatically, so delete it by hand if no other run is active.
3. Waits a random 1 to 20 seconds to spread the load on the rsync servers (skipped with `--debug`).
4. Mirrors the `lists` rsync module from `RSYNCPOOL` into `DESTPATH`, and the `beta-lists` module into `BETA_DESTPATH` when that is set. Files are written to a temporary directory first and moved into place together, so rbldnsd never reads a half-written zone. A failed download is retried three times.
5. Logs a notice if the `SCRIPT_VERSION` file in the downloaded data names a newer version than the script's own (`VERSION=2`).
6. Removes the lock file, also when it is interrupted or a download fails for good.

**IMPORTANT** Make sure that `DESTPATH` only contains Abusix zone files. The directory is mirrored, so any file or directory that is not on our rsync server is removed. The same applies to `BETA_DESTPATH`.

## Installation

```sh
# download the files
wget https://raw.githubusercontent.com/abusix/abusix-rsync-helper/master/getabusix.sh
wget https://raw.githubusercontent.com/abusix/abusix-rsync-helper/master/getabusix.conf

# move the files into place
mv getabusix.conf /etc
mv getabusix.sh /usr/local/bin

# edit the configuration file and set USERNAME, USERPASS and DESTPATH
vi /etc/getabusix.conf

# make the script executable
chmod +x /usr/local/bin/getabusix.sh

# do an initial run and check for errors
/usr/local/bin/getabusix.sh --debug
```

## Scheduled updates

To keep the zones up to date, run the script from cron:

```sh
# open root's crontab
sudo crontab -e

# run the script every minute
* * * * * /usr/local/bin/getabusix.sh
```

## Configuration

All settings live in `getabusix.conf`, which is sourced as a shell file.

| Variable | Required | Purpose |
|---|---|---|
| `USERNAME` | yes | rsync username provided by Abusix |
| `USERPASS` | yes | rsync password provided by Abusix |
| `DESTPATH` | yes | Directory the zone files are mirrored into; created if missing. Default in the shipped file: `/var/lib/rbldnsd/abusix` |
| `BETA_DESTPATH` | no | Directory for the beta zone files; must differ from `DESTPATH` |
| `LOGFILE` | no | Path of a log file, or `logger` (syslog) or `stdout`. Without it the script logs to syslog when `logger` is installed, otherwise to stdout |
| `RSYNCPOOL` | no | rsync server pool. Default `rsync.abusix.zone`, which uses geo-location to pick the closest servers; `rsync-na.abusix.zone` (North America) and `rsync-eu.abusix.zone` (Europe) select a region |

## Upgrading from version 1 of this script

Copy `getabusix.conf` to `/etc` or `/usr/local/etc`, then copy the `USERNAME`, `USERPASS` and `DESTPATH` settings from the existing `getabusix.sh` into it. Overwrite the existing `getabusix.sh` with the new script, and run `getabusix.sh --debug` to make sure no errors are returned.
