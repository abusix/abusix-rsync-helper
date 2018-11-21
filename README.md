## Abusix rsync Helper ##
A shell script that downloads the latest Abusix Mail Intelligence zone files checks them against md5 sums and puts them into the right folder.<br/>
This script requires a valid username and password to access the zone files. If you do not have a username or password yet, please reach out to sales@abusix.com or use our free online query service available at https://abusix.ai. 
## Usage ##
Place the script somewhere on your server.

<pre>
# find a nice home
cd /usr/local/bin/

# download the file
wget https://gitlab.com/abusix-public/abusix-rsync-helper/raw/master/getabusix.sh

# make it executable
chmod +x getabusix.sh

# open file and configure USERNAME and USERPASS and optionally more.
vim getabusix.sh

# set it loose
sudo ./getabusix.sh

</pre>

## Frequent Updating ##
In order for the zones to automatically, you'll need to setup a cron job with crontab.
<pre>
# fire up the crontab (no sudo)
crontab -e

# run the script every minute
* * * * * /usr/local/bin/getabusix.sh
</pre>

