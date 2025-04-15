#!/bin/bash
set -e

# Get the private IP dynamically
PRIVATE_IP=$(hostname -I | awk '{print $1}')
LOGSTASH_HOST="${PRIVATE_IP}:5044"
KIBANA_HOST="http://${PRIVATE_IP}:5601"

# Debugging and error handling
echo "Starting Elasticsearch installation..."
echo "Detected Private IP: $PRIVATE_IP"

# Update system
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y wget apt-transport-https curl

# Import Elasticsearch GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# Add Elasticsearch repository
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

# Install Elasticsearch
sudo apt update
sudo apt install elasticsearch -y 

# Modify Elasticsearch configuration
sudo tee -a /etc/elasticsearch/elasticsearch.yml << EOF

# Network settings
network.host: ["_local_", "_site_", "${PRIVATE_IP}", "127.0.0.1"]
http.port: 9200
discovery.type: single-node
EOF

# Set proper permissions
sudo chown -R elasticsearch:elasticsearch /etc/elasticsearch
sudo chmod -R 755 /etc/elasticsearch

# Configure JVM heap size (optional, adjust as needed)
sudo sed -i 's/-Xms1g/-Xms512m/' /etc/elasticsearch/jvm.options
sudo sed -i 's/-Xmx1g/-Xmx512m/' /etc/elasticsearch/jvm.options

# Restart Elasticsearch to apply changes
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch
sudo systemctl restart elasticsearch

# Wait for Elasticsearch to start
# echo "Waiting for Elasticsearch to start..."
# sleep 30

# Advanced debugging
echo "Checking Elasticsearch service status:"
# sudo systemctl status elasticsearch

# Try to curl Elasticsearch using both localhost and private IP
echo "Attempting to connect to Elasticsearch:"
curl -v http://localhost:9200
curl -v http://${PRIVATE_IP}:9200

KIBANA_TOKEN=$(sudo /usr/share/elasticsearch/bin/elasticsearch-service-tokens create elastic/kibana my-kibana-token)

# Install Kibana
sudo apt update
sudo apt install kibana -y

# Modify Kibana configuration
sudo tee /etc/kibana/kibana.yml << EOF
# Server settings
server.host: "${PRIVATE_IP}"
server.port: 5601

# Elasticsearch connection
elasticsearch.hosts: ["http://${PRIVATE_IP}:9200"]

# Enrollment token
elasticsearch.serviceAccountToken: "${KIBANA_TOKEN}"
EOF

sudo chown -R kibana:kibana /etc/kibana
sudo chmod -R 755 /etc/kibana

sudo systemctl daemon-reload
sudo systemctl enable kibana
sudo systemctl restart kibana

# Update and install Logstash
sudo apt update
sudo apt install -y logstash

# Create Apache configuration
sudo tee /etc/logstash/conf.d/apache.conf << EOF
input {
  beats {
    port => "5044"
  }
}
filter {
  grok {
    match => { "message" => "%{COMBINEDAPACHELOG}" }
  }
}
output {
  elasticsearch {
    hosts => ["http://${PRIVATE_IP}:9200"]
    index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
  }
  stdout {
    codec => rubydebug
  }
}
EOF

# Start and check Logstash
sudo systemctl start logstash
sudo systemctl enable logstash

echo "Logstash installation completed. Listening on port 5044 for Filebeat connections."


# Install Filebeat
sudo apt update
sudo apt install filebeat -y

# Create Filebeat configuration
sudo tee /etc/filebeat/filebeat.yml << EOF
filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false  # Disable dynamic reloading for simpler debugging

filebeat.inputs:
- type: system
  enabled: true
  paths:
    - /var/log/syslog
    - /var/log/auth.log

# Disable setup features that require Elasticsearch output
setup.ilm.enabled: false
setup.template.enabled: false

output.logstash:
  hosts: ["${LOGSTASH_HOST}"]
EOF

# Configure system module (without Kibana setup)
sudo tee /etc/filebeat/modules.d/system.yml << EOF
- module: system
  syslog:
    enabled: true
    var.paths: ["/var/log/syslog"]
  auth:
    enabled: true
    var.paths: ["/var/log/auth.log"]
EOF

# Set permissions
sudo chown root:root /etc/filebeat/filebeat.yml
sudo chmod 644 /etc/filebeat/filebeat.yml
sudo chown root:root /etc/filebeat/modules.d/system.yml
sudo chmod 644 /etc/filebeat/modules.d/system.yml

# Restart Filebeat
echo "Restarting Filebeat..."
sudo systemctl restart filebeat

# Verification
echo "Checking Filebeat status..."
sudo systemctl status filebeat --no-pager

echo "Tailing Filebeat logs (Ctrl+C to exit)..."
sudo tail -f /var/log/filebeat/filebeat

sudo filebeat test output
