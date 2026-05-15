#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# CryptoAdv — Script de déploiement EC2 (Ubuntu)
# Usage : chmod +x deploy.sh && sudo ./deploy.sh
# ─────────────────────────────────────────────────────────────────────────────
set -e

DB_NAME="cryptoadv"
DB_USER="cryptoadv_user"
DB_PASS="CryptoAdv2024!"   # ← Change ce mot de passe

echo "════════════════════════════════════════"
echo "  CryptoAdv — Déploiement EC2"
echo "════════════════════════════════════════"

# ── 1. Mise à jour système ────────────────────────────────────────────────────
echo "[1/6] Mise à jour des paquets..."
apt-get update -qq

# ── 2. Node.js 20 ─────────────────────────────────────────────────────────────
if ! command -v node &> /dev/null; then
  echo "[2/6] Installation Node.js 20..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
else
  echo "[2/6] Node.js déjà installé : $(node -v)"
fi

# ── 3. PostgreSQL ─────────────────────────────────────────────────────────────
if ! command -v psql &> /dev/null; then
  echo "[3/6] Installation PostgreSQL..."
  apt-get install -y postgresql postgresql-contrib
  systemctl enable postgresql
  systemctl start postgresql
else
  echo "[3/6] PostgreSQL déjà installé"
fi

# ── 4. Créer DB + utilisateur ─────────────────────────────────────────────────
echo "[4/6] Configuration de la base de données..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_user WHERE usename='$DB_USER'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Appliquer le schéma
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo -u postgres psql -d $DB_NAME -f "$SCRIPT_DIR/setup.sql"
echo "  → Schéma appliqué ✓"

# ── 5. Dépendances Node ───────────────────────────────────────────────────────
echo "[5/6] Installation des dépendances npm..."
cd "$SCRIPT_DIR"

# Créer le fichier .env s'il n'existe pas
if [ ! -f .env ]; then
  cp .env.example .env
  # Remplacer les valeurs par défaut
  sed -i "s/change_this_to_a_long_random_string/$(openssl rand -hex 32)/" .env
  sed -i "s/change_this_password/$DB_PASS/"                               .env
  echo "  → .env créé ✓"
fi

npm install --production

# ── 6. PM2 (process manager) ──────────────────────────────────────────────────
echo "[6/6] Configuration PM2..."
if ! command -v pm2 &> /dev/null; then
  npm install -g pm2
fi

pm2 delete cryptoadv-server 2>/dev/null || true
pm2 start server.js --name cryptoadv-server --env production
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | bash || true

echo ""
echo "════════════════════════════════════════"
echo "  ✅ Déploiement terminé !"
echo "  REST : http://44.194.121.188:3000"
echo "  WS   : ws://44.194.121.188:3000/ws"
echo "  Test : curl http://44.194.121.188:3000/health"
echo "════════════════════════════════════════"
