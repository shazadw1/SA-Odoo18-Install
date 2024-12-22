#!/bin/bash

# Variables
ODOO_USER="odoo18"
ODOO_HOME="/opt/$ODOO_USER"
ODOO_CONFIG="/etc/${ODOO_USER}.conf"
ODOO_SERVICE="/etc/systemd/system/${ODOO_USER}.service"
POSTGRES_USER="odoo18"
WKHTMLTOPDF_URL="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb"

# Update and upgrade the system
echo "Updating the system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install necessary packages and libraries
echo "Installing required packages..."
sudo apt-get install -y python3-pip python3-dev libxml2-dev libxslt1-dev zlib1g-dev \
libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev \
libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev \
npm git wget

# Install Node.js and npm
echo "Installing Node.js and npm..."
sudo apt-get install -y nodejs npm
sudo ln -s /usr/bin/nodejs /usr/bin/node

# Install Less and Less Plugin Clean CSS
echo "Installing Less and Less Plugin Clean CSS..."
sudo npm install -g less less-plugin-clean-css

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt-get install -y postgresql
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create PostgreSQL user
echo "Creating PostgreSQL user..."
sudo su - postgres -c "createuser --createdb --username postgres --no-createrole --superuser $POSTGRES_USER"

# Create system user for Odoo
echo "Creating system user for Odoo..."
sudo adduser --system --home=$ODOO_HOME --group $ODOO_USER

# Switch to Odoo user and clone Odoo 18 from GitHub
echo "Cloning Odoo 18 from GitHub..."
sudo -H -u $ODOO_USER bash -c "git clone --depth 1 --branch 18.0 https://www.github.com/odoo/odoo $ODOO_HOME/odoo"

# Create and activate virtual environment
echo "Setting up virtual environment..."
sudo -H -u $ODOO_USER bash -c "python3 -m venv $ODOO_HOME/venv"
sudo -H -u $ODOO_USER bash -c "$ODOO_HOME/venv/bin/pip install wheel"
sudo -H -u $ODOO_USER bash -c "$ODOO_HOME/venv/bin/pip install -r $ODOO_HOME/odoo/requirements.txt"

# Install wkhtmltopdf
echo "Installing wkhtmltopdf..."
wget $WKHTMLTOPDF_URL
sudo dpkg -i $(basename $WKHTMLTOPDF_URL)
sudo apt-get install -f -y
rm $(basename $WKHTMLTOPDF_URL)

# Create Odoo configuration file
echo "Creating Odoo configuration file..."
sudo cp $ODOO_HOME/odoo/debian/odoo.conf $ODOO_CONFIG
sudo chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG
sudo chmod 640 $ODOO_CONFIG
sudo sed -i "s/^; admin_passwd.*/admin_passwd = admin/" $ODOO_CONFIG
sudo sed -i "s/^; db_host.*/db_host = False/" $ODOO_CONFIG
sudo sed -i "s/^; db_port.*/db_port = False/" $ODOO_CONFIG
sudo sed -i "s/^; db_user.*/db_user = $POSTGRES_USER/" $ODOO_CONFIG
sudo sed -i "s/^; db_password.*/db_password = False/" $ODOO_CONFIG
sudo sed -i "s|^; addons_path.*|addons_path = $ODOO_HOME/odoo/addons|" $ODOO_CONFIG
sudo sed -i "s|^; logfile.*|logfile = /var/log/odoo/odoo.log|" $ODOO_CONFIG

# Create log directory
echo "Creating log directory..."
sudo mkdir -p /var/log/odoo
sudo chown $ODOO_USER:$ODOO_USER /var/log/odoo

# Create systemd service file
echo "Creating systemd service file..."
sudo bash -c "cat > $ODOO_SERVICE" <<EOF
[Unit]
Description=Odoo18
Documentation=http://www.odoo.com
[Service]
# Ubuntu/Debian convention:
Type=simple
User=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python $ODOO_HOME/odoo/odoo-bin -c $ODOO_CONFIG
[Install]
WantedBy=default.target
EOF

# Set permissions for service file
sudo chmod 755 $ODOO_SERVICE
sudo chown root: $ODOO_SERVICE

# Start and enable Odoo service
echo "Starting and enabling Odoo service..."
sudo systemctl daemon-reload
sudo systemctl start $ODOO_USER
sudo systemctl enable $ODOO_USER

echo "Odoo 18 installation completed successfully!"
