#!/bin/bash

# Salir si hay errores
set -e

# Función para mostrar mensajes en color
function mensaje {
    echo -e "\e[1;32m$1\e[0m"
}

# Preguntar si se desea continuar con la instalación en caso de versión anterior
read -p "¿Deseas continuar la instalación si hay una versión previa del servidor de comunicación? (S/n): " CONTINUAR
CONTINUAR=${CONTINUAR:-S}
if [[ "$CONTINUAR" != "s" && "$CONTINUAR" != "S" ]]; then
    echo "Instalación cancelada por el usuario."
    exit 1
fi

# Preguntar si se desea instalación automática
read -p "¿Deseas realizar la instalación de OCS de forma automática? (S/n): " AUTO
AUTO=${AUTO:-S}

# Actualizar sistema
mensaje "🔄 Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
mensaje "📦 Instalando dependencias necesarias..."
sudo apt install -y apache2 mariadb-server \
php php-mysql php-xml php-curl php-mbstring php-zip php-soap php-intl php-gd php-json \
libapache2-mod-perl2 libapache-dbi-perl libapache-db-perl libarchive-zip-perl \
libdbd-mysql-perl libmojolicious-perl libswitch-perl libplack-perl \
make build-essential wget

# Aumentar límites de subida de PHP
mensaje "⚙️ Configurando límites de subida PHP..."
PHP_INI="/etc/php/8.1/apache2/php.ini"
sudo sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI"
sudo sed -i 's/^post_max_size = .*/post_max_size = 100M/' "$PHP_INI"

# Configurar base de datos
mensaje "🛠️ Configurando base de datos..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS ocsweb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'ocs'@'localhost' IDENTIFIED BY 'TuContraseñaSegura';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ocsweb.* TO 'ocs'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Descargar OCS Inventory
mensaje "⬇️ Descargando OCS Inventory NG 2.12.3..."
cd /tmp
wget -c https://github.com/OCSInventory-NG/OCSInventory-ocsreports/releases/download/2.12.3/OCSNG_UNIX_SERVER-2.12.3.tar.gz
tar -xvzf OCSNG_UNIX_SERVER-2.12.3.tar.gz
cd OCSNG_UNIX_SERVER-2.12.3

# Ejecutar setup.sh según modo elegido
if [[ "$AUTO" == "s" || "$AUTO" == "S" ]]; then
    mensaje "⚙️ Ejecutando la instalación automática..."
    sudo perl setup.sh <<EOF
y
/etc/apache2
/usr/bin/perl
localhost
3306
ocs
TuContraseñaSegura
ocsweb
n
n
EOF
else
    mensaje "⚙️ Ejecutando el instalador interactivo..."
    sudo perl setup.sh
fi

# Habilitar Apache y configuración
mensaje "🔧 Configurando Apache..."
sudo a2enmod rewrite

if [ ! -f /etc/apache2/conf-enabled/ocsinventory-reports.conf ]; then
    sudo ln -s /etc/apache2/conf-available/ocsinventory-reports.conf /etc/apache2/conf-enabled/
fi

# Crear y dar permisos a var lib dir
mensaje "📁 Creando /var/lib/ocsinventory-reports..."
sudo mkdir -p /var/lib/ocsinventory-reports
sudo chown -R www-data:www-data /var/lib/ocsinventory-reports
sudo chmod -R 755 /var/lib/ocsinventory-reports

# Reiniciar Apache
mensaje "♻️ Reiniciando Apache..."
sudo systemctl restart apache2

# Comprobación final
if [ ! -d /usr/share/ocsinventory-reports/ocsreports ]; then
    echo "❌ ERROR: No se encontró el directorio /usr/share/ocsinventory-reports/ocsreports"
    echo "Verifica si el instalador copió los archivos correctamente."
    exit 1
fi

mensaje "🎉 Instalación completada correctamente."
echo "👉 Accede a: http://localhost/ocsreports"
echo "🔐 Usuario por defecto: admin | Contraseña: admin"
echo "✅ PHP configurado con límite de subida ampliado."
echo "✅ Apache reiniciado correctamente."
echo ""
echo "📄 Datos para el asistente de conexión MySQL en la web:"
echo "   🔸 MySQL login:       ocs"
echo "   🔸 MySQL password:    TuContraseñaSegura"
echo "   🔸 Name of Database:  ocsweb"
echo "   🔸 MySQL HostName:    localhost"
echo "   🔸 MySQL Port:        3306"
echo "   🔸 Enable SSL:        No"
