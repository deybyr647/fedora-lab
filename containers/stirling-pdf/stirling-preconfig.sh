mkdir -p ./extraConfigs ./customFiles


# Firewall Setup
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# init
cd /home/deyby/Lab/containers/stirling-pdf
podman-compose up -d



#auto start config

sudo nano /etc/systemd/system/stirling-pdf-compose.service
# [Unit]
# Description=Stirling-PDF Podman Compose Service
# After=network-online.target
# Wants=network-online.target

# [Service]
# Type=oneshot
# RemainAfterExit=yes
# WorkingDirectory=/home/deyby/Lab/containers/stirling-pdf
# ExecStart=/usr/bin/podman-compose up -d
# ExecStop=/usr/bin/podman-compose down

# [Install]
# WantedBy=multi-user.target
#
#

sudo systemctl daemon-reload
sudo systemctl enable stirling-pdf-compose.service
