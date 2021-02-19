#!/bin/bash

#sh -c "$(curl -fsSL https://nsknet.github.io/install/centos.sh)"


function install_postgres_remote()
{

	echo "========================================================================="
	echo "Install POSTGRESQL12"
	
	#https://www.digitalocean.com/community/tutorials/how-to-install-postgresql-on-ubuntu-20-04-quickstart
	apt install -y postgresql-12 postgresql-contrib

	#init database
	echo "init database ========================="
	#sudo /usr/pgsql-12/bin/postgresql-12-setup initdb

	systemctl enable postgresql
	systemctl start postgresql
	systemctl status postgresql


	printf "\nEnter db password for user postgres [no special charaters]: " 
	read db_password
	# #error here!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	su - postgres -c "psql -U postgres -d postgres -c \"alter user postgres with password '$db_password';\""
	sudo systemctl restart postgresql


	#allow PostgreSQL service.
	#TODO disable the Firewall rule, we will use putty tunel for more sercure
	# sudo firewall-cmd --add-service=postgresql --permanent
	# sudo firewall-cmd --zone=public --add-port=5432/tcp --permanent
	# sudo firewall-cmd --reload

	cp /etc/postgresql/12/main/postgresql.conf /etc/postgresql/12/main/postgresql.conf.bak
	cat > "/etc/postgresql/12/main/postgresql.conf" <<END
#for Ubuntu, centos doesnt have these lines
data_directory = '/var/lib/postgresql/12/main'
hba_file = '/etc/postgresql/12/main/pg_hba.conf'
ident_file = '/etc/postgresql/12/main/pg_ident.conf'
external_pid_file = '/var/run/postgresql/12-main.pid'
include_dir = 'conf.d'


listen_addresses ='*'
max_connections = 100			
shared_buffers = 128MB			
dynamic_shared_memory_type = posix	
max_wal_size = 1GB
min_wal_size = 80MB
log_destination = 'stderr'		
logging_collector = on			
log_directory = 'log'			
log_filename = 'postgresql-%a.log'	
log_truncate_on_rotation = on		
log_rotation_age = 1d			
log_rotation_size = 0			
log_line_prefix = '%m [%p] '		
log_timezone = 'Asia/Ho_Chi_Minh'
datestyle = 'iso, mdy'
timezone = 'Asia/Ho_Chi_Minh'
lc_messages = 'en_US.UTF-8'			
lc_monetary = 'en_US.UTF-8'			
lc_numeric = 'en_US.UTF-8'			
lc_time = 'en_US.UTF-8'				
default_text_search_config = 'pg_catalog.english'
END

	cp /etc/postgresql/12/main/pg_hba.conf /etc/postgresql/12/main/pg_hba.conf.bak
	cat > "/etc/postgresql/12/main/pg_hba.conf" <<END
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             all                                     md5
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
# Allow replication connections from localhost, by a user with the replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            ident
host    replication     all             ::1/128                 ident
# Accept from anywhere
host 	all 			all 			0.0.0.0/0 				md5

END
	systemctl restart postgresql

	echo ""
	echo "Done"
	echo "========================================================================="	
}

function install_fail2ban(){
	#https://hocvps.com/cai-dat-fail2ban-tren-centos/
	echo "========================================================================="
	echo "Config fail2ban"
	yum install epel-release -y
	yum install fail2ban -y

	cat > "/etc/fail2ban/jail.conf" <<END
[DEFAULT]

# "ignoreip" can be an IP address, a CIDR mask or a DNS host. Fail2ban will not
# ban a host which matches an address in this list. Several addresses can be
# defined using space separator.
ignoreip = 127.0.0.1 

# "bantime" is the number of seconds that a host is banned.
bantime = 600

# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime = 600

# "maxretry" is the number of failures before a host get banned.
maxretry = 3
END


	cat > "/etc/fail2ban/jail.local" <<END
[DEFAULT]
[sshd]

enabled  = true
filter   = sshd
action   = iptables[name=SSH, port=ssh, protocol=tcp]
logpath  = /var/log/secure
maxretry = 3
bantime = 3600
END

	chkconfig --level 23 fail2ban on
	service fail2ban start

	
	echo "Enable firewall"
	systemctl enable firewalld
	systemctl restart firewalld


	echo ""
	echo "Done"
	echo "========================================================================="
}


function install_php(){
	echo "========================================================================="
	echo "Install PHP"

	sudo yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
	sudo yum-config-manager --enable remi-php74
	sudo yum -y install php php-common php-opcache php-mcrypt php-cli php-gd php-curl php-mysql  php-mbstring php-fpm
	php --version
	
cat > "/etc/php-fpm.d/www.conf" <<END
[www]
user = nginx
group = nginx
listen = /var/run/php-fpm/php-fpm.sock
listen.allowed_clients = 127.0.0.1
listen.owner = nginx
listen.group = nginx
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
slowlog = /var/log/php-fpm/www-slow.log
php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path]    = /var/lib/php/session
php_value[soap.wsdl_cache_dir]  = /var/lib/php/wsdlcache
END


cat > "/etc/selinux/config" <<END
SELINUX=disabled
SELINUXTYPE=targeted
END
	#temporarily change the selinux mode from targeted to permissive
	sudo setenforce 0

	chown -R root:nginx /var/lib/php
	sudo systemctl enable php-fpm
	sudo systemctl start php-fpm
	
	echo ""
	echo "Done"
	echo "If you have any permission error, please try to reboot the system"
	echo "========================================================================="
}

function install_netcore(){
	#install netcore
	#https://docs.microsoft.com/en-us/dotnet/core/install/linux-package-manager-centos7
	echo "========================================================================="
	echo "Install Netcore"
	wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	dpkg -i packages-microsoft-prod.deb
	#apt update
	apt install -y  apt-transport-https dotnet-sdk-5.0  dotnet-sdk-3.1
	rm packages-microsoft-prod.deb
	echo ""
	echo "Done"
	echo "========================================================================="
}

function install_mongodb(){
	#install mongodb
	#https://docs.mongodb.com/manual/tutorial/install-mongodb-on-red-hat/
	echo "========================================================================="
cat > "/etc/yum.repos.d/mongodb-org-4.4.repo" <<END
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc

END


	yum install -y mongodb-org
	mkdir -p /var/lib/mongo
	mkdir -p /var/log/mongodb


	chown -R mongod:mongod /var/lib/mongo
	chown -R mongod:mongod /var/log/mongodb

cp /etc/mongod.conf /etc/mongod.conf.bak
cat > "/etc/mongod.conf" <<END
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

storage:
  dbPath: /var/lib/mongo
  journal:
    enabled: true

processManagement:
  fork: true  
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

net:
  port: 27017
  bindIpAll: true
END



	systemctl enable mongod
	service  mongod start
	service  mongod status

	#sudo firewall-cmd --add-service=mongod --permanent
	#sudo firewall-cmd --zone=public --add-port=27017/tcp --permanent
	#sudo firewall-cmd --reload


	echo ""
	echo "Done"
	echo "========================================================================="
}

function install_elastic_kibana(){
	#install Elasticsearch & Kibana
	#https://linuxize.com/post/how-to-install-elasticsearch-on-centos-7/
	echo "========================================================================="

	
	#setup the source repo
	rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
	cat > "/etc/yum.repos.d/elasticsearch.repo" <<END
[elasticsearch]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md
END
	yum install -y --enablerepo=elasticsearch elasticsearch
	#service elasticsearch start

	#open the firewall
	# sudo firewall-cmd --add-service=elasticsearch --permanent
	# sudo firewall-cmd --zone=public --add-port=9200/tcp --permanent
	# sudo firewall-cmd --reload

	#config to listen from all ip addreses
	cat > "/etc/elasticsearch/elasticsearch.yml" <<END
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node
END

	systemctl daemon-reload
	systemctl enable elasticsearch
	service elasticsearch restart

	#nothing danger, just want to see the log ^^
	#sudo journalctl -u elasticsearch


	################################
	#kibana
	yum install --enablerepo=elasticsearch kibana -y
	#service kibana start

	#open the firewall
	# sudo firewall-cmd --add-service=kibana --permanent
	# sudo firewall-cmd --zone=public --add-port=5601/tcp --permanent
	# sudo firewall-cmd --reload

	#config to listen from all ip addreses
	cat > "/etc/kibana/kibana.yml" <<END
server.port: 5601
server.host: "127.0.0.1"
elasticsearch.hosts: ["http://127.0.0.1:9200"]
#logging.verbose: true
END

	systemctl daemon-reload
	systemctl enable kibana
	service kibana restart

	echo ""
	echo "If the elastic cannot start, please try to disable SELinux or buy a stronger machine :)"
	echo "If the kibana err, please check by: /usr/share/kibana/bin/kibana -V"
	echo "Done"
	echo "========================================================================="
}

function install_nginx(){
	echo "========================================================================="
	echo "Install NGINX"

	#nginx
	apt-get -y install nginx

	systemctl start nginx
	systemctl enable nginx
	systemctl status nginx

	#preconfig for nginx
	sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
	cat > "/etc/nginx/nginx.conf" <<END
user www-data;
worker_processes auto;
error_log /var/log/nginx/global-error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
	worker_connections 1024;
}


http {
	log_format  main  '\$remote_addr (\$http_x_forwarded_for) - \$remote_user [\$time_local] "\$request" '
					  '\$status \$body_bytes_sent "\$http_referer" '
					  '"\$http_user_agent"';

	access_log  /var/log/nginx/global-access.log  main;

	sendfile            on;
	tcp_nopush          on;
	tcp_nodelay         on;
	keepalive_timeout   65;
	types_hash_max_size 2048;

	include             /etc/nginx/mime.types;
	default_type        application/octet-stream;

	include /etc/nginx/conf.d/*.conf;
	
	gzip on;
	gzip_static on;
	gzip_disable "msie6";
	gzip_vary on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;
	gzip_http_version 1.1;
	gzip_types text/plain text/css application/json text/javascript application/javascript text/xml application/xml application/xml+rss;

	server {
		listen      80 default_server;
		server_name "";
		return      444;
	}

}
END

	cat > "/usr/share/nginx/html/403.html" <<END
<html>
<head><title>403 Forbidden</title></head>
<body bgcolor="white">
<center><h1>403 Forbidden</h1></center>
</body>
</html>
END

	cat > "/usr/share/nginx/html/404.html" <<END
<html>
<head><title>404 Not Found</title></head>
<body bgcolor="white">
<center><h1>404 Not Found</h1></center>
</body>
</html>
END
	systemctl restart nginx
	
	#fix Permission denied by default, digital ocean
	sudo setsebool -P httpd_can_network_connect on 

	
	ufw allow http
	ufw allow https
	firewall-cmd --reload
	

	echo ""
	echo "Done"
	echo "========================================================================="
}



function install_nginx_certbot(){
	yum -y install yum-utils
	yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional
	yum -y install certbot python2-certbot-nginx
	#sudo certbot --nginx
	echo "0 0,12 * * * root python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew" | sudo tee -a /etc/crontab > /dev/null
	
	
	#certbot --nginx certonly --noninteractive --webroot --agree-tos --register-unsafely-without-email -d ${SITE_DOMAIN} 
}



function install_nginx_netcore_domain(){
	echo "========================================================================="
	echo "Install new nginx domain and netcore site"
	printf "\nEnter your main domain [ENTER]: " 
	read server_name
	server_name_alias="www.$server_name"
	if [[ $server_name == *www* ]]; then
		server_name_alias=${server_name/www./''}
	fi

	printf "\nEnter your executedll [example.dll]: " 
	read dll_full_name
	
	dll_name="$dll_full_name"
	if [[ $dll_full_name == *dll* ]]; then
		dll_name=${dll_full_name/.dll/''}
	fi
	

	# printf "\nEnter port number [from 2000 to 65000]: " 
	# read port_number
	DIFF=$((50000-5000+1))
	port_number=$(($(($RANDOM%$DIFF))+5000))

	mkdir -p /var/www/nginx/$server_name/public
	# mkdir /var/www/nginx/$server_name/private_html
	# mkdir /var/www/nginx/$server_name/logs
	chmod 777 /var/www/nginx/$server_name
	# chmod 777 /var/www/nginx/$server_name/logs
	mkdir -p /var/log/nginx

	#take ownership to centos account
	# chown -R centos:centos /var/www/nginx/$server_name



	cat > "/etc/nginx/conf.d/$server_name.conf" <<END
server {
		client_max_body_size 200M;
		listen       80;
		server_name $server_name;
		root         /usr/share/nginx/html;
		error_log /var/log/nginx/$server_name-error.log;
		access_log  /var/log/nginx/$server_name-access.log main;

		# Load configuration files for the default server block.
		include /etc/nginx/default.d/*.conf;

		location / {
			proxy_pass http://127.0.0.1:$port_number;
			proxy_redirect off;
			proxy_set_header Host \$host;
			proxy_set_header X-Real-IP \$remote_addr;
			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
			proxy_set_header X-Forwarded-Proto \$scheme;
		}

		error_page 404 /404.html;
			location = /40x.html {
		}
		error_page 500 502 503 504 /50x.html;
			location = /50x.html {
		}
}
END


	cat > "/etc/systemd/system/$server_name.service"  <<END
[Unit]
Description=$server_name

[Service]
WorkingDirectory=/var/www/nginx/$server_name/public
ExecStart=/usr/bin/dotnet /var/www/nginx/$server_name/public/$dll_name.dll
Restart=always
# Restart service after 10 seconds if the dotnet service crashes:
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=$server_name
User=root
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_HTTP_PORT=$port_number
Environment=ASPNETCORE_URLS=http://localhost:$port_number

[Install]
WantedBy=multi-user.target
END


	echo "========================================================================="
	echo "Donwload sample site"
	wget nsknet.github.io/install/SampleBlankSite.tar -P  /var/www/nginx/$server_name/public/
	tar -xvf /var/www/nginx/$server_name/public/SampleBlankSite.tar -C /var/www/nginx/$server_name/public
	rm -fv  /var/www/nginx/$server_name/public/SampleBlankSite.tar
	mv /var/www/nginx/$server_name/public/SampleBlankSite.deps.json  /var/www/nginx/$server_name/public/$dll_name.deps.json
	mv /var/www/nginx/$server_name/public/SampleBlankSite  /var/www/nginx/$server_name/public/$dll_name
	mv /var/www/nginx/$server_name/public/SampleBlankSite.pdb  /var/www/nginx/$server_name/public/$dll_name.pdb
	mv /var/www/nginx/$server_name/public/SampleBlankSite.dll  /var/www/nginx/$server_name/public/$dll_name.dll
	mv /var/www/nginx/$server_name/public/SampleBlankSite.runtimeconfig.json  /var/www/nginx/$server_name/public/$dll_name.runtimeconfig.json
	# perl -pi -e 's/SampleBlankSite/{$dll_name}/g' /var/www/nginx/$server_name/public/$dll_name.deps.json
	sed -i.bak s/SampleBlankSite/$dll_name/g /var/www/nginx/$server_name/public/$dll_name.deps.json




	systemctl daemon-reload
	sudo systemctl restart nginx
	sudo systemctl start $server_name.service




	echo "========================================================="
	echo "Install nginx done, please upload your code to: /var/www/nginx/$server_name/public"
	echo "Main dll name is $dll_name, edit it at /etc/systemd/system/$server_name.service"
	echo "Domain name $server_name, nginx config at /etc/nginx/conf.d/$server_name.conf"
	echo "Local port number $port_number"
	echo "========================================================="

}


function install_nginx_php_domain(){
	echo "========================================================================="
	echo "Install new nginx domain and php site"
	printf "\nEnter your main domain [ENTER]: " 
	read server_name
	server_name_alias="www.$server_name"
	if [[ $server_name == *www* ]]; then
		server_name_alias=${server_name/www./''}
	fi


	mkdir -p /var/www/nginx/$server_name/public
	# mkdir /var/www/nginx/$server_name/private_html
	# mkdir /var/www/nginx/$server_name/logs
	chmod 777 /var/www/nginx/$server_name
	# chmod 777 /var/www/nginx/$server_name/logs
	mkdir -p /var/log/nginx

	#take ownership to centos account
	# chown -R centos:centos /var/www/nginx/$server_name
	chown -R nginx:nginx  /var/www/nginx/$server_name


	cat > "/etc/nginx/conf.d/$server_name.conf" <<END
server {
		client_max_body_size 200M;
		listen       80;
		server_name $server_name;
		#root         /usr/share/nginx/html;
		#root /var/www/$server_name/public; 
		root /var/www/nginx/$server_name/public;
		error_log /var/log/nginx/$server_name-error.log;
		access_log  /var/log/nginx/$server_name-access.log main;
        	index index.php index.html index.htm index.nginx-debian.html;

		# Load configuration files for the default server block.
		include /etc/nginx/default.d/*.conf;

		location / {
			try_files \$uri \$uri/ /index.php\$request_uri;
		}

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
		error_page 404 /404.html;
			location = /40x.html {
		}
		error_page 500 502 503 504 /50x.html;
			location = /50x.html {
		}
}
END

	cat > "/var/www/nginx/$server_name/public/index.php" <<END
<?php
phpinfo();
?>
END

	sudo systemctl restart nginx

	echo "========================================================="
	echo "Domain added, please upload your code to: /var/www/nginx/$server_name/public"
	echo "Domain name $server_name, nginx config at /etc/nginx/conf.d/$server_name.conf"
	echo "If it thrown 403, please run this command: restorecon -r -v /var/www/nginx/$server_name/public"
	echo "========================================================="

}
function install_wordpress_phpmyadmin(){
	echo "========================================================================="
	echo "Install Wordpress & phpMyAdmin"
	printf "\nEnter your main domain [ENTER]: " 
	read server_name
	server_name_alias="www.$server_name"
	if [[ $server_name == *www* ]]; then
		server_name_alias=${server_name/www./''}
	fi


	mkdir -p /var/www/nginx/$server_name/public
	chmod 777 /var/www/nginx/$server_name

	wget https://wordpress.org/latest.tar.gz
	wget https://files.phpmyadmin.net/phpMyAdmin/4.9.5/phpMyAdmin-4.9.5-english.tar.gz
	tar -zxvf latest.tar.gz
	tar -zxvf phpMyAdmin-4.9.5-english.tar.gz

	mv wordpress/* /var/www/nginx/$server_name/public

	yes | cp -rf  wordpress/* /var/www/nginx/$server_name/public
	rm -rf wordpress

	mkdir /var/www/nginx/$server_name/public/phpMyAdmin
	mkdir /var/www/nginx/$server_name/public/phpMyAdmin/tmp
	chmod 777 /var/www/nginx/$server_name/public/phpMyAdmin/tmp
	yes | cp -rf  phpMyAdmin-4.9.5-english/* /var/www/nginx/$server_name/public/phpMyAdmin
	rm -rf phpMyAdmin-4.9.5-english

	rm -fv  latest.tar.gz
	rm -fv  phpMyAdmin-4.9.5-english.tar.gz
	chown -R nginx:nginx  /var/www/nginx/$server_name


	echo "========================================================="
	echo "Wordpress & phpMyAdmin have been installed to /var/www/nginx/$server_name/public"
	echo "Wordpress: $server_name"
	echo "phpMyAdmin: $server_name/phpMyAdmin"
	echo "========================================================="

}


function install_nginx_certbot_add_domain_direct_dns(){
	echo "========================================================================="
	echo "Setup https"
	printf "\nEnter your main domain [ENTER]: " 
	read server_name
	server_name_alias="www.$server_name"
	if [[ $server_name == *www* ]]; then
		server_name_alias=${server_name/www./''}
	fi
	certbot --nginx  --noninteractive  --agree-tos --register-unsafely-without-email -d $server_name_alias
	echo ""
	echo "Done"
	echo "========================================================================="
}

function install_nginx_certbot_add_domain_cloudflare(){
	yum -y install python3-pip
	pip3 install certbot-dns-cloudflare
	
	echo "========================================================================="
	echo "Setup https"
	printf "\nEnter your main domain [ENTER]: " 
	read server_name
	server_name_alias="www.$server_name"
	if [[ $server_name == *www* ]]; then
		server_name_alias=${server_name/www./''}
	fi
	#didnt create /root/cloudflare.ini yet
	cat > "/etc/systemd/system/$server_name.service"  <<END
[Unit]
dns_cloudflare_email = email@gmail.com
dns_cloudflare_api_key = Global API Key
END
	
	chmod 600 /root/cloudflare.ini
	certbot --dns-cloudflare --dns-cloudflare-credentials /root/cloudflare.ini --nginx  --noninteractive  --agree-tos --register-unsafely-without-email -d $server_name_alias -d *.$server_name_alias
	echo ""
	echo "Done"
	echo "========================================================================="
}


function install_mariadb(){
	echo "========================================================================="
	echo "Install MariaDB"

	sudo yum -y install mariadb-server
	sudo systemctl start mariadb.service
	sudo systemctl enable mariadb.service
	sudo systemctl status mariadb
	sudo mysql_secure_installation
	
	echo ""
	echo "Done"
	echo "========================================================================="
}

function install_open_vpn(){
	echo "========================================================================="
	echo "Install OpenVPN"
	curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
	chmod +x openvpn-install.sh
	AUTO_INSTALL=y ./openvpn-install.sh
	echo "Done"
	echo "========================================================================="
}

function install_virtual_ram_4g(){
	echo "========================================================================="
	echo "Add more 4GB Virtual RAM"
	sudo dd if=/dev/zero of=/swapfile bs=1024 count=4096k
	mkswap /swapfile
	swapon /swapfile
	swapon -s
	echo /swapfile none swap defaults 0 0 >> /etc/fstab
	chown root:root /swapfile 
	chmod 0600 /swapfile
	cat /proc/sys/vm/swappiness

	echo "Done"
	echo "========================================================================="

}

function common_configs(){
	echo "========================================================================="
	echo "Common config"

	echo "Set datetime to GMT+7"
	rm -f /etc/localtime
	ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
	
	echo "Common tools"
	apt update
	apt-get -y install wget axel htop tmux rar unrar

	echo "Firewall"
	apt install -y ufw	
	ufw default deny incoming
	ufw default allow outgoing
	ufw --force enable

	echo ""
	echo "Done"
	echo "========================================================================="
}

function show_menu(){
	echo "Select function to execute or press CRTL+C to exit:"
	echo "    0) Setup: Common config for all VPS (time zone, firewall, fail2ban)"
	echo "    1) Setup: Virtual RAM 4GB"
	echo "    2) Install: NetCore 5.0"
	echo "    3) Install: NGINX"
	echo "    4) Install: PostgreSql 12"
	echo "    5) Install: MariaDb"
	echo "    6) Install: PHP 7.4"
	echo "    7) Add: Domain with NGINX and PHP"
	echo "    8) Add: Domain with NGINX and NetCore"
	echo "    9) Deploy: Wordpress & phpMyAdmin"
	echo "    10) Install: MongoDB"
	echo "    11) Install: Elasticsearch & Kibana"
	#echo "    9) Install: Open VPN"
	# echo "    10) Install: Cerbot Let's Encrypt to NGINX"
	# echo "    11) Add: Cerbot config to domain via direct DNS"
	# echo "    12) Add: Cerbot config to domain via Cloudflare"
	# echo "    10) Install: FTP"
	# echo "    11) Add: FTP Account"


	printf "Your choise: "

	read n
	case $n in
	  0) 
		  common_configs
		  #install_fail2ban
		  ;;		  
	  1) 
		  install_virtual_ram_4g
		  ;;		  
	  2) 
		  install_netcore
		  ;;	  
	  3) 
		  install_nginx
		  ;;	  
	  4) 
		  install_postgres_remote
		  ;;
	  5) 
		  install_mariadb
		  ;;
	  6) 
		  install_php
		  ;;		  
	  7) 
		  install_nginx_php_domain
		  ;;	  
	  8) 
		  install_nginx_netcore_domain
		  ;;  
		  
	  # 9) 
		  # install_open_vpn
		  # ;;	  
	  9) 
		  install_wordpress_phpmyadmin
		  ;;
	 10) 
	  	  install_mongodb
		  ;;
	 11) 
	  	  install_elastic_kibana
		  ;;
	  
	#   10) 
	# 	  install_nginx_certbot
	# 	  ;;	  
	#   11) 
	# 	  install_nginx_certbot_add_domain_direct_dns
	# 	  ;;	  
	  12) 
		  install_nginx_certbot_add_domain_cloudflare
		  ;;	  


		  

	  *) echo "Invalid option";;
	esac
}


while :
do
	# clear
	echo ""
	echo "========================================================================="
	show_menu
	echo ""
	read -rsn1 -p"Press any key to continue  ";echo
	echo ""
	echo ""
	echo ""
	echo ""
done



#FAQ:

#Q: Wordpress: To perform the requested action, WordPress needs to access your web server
#A: Add this line to wp-config.php:
#	define( 'FS_METHOD', 'direct' );





