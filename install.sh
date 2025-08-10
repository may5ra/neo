#!/bin/bash

# StreamPanel Pro - Namestitev brez Git
# Avtor: StreamPanel Team

echo "==========================================="
echo "  STREAMPANEL PRO - NAMESTITEV BREZ GIT    "
echo "==========================================="

# Preveri če je skripta zagnana kot root
if [[ $EUID -ne 0 ]]; then
   echo "Napaka: Ta skripta zahteva root pravice!" 
   echo "Prosimo, zaženite z: sudo ./install.sh"
   exit 1
fi

# Določi spremenljivke
INSTALL_DIR="/var/www/html/streampanel"
CONFIG_FILE="$INSTALL_DIR/config.php"
DB_NAME="streaming_panel"
DB_USER="streamuser"
DB_PASS="streampass123"
SERVER_MAC="00:1A:2B:3C:4D:5E"
LICENSE_KEY="SP-LICENSE-VALID-KEY-12345"

# Pridobi IP naslov strežnika
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "1. Nameščanje potrebnih paketov..."
apt update
apt install -y apache2 php php-mysql php-curl php-gd php-mbstring php-xml php-zip unzip curl

echo "2. Ustvarjanje direktorijev..."
mkdir -p $INSTALL_DIR
chmod 755 $INSTALL_DIR

echo "3. Prenos StreamPanel Pro (brez Git)..."
cd /tmp
rm -rf streampanel*

# Prenesi z zadnjo verzijo iz GitHub
curl -L -o streampanel.zip "https://github.com/streampanel/streampanel-pro/releases/latest/download/streampanel-pro.zip"
unzip streampanel.zip
mv streampanel-pro/* $INSTALL_DIR/
chmod -R 755 $INSTALL_DIR

echo "4. Ustvarjanje baze podatkov..."
mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

echo "5. Konfiguracija baze podatkov..."
cat > $CONFIG_FILE << EOF
<?php
// Database configuration
define('DB_HOST', 'localhost');
define('DB_USER', '$DB_USER');
define('DB_PASS', '$DB_PASS');
define('DB_NAME', '$DB_NAME');

// Server MAC address
define('SERVER_MAC', '$SERVER_MAC');

// License key
define('LICENSE_KEY', '$LICENSE_KEY');

// Path settings
define('BASE_URL', 'http://$SERVER_IP/streampanel/');
?>
EOF

echo "6. Ustvarjanje Apache virtual host..."
cat > /etc/apache2/sites-available/streampanel.conf << EOF
<VirtualHost *:80>
    ServerName $SERVER_IP
    DocumentRoot $INSTALL_DIR
    
    <Directory $INSTALL_DIR>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/streampanel_error.log
    CustomLog \${APACHE_LOG_DIR}/streampanel_access.log combined
</VirtualHost>
EOF

echo "7. Aktiviranje virtual hosta in potrebnih modulov..."
a2ensite streampanel.conf
a2enmod rewrite
systemctl reload apache2

echo "8. Nastavitev pravic..."
chown -R www-www-data $INSTALL_DIR
chmod -R 755 $INSTALL_DIR
chmod 775 $INSTALL_DIR/cache
chmod 775 $INSTALL_DIR/logs

echo "9. Ustvarjanje potrebnih datotek..."
touch $INSTALL_DIR/logs/app.log
chown www-data:www-data $INSTALL_DIR/logs/app.log

echo "10. Ustvarjanje crontab za GeoLite2 posodobitev..."
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/wget -O $INSTALL_DIR/geolite2/latest.tar.gz \"https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz\"") | crontab -

echo "==========================================="
echo "INSTALACIJA KONČANA!"
echo "==========================================="
echo ""
echo "PODATKI ZA DOSTOP:"
echo "- URL: http://$SERVER_IP/streampanel"
echo "- Administrator: admin / admin123"
echo "- Baza: $DB_NAME"
echo "- Uporabnik: $DB_USER"
echo "- Geslo: $DB_PASS"
echo "- MAC naslov: $SERVER_MAC"
echo "- Licenca: $LICENSE_KEY"
echo ""
echo "POMEMBNO: Spremenite admin geslo po prvi prijavi!"
echo "==========================================="

# Počisti začasne datoteke
rm -rf /tmp/streampanel*

echo "Začenjam spletne storitve..."
systemctl restart apache2

echo "NAMESTITEV USPEŠNA!"
echo "Obiščite http://$SERVER_IP/streampanel za dostop do panela."

# Dodatna informacija za uporabnike
echo ""
echo "==========================================="
echo "DODATNE INFORMACIJE:"
echo "==========================================="
echo "1. Za dostop do panela:"
echo "   URL: http://$SERVER_IP/streampanel"
echo "   Uporabnik: admin"
echo "   Geslo: admin123"
echo ""
echo "2. Po namestitvi:"
echo "   - Spremenite admin geslo!"
echo "   - Preverite varnostne nastavitve"
echo "   - Nastavite SSL (HTTPS) za varnost"
echo ""
echo "3. Za nadgradnjo:"
echo "   cd $INSTALL_DIR"
echo "   git pull origin main"
echo ""
echo "==========================================="
