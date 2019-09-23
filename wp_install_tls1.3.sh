#!/bin/bash
 
function blue(){
    echo -e "\033[34m\033[01m $1 \033[0m"
}
function green(){
    echo -e "\033[32m\033[01m $1 \033[0m"
}
function red(){
    echo -e "\033[31m\033[01m $1 \033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m $1 \033[0m"
}
function bred(){
    echo -e "\033[31m\033[01m\033[05m $1 \033[0m"
}
function byellow(){
    echo -e "\033[33m\033[01m\033[05m $1 \033[0m"
}

#判断系统
if [ ! -e '/etc/redhat-release' ]; then
red "==============="
red " 仅支持CentOS7"
red "==============="
exit
fi
if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
red "==============="
red " 仅支持CentOS7"
red "==============="
exit
fi

install_php7(){

    green "==============="
    green "  安装必要软件"
    green "==============="
    sleep 1
    yum -y install epel-release
    sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
    yum -y install  wget unzip vim tcl expect expect-devel
    green "==============="
    green "    安装PHP7"
    green "==============="
    sleep 1
    rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
    yum -y install php70w php70w-mysql php70w-gd php70w-xml php70w-fpm
    service php-fpm start
    chkconfig php-fpm on
    if [ `yum list installed | grep php70 | wc -l` -ne 0 ]; then
    	green "【checked】 PHP7安装成功"
	echo
	echo
	sleep 2
	php_status=1
    fi
}

install_mysql(){

    green "==============="
    green "   安装MySQL"
    green "==============="
    sleep 1
    wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    rpm -ivh mysql-community-release-el7-5.noarch.rpm
    yum -y install mysql-server
    systemctl enable mysqld.service
    systemctl start  mysqld.service
    if [ `yum list installed | grep mysql-community | wc -l` -ne 0 ]; then
    	green "【checked】 MySQL安装成功"
	echo
	echo
	sleep 2
	mysql_status=1
    fi
    green "==============="
    green "   配置MySQL"
    green "==============="
    sleep 1
    mysqlpasswd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
    
/usr/bin/expect << EOF
spawn mysql_secure_installation
expect "password for root" {send "\r"}
expect "root password" {send "Y\r"}
expect "New password" {send "$mysqlpasswd\r"}
expect "Re-enter new password" {send "$mysqlpasswd\r"}
expect "Remove anonymous users" {send "Y\r"}
expect "Disallow root login remotely" {send "Y\r"}
expect "database and access" {send "Y\r"}
expect "Reload privilege tables" {send "Y\r"}
spawn mysql -u root -p
expect "Enter password" {send "$mysqlpasswd\r"}
expect "mysql" {send "create database wordpress_db;\r"}
expect "mysql" {send "exit\r"}
EOF


}

install_nginx(){

    green "==============="
    green "   安装nginx"
    green "==============="
    sleep 1
    yum install -y libtool perl-core zlib-devel gcc wget pcre* unzip
    wget https://www.openssl.org/source/openssl-1.1.1a.tar.gz
    tar xzvf openssl-1.1.1a.tar.gz
    
    mkdir /etc/nginx
    mkdir /etc/nginx/ssl
    mkdir /etc/nginx/conf.d
    wget https://nginx.org/download/nginx-1.15.8.tar.gz
    tar xf nginx-1.15.8.tar.gz && rm nginx-1.15.8.tar.gz
    cd nginx-1.15.8
    ./configure --prefix=/etc/nginx --with-openssl=../openssl-1.1.1a --with-openssl-opt='enable-tls1_3' --with-http_v2_module --with-http_ssl_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_sub_module --with-stream --with-stream_ssl_module
    make && make install
    if [ `yum list installed | grep nginx | wc -l` -ne 0 ]; then
    	green "【checked】 nginx安装成功"
	echo
	echo
	sleep 1
    fi

    green "=========="
    green " 输入域名，例如jiasu.ga"
    green "=========="
    read domain
    
cat > /etc/nginx/nginx.conf <<-EOF
user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
EOF

cat > /etc/nginx/conf.d/default.conf<<-EOF
server {
    listen       80;
    server_name  $domain;
    root /etc/nginx/html;
    index index.php index.html index.htm;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /etc/nginx/html;
    }
}
EOF

    /etc/nginx/sbin/nginx

while :
do
green "===================================="
yellow "开启网站https需要域名已经解析到本VPS"
green "是否开启https？是：输入1，否：输入0"
green "===================================="
read ifhttps
if [ "$ifhttps" = "1" ]; then
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh  --issue  -d $domain -d *.$domain --webroot /usr/share/nginx/html/
    ~/.acme.sh/acme.sh  --installcert  -d  $domain  -d  *.$domain \
        --key-file   /etc/nginx/ssl/$domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer \
        --reloadcmd  "service nginx force-reload"
	
cat > /etc/nginx/conf.d/default.conf<<-EOF
server { 
    listen       80;
    server_name  $domain www.$domain;
    rewrite ^(.*)$  https://\$host\$1 permanent; 
}
server {
    listen 443 ssl http2;
    server_name $domain www.$domain;
    root /usr/share/nginx/html;
    index index.php index.html;
    ssl_certificate /etc/nginx/ssl/fullchain.cer; 
    ssl_certificate_key /etc/nginx/ssl/$domain.key;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security "max-age=31536000";
    access_log /var/log/nginx/hostscube.log combined;
    location ~ \.php$ {
    	fastcgi_pass 127.0.0.1:9000;
    	fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    	include fastcgi_params;
    }
    location / {
       try_files \$uri \$uri/ /index.php?\$args;
    }
}
EOF

    break
elif [ "$ifhttps" = "0" ]; then

cat > /etc/nginx/conf.d/default.conf<<-EOF
server {
    listen       80;
    server_name  localhost;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
    location ~ \.php$ {
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }
}
EOF

    break
else
    red "输入字符不正确，请重新输入"
    sleep 1
    continue
fi
done
}

config_php(){

    green "===================="
    green "  配置php和php-fpm"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/;" /etc/php.ini
    sed -i "s/user = apache/user = nginx/;s/group = apache/group = nginx/;s/pm.start_servers = 5/pm.start_servers = 3/;s/pm.min_spare_servers = 5/pm.min_spare_servers = 3/;s/pm.max_spare_servers = 35/pm.max_spare_servers = 8/;" /etc/php-fpm.d/www.conf
    systemctl restart php-fpm.service
    systemctl restart nginx.service

}

install_wp(){

    green "===================="
    green "   安装wordpress"
    green "===================="
    sleep 1
    cd /usr/share/nginx/html
    wget https://cn.wordpress.org/wordpress-5.0.3-zh_CN.zip
    unzip wordpress-5.0.3-zh_CN.zip
    mv wordpress/* ./
    cp wp-config-sample.php wp-config.php
    green "===================="
    green "   配置wordpress"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/database_name_here/wordpress_db/;s/username_here/root/;s/password_here/$mysqlpasswd/;" /usr/share/nginx/html/wp-config.php
    echo "define('FS_METHOD', "direct");" >> /usr/share/nginx/html/wp-config.php
    chown -R nginx /usr/share/nginx/html
    green "==========================================================="
    green " WordPress服务端配置已完成，请打开浏览器访问服务器进行前台配置"
    yellow " 请保存好mysql数据库密码"
    green " 用户名：root  密码：$mysqlpasswd"
    green "==========================================================="
}

uninstall_wp(){
    red "============================================="
    red "你的wordpress数据将全部丢失！！你确定要卸载吗？"
    read -s -n1 -p "按回车键开始卸载，按ctrl+c取消"
    yum remove -y php70w php70w-mysql php70w-gd php70w-xml php70w-fpm mysql-server nginx
    rm -rf /usr/share/nginx/html/*
    green "=========="
    green " 卸载完成"
    green "=========="
}

start_menu(){
    clear
    green "======================================="
    green " 介绍：适用于CentOS7，一键安装wordpress"
    green " 作者：atrandys"
    green " 网站：www.atrandys.com"
    green " Youtube：atrandys"
    green "======================================="
    green "1. 一键安装wordpress"
    red "2. 卸载wordpress"
    yellow "0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
	install_php7
    	install_mysql
    	install_nginx
	config_php
    	install_wp
	;;
	2)
	uninstall_wp
	;;
	0)
	exit 1
	;;
	*)
	clear
	echo "请输入正确数字"
	sleep 2s
	start_menu
	;;
    esac
}

start_menu
