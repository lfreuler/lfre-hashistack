# HashiCorp Stack auf bestehender EC2 Amazon Linux Instanz

Ein praktischer Guide zur Installation und Konfiguration der HashiCorp-Tools auf einer bereits laufenden Amazon Linux 2 EC2-Instanz.

## Voraussetzungen

- Laufende Amazon Linux 2 EC2-Instanz
- SSH oder SSM Session Manager Zugriff
- Internet-Verbindung (für Package-Downloads)
- Mindestens t3.medium (2 CPU, 4GB RAM)

## Überblick der Tools

- **Consul**: Service Discovery und Configuration
- **Vault**: Secrets Management
- **Nomad**: Workload Orchestration

## Phase 1: System vorbereiten

### 1.1 System Updates und Docker

```bash
# System aktualisieren
sudo yum update -y

# Docker installieren und starten
sudo amazon-linux-extras install docker -y
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user
sudo usermod -aG docker ssm-user

# Docker Test
sudo docker run hello-world
```

### 1.2 HashiCorp Repository hinzufügen

```bash
# HashiCorp GPG Key und Repository
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

# HashiCorp Tools installieren
sudo yum install -y consul vault nomad

# Installation prüfen
consul version
vault version
nomad version
```

## Phase 2: Consul einrichten

### 2.1 Consul Konfiguration

```bash
# Verzeichnisse erstellen
sudo mkdir -p /opt/consul/data /etc/consul.d

# IP-Adresse der Instanz ermitteln
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Local IP: $LOCAL_IP"

# Consul Konfiguration erstellen
sudo tee /etc/consul.d/consul.hcl << EOF
datacenter = "dc1"
data_dir = "/opt/consul/data"
server = true
bootstrap_expect = 1
node_name = "consul-demo"
bind_addr = "$LOCAL_IP"
client_addr = "0.0.0.0"
ui_config {
  enabled = true
}
log_level = "INFO"
EOF
```

### 2.2 Consul starten

```bash
# Consul Service starten
sudo systemctl enable consul
sudo systemctl start consul

# Status prüfen
sudo systemctl status consul
consul members

# UI Test (falls Port 8500 offen)
curl http://localhost:8500/v1/status/leader
```

## Phase 3: Vault einrichten

### 3.1 Vault Konfiguration

```bash
# Verzeichnisse erstellen
sudo mkdir -p /opt/vault/data /etc/vault.d

# Vault Konfiguration erstellen (HTTP für Demo)
sudo tee /etc/vault.d/vault.hcl << EOF
ui = true
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = true
}

api_addr = "http://$LOCAL_IP:8200"
EOF
```

### 3.2 Vault starten und initialisieren

```bash
# Vault Service starten
sudo systemctl enable vault
sudo systemctl start vault

# Status prüfen
sudo systemctl status vault

# Vault Umgebungsvariable setzen
export VAULT_ADDR="http://127.0.0.1:8200"

# Vault initialisieren
vault operator init -key-shares=3 -key-threshold=2

# Ausgabe speichern! Sie erhalten:
# Unseal Key 1: xxxxx
# Unseal Key 2: xxxxx  
# Unseal Key 3: xxxxx
# Initial Root Token: xxxxx
```

### 3.3 Vault entsperren

```bash
# Vault mit 2 von 3 Keys entsperren
vault operator unseal [KEY1]
vault operator unseal [KEY2]

# Root Token setzen
export VAULT_TOKEN=[ROOT_TOKEN]

# Secrets Engine aktivieren
vault secrets enable -path=secret kv-v2

# Test: Secret speichern und abrufen
vault kv put secret/demo username=testuser password=secret123
vault kv get secret/demo
```

## Phase 4: Nomad einrichten

### 4.1 Nomad Konfiguration

```bash
# Verzeichnisse erstellen
sudo mkdir -p /opt/nomad/data /etc/nomad.d

# Nomad Konfiguration erstellen
sudo tee /etc/nomad.d/nomad.hcl << EOF
datacenter = "dc1"
data_dir = "/opt/nomad/data"
name = "nomad-demo"

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true
  servers = ["127.0.0.1:4647"]
}

consul {
  address = "127.0.0.1:8500"
}

vault {
  enabled = true
  address = "http://127.0.0.1:8200"
  token   = "[VAULT_ROOT_TOKEN]"
}

plugin "docker" {
  config {
    allow_privileged = true
  }
}
EOF
```

### 4.2 Nomad starten

```bash
# Nomad Service starten
sudo systemctl enable nomad
sudo systemctl start nomad

# Status prüfen
sudo systemctl status nomad
nomad node status
nomad server members
```

## Phase 5: Erste Anwendung deployen

### 5.1 Einfache Web-Anwendung

```bash
# Nomad Job Datei erstellen
cat > webapp.nomad << EOF
job "webapp" {
  datacenters = ["dc1"]
  
  group "web" {
    count = 1
    
    network {
      mode = "host"
      port "http" {
        static = 8080
      }
    }
    
    task "web" {
      driver = "docker"
      
      config {
        image = "nginx:alpine"
        ports = ["http"]
        network_mode = "host"
      }
      
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
EOF

# Job deployen
nomad job run webapp.nomad

# Status prüfen
nomad job status webapp
```

### 5.2 Anwendung testen

```bash
# Nginx Willkommensseite abrufen
curl localhost:80

# Docker Container prüfen
sudo docker ps

# Nomad Allocation Details
nomad alloc status $(nomad job allocs webapp | grep running | awk '{print $1}')
```

## Phase 6: Vault-Integration testen

### 6.1 Credentials in Vault speichern

```bash
# Database Credentials
vault kv put secret/database \
  username=dbuser \
  password=supersecret123 \
  host=db.internal.com

# API Keys
vault kv put secret/api \
  api_key=abc123def456 \
  service_url=https://api.example.com
```

### 6.2 Nomad Job mit Vault-Secrets

```bash
# Job mit Vault-Integration erstellen
cat > vault-app.nomad << EOF
job "vault-app" {
  datacenters = ["dc1"]
  
  group "app" {
    task "app" {
      driver = "docker"
      
      config {
        image = "alpine:latest"
        command = "/bin/sh"
        args = ["-c", "echo 'Database Config:' && env | grep DB_ && echo 'API Config:' && env | grep API_ && sleep 300"]
        network_mode = "host"
      }
      
      vault {
        policies = ["default"]
      }
      
      template {
        data = <<EOH
{{ with secret "secret/data/database" }}
DB_USER={{ .Data.data.username }}
DB_PASS={{ .Data.data.password }}
DB_HOST={{ .Data.data.host }}
{{ end }}
{{ with secret "secret/data/api" }}
API_KEY={{ .Data.data.api_key }}
API_URL={{ .Data.data.service_url }}
{{ end }}
EOH
        destination = "secrets/app.env"
        env = true
      }
      
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
EOF

# Job deployen
nomad job run vault-app.nomad

# Logs prüfen um Vault-Secrets zu sehen
nomad alloc logs $(nomad job allocs vault-app | grep running | awk '{print $1}')
```

## Phase 7: Management und Überwachung

### 7.1 Web UIs nutzen

Falls die Security Groups konfiguriert sind:

- **Consul UI**: `http://[EC2-IP]:8500`
- **Vault UI**: `http://[EC2-IP]:8200`
- **Nomad UI**: `http://[EC2-IP]:4646`

### 7.2 Nützliche Kommandos

**Consul:**
```bash
# Service-Liste
consul catalog services

# Nodes anzeigen
consul catalog nodes

# Cluster-Mitglieder
consul members
```

**Vault:**
```bash
# Status
vault status

# Secrets auflisten
vault kv list secret/

# Secret Details
vault kv get secret/database
```

**Nomad:**
```bash
# Jobs anzeigen
nomad job status

# Nodes anzeigen
nomad node status

# Job skalieren
nomad job scale webapp 3

# Job stoppen
nomad job stop webapp
```

### 7.3 Logs und Debugging

```bash
# Service Logs
sudo journalctl -u consul -f
sudo journalctl -u vault -f
sudo journalctl -u nomad -f

# Nomad Job Logs
nomad alloc logs [ALLOC-ID]

# Docker Container Logs
sudo docker logs [CONTAINER-ID]
```

## Erweiterte Konfiguration

### Consul Service Discovery Test

```bash
# Service manuell registrieren
curl -X PUT http://localhost:8500/v1/agent/service/register \
  -d '{
    "name": "test-service",
    "address": "127.0.0.1",
    "port": 9999,
    "check": {
      "http": "http://127.0.0.1:9999/health",
      "interval": "10s"
    }
  }'

# Service abfragen
curl http://localhost:8500/v1/catalog/service/test-service
```

### Vault Policies erstellen

```bash
# Policy für Anwendungen
vault policy write app-policy - <<EOF
path "secret/data/database" {
  capabilities = ["read"]
}
path "secret/data/api" {
  capabilities = ["read"]
}
EOF

# Token mit Policy erstellen
vault token create -policy=app-policy
```

### Nomad Job Templates

```bash
# Parametrisierter Job
cat > template-app.nomad << EOF
job "[[.job_name]]" {
  datacenters = ["dc1"]
  
  group "app" {
    count = [[.instance_count]]
    
    task "app" {
      driver = "docker"
      
      config {
        image = "[[.docker_image]]"
        network_mode = "host"
      }
      
      env {
        APP_NAME = "[[.job_name]]"
        ENVIRONMENT = "[[.environment]]"
      }
    }
  }
}
EOF

# Job mit Variablen deployen
nomad job run -var job_name=myapp -var instance_count=2 -var docker_image=nginx:alpine -var environment=prod template-app.nomad
```

## Cleanup und Wartung

### Services stoppen

```bash
# Jobs stoppen
nomad job stop webapp
nomad job stop vault-app

# Services stoppen
sudo systemctl stop nomad
sudo systemctl stop vault
sudo systemctl stop consul

# Optional: Services deaktivieren
sudo systemctl disable nomad vault consul
```

### Daten bereinigen

```bash
# Nomad Daten löschen
sudo rm -rf /opt/nomad/data/*

# Vault Daten löschen (VORSICHT: Alle Secrets gehen verloren!)
sudo rm -rf /opt/vault/data/*

# Consul Daten löschen
sudo rm -rf /opt/consul/data/*
```

## Troubleshooting

### Häufige Probleme

1. **Services starten nicht**:
   - Logs prüfen: `sudo journalctl -u [service] -f`
   - Konfigurationsdatei validieren
   - Ports prüfen: `ss -tlnp | grep [port]`

2. **Nomad Jobs schlagen fehl**:
   - Node Status: `nomad node status -verbose`
   - Job Details: `nomad job inspect [job-name]`
   - Allocation Logs: `nomad alloc logs [alloc-id]`

3. **Vault-Integration funktioniert nicht**:
   - Vault Token in Nomad-Config prüfen
   - Vault-Policies überprüfen
   - Vault-Erreichbarkeit testen: `curl $VAULT_ADDR/v1/sys/health`

4. **Docker Permission-Probleme**:
   - User zur Docker-Gruppe hinzufügen: `sudo usermod -aG docker $USER`
   - Neu einloggen oder `newgrp docker`

### Nützliche Debug-Kommandos

```bash
# Netzwerk-Ports prüfen
ss -tlnp | grep -E '8200|8500|4646|4647'

# Prozesse prüfen
ps aux | grep -E 'consul|vault|nomad'

# Disk Space prüfen
df -h /opt/

# Memory Usage
free -h
```

Dieser Guide zeigt die komplette HashiCorp-Stack-Installation auf einer bestehenden EC2-Instanz. Alle Services laufen im Single-Node-Modus für Development und Testing.