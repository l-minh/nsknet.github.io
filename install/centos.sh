#!/bin/bash

function install_postgres_remote()
{

	echo "========================================================================="
	echo "Install POSTGRESQL12"
	
	#https://computingforgeeks.com/how-to-install-postgresql-12-on-centos-7/
	sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

	sudo yum install epel-release yum-utils -y 
	sudo yum-config-manager --enable pgdg12
	sudo yum install postgresql12-server postgresql12 -y

	#init database
	echo "init database ========================="
	sudo /usr/pgsql-12/bin/postgresql-12-setup initdb

	sudo systemctl enable --now postgresql-12

	#If you have a running Firewall service and remote clients should connect to your database server, allow PostgreSQL service.
	sudo firewall-cmd --add-service=postgresql --permanent
	sudo firewall-cmd --reload


	cat > "/var/lib/pgsql/12/data/postgresql.conf" <<END
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


	cat > "/var/lib/pgsql/12/data/pg_hba.conf" <<END
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
	sudo systemctl restart postgresql-12

	# echo "Set PostgreSQL admin user"
	# sudo su - postgres
	
	printf "\nEnter db password for user postgres: " 
	read db_password
	#error here!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	su - postgres -c "psql -U postgres -d postgres -c \"alter user postgres with password '$db_password';\""
	sudo systemctl restart postgresql-12

	echo ""
	echo "Done"
	echo "========================================================================="
	
}

function install_fail2ban(){
	#https://hocvps.com/cai-dat-fail2ban-tren-centos/
	echo "========================================================================="
	echo "Config fail2ban"
	yum install epel-release
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

function install_phpMyAdmin(){
	echo "Intall phpmyadmin"
	yum -y install phpmyadmin

	printf "\nEnter your domain for phpmyadmin [ENTER]: " 
	read server_name
	server_name_alias="www.$server_name"
	if [[ $server_name == *www* ]]; then
		server_name_alias=${server_name/www./''}
	fi

	cat > "/etc/nginx/conf.d/phpmyadmin.conf" <<END
server {
        listen   80;
        server_name $server_name;
        root /usr/share/phpMyAdmin;
		
	location / {
        index  index.php;
        }
    location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|xml)\$ {
        access_log        off;
        expires           30d;
    }
	location ~ /\.ht {
        deny  all;
    }
	location ~ /(libraries|setup/frames|setup/libs) {
        deny all;
        return 404;
    }
	location ~ \.php\$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME /usr/share/phpMyAdmin\$fastcgi_script_name;
		proxy_set_header X-Real-IP  \$remote_addr;
		proxy_set_header X-Forwarded-For \$remote_addr;
		proxy_set_header Host \$host;
    }
}
END

	systemctl restart nginx.service
	systemctl restart php-fpm.service
	sed '1 a \$cfg['\''PmaAbsoluteUri'\''] = '\''https://'$server_name\''; '  /etc/phpMyAdmin/config.inc.php  > /etc/phpMyAdmin/config.inc.php.tmp

	mv /etc/phpMyAdmin/config.inc.php.tmp /etc/phpMyAdmin/config.inc.php -f

	echo "========================================="
	echo "Done"

}

function install_php(){
	echo "========================================================================="
	echo "Common config"


	rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
	yum install php70w php70w-bcmath php70w-cli php70w-common php70w-dba php70w-devel php70w-embedded php70w-enchant php70w-fpm php70w-gd php70w-imap php70w-interbase php70w-intl php70w-ldap php70w-mbstring php70w-mcrypt php70w-mysqlnd php70w-odbc php70w-opcache php70w-pdo php70w-pdo_dblib php70w-pecl-xdebug php70w-pgsql php70w-phpdbg php70w-process php70w-pspell php70w-recode php70w-snmp php70w-soap php70w-tidy php70w-xml php70w-xmlrpc -y

	systemctl start php-fpm
	systemctl enable php-fpm


	echo ""
	echo "Done"
	echo "========================================================================="
}

function install_netcore(){
	#install netcore
	#https://docs.microsoft.com/en-us/dotnet/core/install/linux-package-manager-centos7
	echo "========================================================================="
	echo "Install Netcore"
	sudo rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
	sudo yum install dotnet-sdk-3.1 aspnetcore-runtime-3.1 dotnet-runtime-3.1 -y
	
	echo ""
	echo "Done"
	echo "========================================================================="
}

function install_nginx(){
	echo "========================================================================="
	echo "Install NGINX"

	#nginx
	sudo yum install nginx -y
	sudo systemctl start nginx
	sudo systemctl enable nginx
	sudo systemctl status nginx

	#preconfig for nginx
	sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
	cat > "/etc/nginx/nginx.conf" <<END
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
	worker_connections 1024;
}


http {
	log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
					  '\$status \$body_bytes_sent "\$http_referer" '
					  '"\$http_user_agent" "\$http_x_forwarded_for"';

	access_log  /var/log/nginx/access.log  main;

	sendfile            on;
	tcp_nopush          on;
	tcp_nodelay         on;
	keepalive_timeout   65;
	types_hash_max_size 2048;

	include             /etc/nginx/mime.types;
	default_type        application/octet-stream;

	include /etc/nginx/conf.d/*.conf;
	
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
	sudo systemctl restart nginx
	
	#fix Permission denied by default, digital ocean
	sudo setsebool -P httpd_can_network_connect on 

	
	firewall-cmd --zone=public --add-port=80/tcp --permanent
	firewall-cmd --reload
	

	echo ""
	echo "Done"
	echo "========================================================================="
}

function install_nginx_netcore_domain(){

	printf "\nEnter your main domain [ENTER]: " 
	read server_name
	server_name_alias="www.$server_name"
	if [[ $server_name == *www* ]]; then
		server_name_alias=${server_name/www./''}
	fi

	printf "\nEnter your executedll [example.dll]: " 
	read dll_name

	printf "\nEnter port number [from 2000 to 65000]: " 
	read port_number


	mkdir -p /home/$server_name/public_html
	# mkdir /home/$server_name/private_html
	mkdir /home/$server_name/logs
	chmod 777 /home/$server_name
	chmod 777 /home/$server_name/logs
	mkdir -p /var/log/nginx

	#take ownership to centos account
	# chown -R centos:centos /home/$server_name



	cat > "/etc/nginx/conf.d/$server_name.conf" <<END
server {
		client_max_body_size 200M;
		listen       80;
		server_name $server_name;
		root         /usr/share/nginx/html;

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
WorkingDirectory=/home/$server_name/public_html
ExecStart=/usr/bin/dotnet /home/$server_name/public_html/$dll_name
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
	systemctl daemon-reload
	sudo systemctl restart nginx
	sudo systemctl start $server_name.service

	echo "========================================================="
	echo "Install nginx done, please upload your code to: /home/$server_name/public_html"
	echo "Main dll name is $dll_name, edit it at /etc/systemd/system/$server_name.service"
	echo "Domain name $server_name, nginx config at /etc/nginx/conf.d/$server_name.conf"
	echo "========================================================="

}

function install_mariadb(){
	echo "========================================================================="
	echo "Common config"


	admin_password=ldksjrhtpsd
	phienbanmariadb=10.4
#dint test it yet!!!!!!!!!!!

cat > "/etc/yum.repos.d/mariadb.repo" <<END

# MariaDB $phienbanmariadb CentOS repository list
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/$phienbanmariadb/centos7-amd64
gpgkey=http://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
END


	sudo yum install mariadb-server mariadb-client -y
	sudo systemctl start mariadb
	sudo systemctl enable mariadb
	sudo systemctl status mariadb


	echo "=========================================================================\n"
	echo "Config for MariaDB ... \n"
	echo "=========================================================================\n"


	'/usr/bin/mysqladmin' -u root password "$admin_password"
	mysql -u root -p "$admin_password" -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' IDENTIFIED BY '$admin_password' WITH GRANT OPTION;"
	mysql -u root -p "$admin_password" -e "DELETE FROM mysql.user WHERE User=''"
	mysql -u root -p "$admin_password" -e "DROP User '';"
	mysql -u root -p "$admin_password" -e "DROP DATABASE test"
	mysql -u root -p "$admin_password" -e "FLUSH PRIVILEGES"

	cat > "/root/.my.cnf" <<END
[client]
user=root
password=$admin_password
END
	chmod 600 /root/.my.cnf
	
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
	
	
	
	echo "WGET, AXEL"
	yum -y install epel-release 
	yum -y install  wget axel


	echo "Winrar"
	wget https://www.rarlab.com/rar/rarlinux-x64-5.8.0.tar.gz
	tar -zxvf rarlinux-x64-5.8.0.tar.gz
	cp -v ./rar/rar /usr/local/bin/
	cp -v ./rar/unrar /usr/local/bin/

		
	echo ""
	echo "Done"
	echo "========================================================================="
}

function show_menu(){
	echo "Select function to execute or press CRTL+C to exit:"
	echo "    0) Setup: Common config for all VPS (time zone, firewall, fail2ban)"
	echo "    1) Setup: Virtual RAM 4GB"
	echo "    2) Install: NetCore 3.1"
	echo "    3) Install: NGINX"
	echo "    4) Install: PostgreSql 12"
	echo "    5) Install: MariaDb 10.4"
	echo "    6) Install: PHP 7.3"
	echo "    7) Install: phpMyAdmin"
	echo "    8) Add: Domain with NGINX and NetCore"
	echo "    9) Install: Open VPN"
	# echo "    10) Install: FTP"
	# echo "    11) Add: FTP Account"
	printf "Your choise: "

	read n
	case $n in
	  0) 
		  common_configs
		  install_fail2ban
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
		  install_phpMyAdmin
		  ;;	  
	  8) 
		  install_nginx_netcore_domain
		  ;;  
	  9) 
		  install_open_vpn
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
