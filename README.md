## Abusix rsync Helper ##
A shell script that downloads the latest Abusix Mail Intelignece Zone Files, checks them against md5 sums and puts them into the right folder. This script requires a valid username and password to access the Zonefiles. If you do not have a username or password yet, please reach out to sales@abusix.com or use our free online query service. Further informtion can be found under https://abusix.com and https://abusix.ai.

## Usage ##
Place the script somewhere on your server.

<pre>
# find a nice home
cd /home/YOUR-USERNAME/bin/

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
In order for the zones to automatically update evey 2 minutes, you'll need to setup a cron job with crontab.
<pre>
# fire up the crontab (no sudo)
crontab -e

# run the script every 2 minutes
2 * * * * /home/YOUR-USERNAME/bin/getabusix.sh
</pre>

## Further Information ##
Abusix Mail Intelligence Docs:
Abusix Mail Intelligence Product Information:
Abusix Mail Intelligence Support:

