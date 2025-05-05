rm -rvf /app/edaweb/edaweb.conf/
ln -s /app/edaweb.conf /app/edaweb/edaweb.conf
printenv | grep -v "no_proxy" >> /etc/environment
tmux new-session -d -s "cron" 'cron -f || bash && bash';
python3 /app/edaweb/app.py --production
