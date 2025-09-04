#!/bin/bash
# user_data.sh - Single Node Setup

set -e

# System Updates
apt-get update
apt-get install -y unzip curl

# SSM Agent installieren (falls nicht vorhanden)
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Install Docker (für Nomad Jobs)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu
usermod -aG docker ssm-user

# HashiCorp Tools installieren
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y consul vault nomad

# Instance Info
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Consul Config (Single Node für Demo!)
mkdir -p /opt/consul/data /etc/consul.d
cat > /etc/consul.d/consul.hcl << EOF
datacenter = "${aws_region}"
data_dir = "/opt/consul/data"
server = true
bootstrap_expect = 1
node_name = "consul-demo"
bind_addr = "$LOCAL_IP"
client_addr = "0.0.0.0"
ui_config {
  enabled = true
}
EOF

# Vault Config (einfach!)
mkdir -p /opt/vault/data /etc/vault.d
cat > /etc/vault.d/vault.hcl << EOF
storage "file" {
  path = "/opt/vault/data"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}
api_addr = "http://$LOCAL_IP:8200"
ui = true
EOF

# Nomad Config (Single Node!)
mkdir -p /opt/nomad/data /etc/nomad.d
cat > /etc/nomad.d/nomad.hcl << EOF
datacenter = "${aws_region}"
data_dir = "/opt/nomad/data"
name = "nomad-demo"
server {
  enabled = true
  bootstrap_expect = 1
}
client {
  enabled = true
}
EOF

# Services starten
systemctl enable consul && systemctl start consul
sleep 10
systemctl enable vault && systemctl start vault
sleep 10
systemctl enable nomad && systemctl start nomad

# SSM Agent Status prüfen
systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service

echo "Setup complete - SSM Agent ready!"