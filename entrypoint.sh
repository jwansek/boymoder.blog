printenv | grep -v "no_proxy" >> /etc/environment
tmux new-session -d -s "cron" 'cron -f || bash && bash';
python3 /app/app.py --production