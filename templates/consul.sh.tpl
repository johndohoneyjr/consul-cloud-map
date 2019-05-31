#!/usr/bin/env bash
set -e

echo "Grabbing IPs..."
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
cd /home/centos

echo "Installing dependencies..."
sudo yum update -y  &>/dev/null
sudo yum install -y unzip &>/dev/null
cd /home/centos

echo "Set-up User.."
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

echo "Fetching Consul..."
cd /tmp
curl -sLo consul.zip https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
curl -sLo consul-aws.zip https://releases.hashicorp.com/consul-aws/0.1.1/consul-aws_0.1.1_linux_amd64.zip

echo "Installing Consul_AWS ..."
sudo unzip consul-aws.zip >/dev/null
sudo chmod +x consul-aws
sudo chown root:root consul-aws
sudo mv consul-aws /bin/consul-aws

echo "Installing Consul..."
sudo unzip consul.zip >/dev/null
sudo chmod +x consul
sudo chown root:root consul
sudo mv consul /bin/consul
cd /home/centos

# Setup Consul
sudo mkdir -p /mnt/consul
cd /mnt
sudo chown consul:consul consul
sudo mkdir -p /etc/consul.d
sudo tee /etc/consul.d/config.json > /dev/null <<EOF
{
  "bind_addr": "$PRIVATE_IP",
  "advertise_addr": "$PRIVATE_IP",
  "advertise_addr_wan": "$PUBLIC_IP",
  "data_dir": "/mnt/consul",
  "disable_remote_exec": true,
  "disable_update_check": true,
  "leave_on_terminate": true,
  ${config}
}
EOF

mkdir -p /etc/systemd/system
sudo touch /etc/systemd/system/consul.service
sudo tee /etc/systemd/system/consul.service > /dev/null <<EOF
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/config.json

[Service]
User=consul
Group=consul
ExecStart=/bin/consul agent -ui -config-dir=/etc/consul.d/
ExecReload=/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul 
cd /home/centos
echo "Cluster leader is" `curl --silent http://127.0.0.1:8500/v1/status/leader` >> LeaderStatus.txt
echo "" >> LeaderStatus.txt
echo "$(consul operator raft list-peers)" >> LeaderStatus.txt
