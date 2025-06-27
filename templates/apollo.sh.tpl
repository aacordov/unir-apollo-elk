#!/bin/bash
set -e

ELASTIC_SERVER_IP="${elk_ip}"
LOG_FILE="/var/log/apollo-setup.log"
APP_DIR="/opt/apollo-app"
SERVICE_USER="apollo"


#################
# Apollo Server #
#################

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Apollo Server setup"

apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget gnupg2 software-properties-common

log "Installing Node.js 18"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

log "Creating service user"
useradd -r -s /bin/false $SERVICE_USER || true

log "Creating application directory"
mkdir -p $APP_DIR
cd $APP_DIR

log "Initializing Apollo GraphQL application"
cat > package.json << 'EOF'
{
  "name": "apollo-monitoring-demo",
  "version": "1.0.0",
  "description": "Apollo GraphQL Server with Elastic APM monitoring",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "apollo-server-express": "^3.12.0",
    "express": "^4.18.2",
    "graphql": "^16.6.0",
    "elastic-apm-node": "^3.46.0"
  }
}
EOF

log "Installing npm dependencies"
npm install

log "Creating Apollo GraphQL server"

cat > index.js << 'ENDJS'
const apm = require('elastic-apm-node').start({
  serviceName: 'apollo-graphql-server',
  secretToken: '',
  serverUrl: 'http://localhost:8200',
  environment: 'development'
});

const { ApolloServer, gql } = require('apollo-server-express');
const express = require('express');

const books = [
  { id: '1', title: 'The Awakening', author: 'Kate Chopin', year: 1899 },
  { id: '2', title: 'City of Glass', author: 'Paul Auster', year: 1985 },
  { id: '3', title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', year: 1925 }
];

const typeDefs = gql`
  type Book {
    id: ID!
    title: String!
    author: String!
    year: Int!
  }

  type Query {
    hello: String
    books: [Book]
    book(id: ID!): Book
  }

  type Mutation {
    addBook(title: String!, author: String!, year: Int!): Book
  }
`;

const resolvers = {
  Query: {
    hello: () => 'Hello from Apollo GraphQL Server!',
    books: () => books,
    book: (_, { id }) => books.find(book => book.id === id)
  },
  Mutation: {
    addBook: (_, { title, author, year }) => {
      const newBook = {
        id: String(books.length + 1),
        title,
        author,
        year
      };
      books.push(newBook);
      return newBook;
    }
  }
};

async function startServer() {
  const app = express();
  
  app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  });

  const server = new ApolloServer({ 
    typeDefs, 
    resolvers,
    introspection: true,
    playground: false,
    plugins: [
     require('apollo-server-core').ApolloServerPluginLandingPageGraphQLPlayground()
    ]
  });

  await server.start();
  server.applyMiddleware({ app, path: '/graphql' });

  app.listen(4000, '0.0.0.0', () => {
    console.log('Apollo Server ready at http://localhost:4000/graphql');
  });
}
startServer();
ENDJS

sed -i "s/ELASTIC_IP_PLACEHOLDER/$$ELASTIC_SERVER_IP/g" index.js

log "Creating systemd service"
cat > /etc/systemd/system/apollo-server.service << EOF
[Unit]
Description=Apollo GraphQL Server
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR

##################
# INSTALL BEATS #
#################

log "Installing Beats"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list
apt-get update
apt-get install -y metricbeat filebeat

cat > /etc/metricbeat/metricbeat.yml << EOF
# ============================== Metricbeat ==============================

# Configuración básica
name: metricbeat
tags: ["infraestructura", "metricas"]

# =========================== Inputs (Módulos) ===========================

metricbeat.modules:
  - module: system
    period: 10s
    metricsets:
      - cpu            # Uso de CPU
      - memory         # Uso de RAM
      - network        # Interfaces de red
      - network_summary
      - diskio         # Uso de disco (E/S)
      - filesystem     # Espacio usado
      - fsstat         # Estadísticas de sistema de archivos

# =========================== Outputs ===========================

# Elasticsearch (cambiar si usas Logstash)
output.elasticsearch:
  hosts: ["http://$${ELASTIC_SERVER_IP}:9200"]
  username: "elastic"         # <--- Reemplaza con el usuario real
  password: "changeme"   # <--- Reemplaza con la contraseña real

# =========================== Kibana ===========================

setup.kibana:
  host: "http://$${ELASTIC_SERVER_IP}:5601"

# ====================== Dashboards y plantillas ======================

setup.dashboards.enabled: true
setup.template.settings:
  index.number_of_shards: 1

# ====================== Logging ======================

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/metricbeat
  name: metricbeat
  keepfiles: 7
  permissions: 0644
EOF

cat > /etc/filebeat/filebeat.yml << EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/apollo-setup.log
    - /var/log/syslog

output.elasticsearch:
  hosts: ["http://$${ELASTIC_SERVER_IP}:9200"]
  username: "elastic"
  password: "changeme"

setup.kibana:
  host: "http://$${ELASTIC_SERVER_IP}:5601"
EOF

systemctl daemon-reload
systemctl enable apollo-server metricbeat filebeat
systemctl start metricbeat filebeat
sleep 5
systemctl start apollo-server

log "Setup completed"

##############
# APM Server #
##############
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/elastic.gpg
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt update
sudo apt install apm-server
sudo systemctl enable apm-server
sudo systemctl restart apm-server
#sudo systemctl status apm-server
#sudo mv /etc/apm-server/apm-server.yml /etc/apm-server/apm-server.yml.backup
#sudo cp -f /vagrant/apm-server.yml /etc/apm-server/apm-server.yml

cat<<EOF >/etc/apm-server/apm-server.yml
apm-server:
  host: "0.0.0.0:8200"
output.elasticsearch:
  hosts: ["$${ELASTIC_SERVER_IP}:9200"]
  username: elastic
  password: changeme
setup.kibana:
  host: "http://$${ELASTIC_SERVER_IP}:5601"
EOF

sudo systemctl restart apm-server