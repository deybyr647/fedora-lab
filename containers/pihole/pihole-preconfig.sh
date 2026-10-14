# Install Podman

sudo dnf install -y podman podman-compose


# Free up port 53

sudo mkdir -p /etc/systemd/resolved.conf.d
sudo nano /etc/systemd/resolved.conf.d/disable-stub.conf

# [Resolve]
# DNSStubListener=no

# Restart network services
sudo systemctl daemon-reload
sudo systemctl restart systemd-resolved

# Check if port 53 is free
sudo ss -tulpn | grep :53

# Firewall Configs
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --permanent --add-service=dhcp
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload


# Make Directories
mkdir -p /home/deyby/Lab/containers/pihole/etc-pihole /home/deyby/Lab/containers/pihole/etc-dnsmasq.d

cd /home/deyby/Lab/containers/pihole
sudo podman-compose up -d

sudo podman ps
sudo podman logs pihole --tail 20



sudo nano /etc/systemd/system/pihole-compose.service
# >>
# [Unit]
# Description=Pi-hole Podman Compose Service
# After=network-online.target
# Wants=network-online.target

# [Service]
# Type=oneshot
# RemainAfterExit=yes
# WorkingDirectory=/home/deyby/Lab/containers/pihole
# ExecStart=/usr/bin/podman-compose up -d
# ExecStop=/usr/bin/podman-compose down

# [Install]
# WantedBy=multi-user.target
#
#

sudo systemctl daemon-reload
sudo systemctl enable pihole-compose.service


# Modify DNS servers in system
sudo nano /etc/resolv.conf
# nameserver 127.0.0.1
# nameserver 1.1.1.1

# Edit Network Interface to use proper DNS
sudo nmcli connection modify "Wired connection 1" ipv4.dns "127.0.0.1 1.1.1.1"
