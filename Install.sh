#!/usr/bin/env bash

# check if we're root, exit if not, no use to run as non-root user
if [[ "$(id -u)" != "0" ]]; then
  clear
  echo -e "[ - ] Not root. G'bye ..."
  exit 1
fi

# check if we're on Debian
if [[ ! -r /etc/debian_version ]]; then
  clear
  echo -e "[ - ] I doubt we're on Debian. G'bye ..."
  exit 1
else
  DEBIAN_VERSION=$(cat /etc/debian_version | awk -F\. '{print $1}')
  if [[ $DEBIAN_VERSION < 8 || $DEBIAN_VERSION > 9 ]]; then
    clear
    echo -e "[ - ] I need Debian Version 8 or 9, this is Version ${DEBIAN_VERSION}. G'bye ..."
    exit 1
  fi
  CMD_APTGET=$(command -v apt-get)
fi

# we're root and on Debian, let's continue

# install dependencies
echo -e "[ + ] Installing dependencies"
$CMD_APTGET update
if [[ $DEBIAN_VERSION -eq "9" ]]; then
  $CMD_APTGET -y install net-tools
fi
$CMD_APTGET -y install apache2 sudo zip unzip wget build-essential tar libapache2-mod-wsgi libtool m4 automake apache2-dev libpcre3 libpcre3-dev libxml2-dev zlib1g-dev geoip-bin libgeoip-dev openssl

# vars
CURR_DIR=$(pwd)

CMD_MKDIR=$(command -v mkdir)
CMD_WGET=$(command -v wget)
CMD_UNZIP=$(command -v unzip)
CMD_MV=$(command -v mv)
CMD_RM=$(command -v rm)
CMD_LN=$(command -v ln)
CMD_CHMOD=$(command -v chmod)
CMD_CHOWN=$(command -v chown)
CMD_ADDUSER=$(command -v adduser)
CMD_TAR=$(command -v tar)
CMD_CRONTAB=$(command -v crontab)
CMD_OPENSSL=$(command -v openssl)
CMD_A2ENMOD=$(command -v a2enmod)
CMD_SUDO=$(command -v sudo)
CMD_TOUCH=$(command -v touch)

DIR_HOME="/home/www-data"
DIR_SUDOLECTURE="/var/lib/sudo/lectured"

# finally, let's install Waf2Py
echo "[ + ] Creating www-data home folder and download web2py framework"

$CMD_MKDIR $DIR_HOME
cd $DIR_HOME
$CMD_RM web2py_src.zip*
$CMD_WGET http://web2py.com/examples/static/web2py_src.zip
$CMD_UNZIP web2py_src.zip
$CMD_MV web2py waf2py_community
$CMD_MV $DIR_HOME/waf2py_community/handlers/wsgihandler.py $DIR_HOME/waf2py_community/wsgihandler.py
cd $CURR_DIR
$CMD_MV Waf2Py $DIR_HOME/waf2py_community/applications/
clear
echo "[ + ] Creating  ssl folder and deleting enabled default sites of apache"

$CMD_RM /etc/apache2/sites-enabled/*.conf
$CMD_MKDIR /etc/apache2/ssl
cd /etc/apache2/
$CMD_MV /etc/apache2/ports.conf /etc/apache2/ports.conf.bkp

echo "[ + ] Configuring ports"

echo '
# Created by Waf2Py installer script
<IfModule ssl_module>
	#Listen 443
	Listen 62443
</IfModule>

<IfModule mod_gnutls.c>
	Listen 443
</IfModule>
' > /etc/apache2/ports.conf

echo "[ + ] Enabling apache modules"
$CMD_A2ENMOD ssl
$CMD_A2ENMOD proxy
$CMD_A2ENMOD proxy_http
$CMD_A2ENMOD headers
$CMD_A2ENMOD expires
$CMD_A2ENMOD wsgi
clear

echo "[ + ] Creating apache config"
echo '
# Created by Waf2Py installer script
<VirtualHost *:62443>
  #SSL certs
  SSLEngine on
  SSLCertificateFile /etc/apache2/ssl/self_signed.cert
  SSLCertificateKeyFile /etc/apache2/ssl/self_signed.key

  WSGIDaemonProcess Waf2Py user=www-data group=www-data
  WSGIProcessGroup Waf2Py
  WSGIScriptAlias / /home/www-data/waf2py_community/wsgihandler.py
  WSGIPassAuthorization On


<Location /admin>
  Require all granted
  #Comment line above and uncomment lines below to restrict access to the admin interfaces of web2py (Totally recommended):
  #Require ip X.X.X.X
  #Require all denied
  </Location>

  <LocationMatch ^/([^/]+)/appadmin>
    Require all granted
    #Comment line above and uncomment lines below to restrict access to the admin interfaces of web2py (Totally recommended):
    #Require ip X.X.X.X
    #Require all denied
  </LocationMatch>

  <Directory /home/www-data/waf2py_community>
    AllowOverride None
    Require all granted
    #Comment line above and uncomment lines below to restrict access to the waf2py app:
    #Require ip X.X.X.X
    #Require all denied

    <Files wsgihandler.py>
       Require all granted
       #Comment line above and uncomment lines below to restrict access to the waf2py app:
       #Require ip X.X.X.X
       #Require all denied
    </Files>
  </Directory>

  AliasMatch ^/([^/]+)/static/(?:_[\d]+.[\d]+.[\d]+/)?(.*) \
        /home/www-data/waf2py_community/applications/$1/static/$2

  <Directory /home/www-data/waf2py_community/applications/*/static/>
    Options -Indexes
    ExpiresActive On
    ExpiresDefault "access plus 1 hour"
    Require all granted
    #Comment line above and uncomment lines below to restrict access to the static content:
    #Require ip X.X.X.X
    #Require all denied
  </Directory>


  #Access and error logs files
  CustomLog /var/log/apache2/waf2py_access.log common
  ErrorLog /var/log/apache2/waf2py_error.log

</VirtualHost> ' > /etc/apache2/sites-available/waf2py.conf

echo "[ + ] Enabling Waf2Py on apache"
cd /etc/apache2/sites-enabled
$CMD_LN -s ../sites-available/waf2py.conf .

echo "[ + ] Creating ssl certificates"

cd /etc/apache2/ssl
$CMD_OPENSSL genrsa 4096 > /etc/apache2/ssl/self_signed.key
$CMD_CHMOD 400 /etc/apache2/ssl/self_signed.key
if [ -n "$SSLCountry" ]; then
	$CMD_OPENSSL req -new -x509 -nodes -sha1 -days 365 -subj "/C=$SSLCountry/ST=$SSLState/L=$SSLLocation/O=$SSLOrg/CN=$SSLCN" -key /etc/apache2/ssl/self_signed.key > /etc/apache2/ssl/self_signed.cert
else
	$CMD_OPENSSL req -new -x509 -nodes -sha1 -days 365 -key /etc/apache2/ssl/self_signed.key > /etc/apache2/ssl/self_signed.cert
fi	
$CMD_OPENSSL x509 -noout -fingerprint -text < /etc/apache2/ssl/self_signed.cert > /etc/apache2/ssl/self_signed.info
clear

$CMD_CHOWN -R www-data:www-data /home/www-data/waf2py_community
echo "[ + ] Change the admin password for the admin interface of web2py"
cd /home/www-data/waf2py_community
$CMD_SUDO -u www-data python -c "from gluon.widget import console; console();"

if [ -n "$adminPass" ]; then
    $CMD_SUDO -u www-data python -c "from gluon.main import save_password; save_password($adminPass,62443)"
else
    $CMD_SUDO -u www-data python -c "from gluon.main import save_password; save_password(raw_input('Choose an admin password for web2py admin: '),62443)"
fi
cd ../

# remove default web2py applications
$CMD_RM -r /home/www-data/waf2py_community/applications/examples
$CMD_RM -r /home/www-data/waf2py_community/applications/welcome

echo "[ + ] Adding user www-data to sudo"
$CMD_ADDUSER www-data sudo
echo '
www-data ALL=(ALL) NOPASSWD: /opt/waf/nginx/sbin/nginx
www-data ALL=(ALL) NOPASSWD: /bin/netstat
www-data ALL=(ALL) NOPASSWD: /bin/chmod
www-data ALL=(ALL) NOPASSWD: /bin/chown
www-data ALL=(ALL) NOPASSWD: /sbin/ifconfig
www-data ALL=(ALL) NOPASSWD: /sbin/route
' > /etc/sudoers.d/Waf2Py
$CMD_TOUCH $DIR_SUDOLECTURE/www-data

cd $CURR_DIR

# unpack war_core to /opt
case $DEBIAN_VERSION in
  "8")
    $CMD_TAR xvzf waf_core_debian_8.tar.gz -C /opt/
    ;;
  "9")
    $CMD_TAR xvzf waf_core_debian_9.tar.gz -C /opt/
    ;;
  *)
    echo -e "I wonder how you got that far ... G'bye"
    ;;
esac

clear
echo "[ + ] Creating cronjobs"

$CMD_MKDIR /etc/crons_waf
echo '
#!/bin/sh

test -x /usr/sbin/logrotate || exit 0
/usr/sbin/logrotate /etc/logrotate.conf
' > /etc/crons_waf/logrotate

# write out current crontab
$CMD_CRONTAB -l > waf_cron
# echo new cron into cron file
echo '@reboot  /usr/bin/python /home/www-data/waf2py_community/applications/Waf2Py/scripts/check_services.py
2 0 * * * /usr/bin/python /home/www-data/waf2py_community/applications/Waf2Py/scripts/index_logs_files.py
0 */2 * * * /bin/bash /home/www-data/waf2py_community/applications/Waf2Py/scripts/remove_tmp.sh
0 */2 * * * /bin/bash /home/www-data/waf2py_community/applications/Waf2Py/scripts/clean_logs.sh
1 0 * * * /bin/bash /etc/crons_waf/logrotate' >> waf_cron
# install new cron file
$CMD_CRONTAB waf_cron
$CMD_RM waf_cron

echo "[ + ] Creating routes file"
echo "
routers = dict(
    BASE = dict(
        default_application='Waf2Py'
    )
)
"> /home/www-data/waf2py_community/routes.py

$CMD_MKDIR /home/www-data/waf2py_community/applications/Waf2Py/logrotation.d
$CMD_CHOWN -R www-data:www-data /home/www-data/waf2py_community/*

/etc/init.d/apache2 restart

echo "[ + ] Done!"
echo "[ ++ ] Now go to https://yourip:62443/Waf2Py and login"
echo "[ ++ ] User: admin"
echo "[ ++ ] Pass: admin"
echo "[ ++ ] Please don't forget to change the default password"
echo "Note: Before you go public on the internet, check /etc/apache2/sites-enabled/waf2py.conf and look for lines 'Require ip x.x.x.x', make sure to put your IPs there to avoid any other unwanted 'user' trying to access to this interface"

