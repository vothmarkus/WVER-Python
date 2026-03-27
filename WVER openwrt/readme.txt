readme:

PowerShell:

scp -O "C:\Users\vothm\Downloads\wver-openwrt\index.html" root@192.168.10.1:/tmp/index.html
scp -O "C:\Users\vothm\Downloads\wver-openwrt\wver_update.sh" root@192.168.10.1:/tmp/wver_update.sh


CMD:

ssh root@192.168.10.1
mv /tmp/index.html /www/wver/index.html
mv /tmp/wver_update.sh /root/wver_update.sh
chmod +x /root/wver_update.sh
/root/wver_update.sh


cron:

*/15 * * * * /root/wver_update.sh