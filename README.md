## Abusix rsync Helper ##
A shell script that downloads the latest Abusix Mail Intelligence zone files.

This script requires a valid username and password to access the zone files. If you do not have a username or password yet, please reach out to sales@abusix.com or use our free online query service available at https://abusix.ai. 

## Upgrading from the previous version of this script ##

Copy `getabusix.conf` to either `/etc` or `/usr/local/etc` and then copy the `USERNAME` `USERPASS` and `DESTPATH` settings from the existing `getabusix.sh` script into this file.

**IMPORTANT** Make sure that the `DESTPATH` only contains Abusix zone files because any files or directories not present on our rsync server will be automatically removed as the directory is mirrored, so any other files should be moved and your configuration altered as necessary.

Overwrite the existing `getabusix.sh` script with the new script.

Run `getabusix.sh --debug` to force a run and make sure no errors are returned.

## Installation ##

<pre>
# download the files
wget https://gitlab.com/abusix-public/abusix-rsync-helper/raw/master/getabusix.sh
wget https://gitlab.com/abusix-public/abusix-rsync-helper/raw/master/getabusix.conf

# move the files into place
mv getabusix.conf /etc
mv getabusix.sh /usr/local/bin

# edit the configuration files and set USERNAME, USERPASS and DESTPATH variables
vi /etc/getabusix.conf

# make the script executable
chmod +x /usr/local/bin/getabusix.sh

# do initial run and check for errors
/usr/local/bin/getabusix.sh --debug
</pre>

## Frequent Updating ##
In order for the zones to automatically, you'll need to setup a cron job with crontab.
<pre>
# fire up the crontab
sudo crontab -e

# run the script every minute
* * * * * /usr/local/bin/getabusix.sh
</pre>
