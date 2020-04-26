#!/bin/bash
 
function blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
function bred(){
    echo -e "\033[31m\033[01m\033[05m$1\033[0m"
}
function byellow(){
    echo -e "\033[33m\033[01m\033[05m$1\033[0m"
}

#判断系统
check_os(){
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
if  [ -n "$(grep ' 8\.' /etc/redhat-release)" ] ;then
red "==============="
red " 仅支持CentOS7"
red "==============="
exit
fi
}

disable_selinux(){

    systemctl stop firewalld
    systemctl disable firewalld
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" != "SELINUX=disabled" ]; then
        semanage port -a -t http_port_t -p tcp 80
        semanage port -a -t http_port_t -p tcp 443
    fi
}

check_domain(){
	download_wp
	install_php7
    	install_mysql
    	install_nginx
	config_php
    	install_wp
}

install_php7(){

    green "==============="
    green " 1.安装必要软件"
    green "==============="
    sleep 1
    yum -y install epel-release
    sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
    yum -y install  unzip vim tcl expect curl socat
    echo
    echo
    green "=========="
    green "2.安装PHP7"
    green "=========="
    sleep 1
    rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
    yum -y install php70w php70w-mysql php70w-gd php70w-xml php70w-fpm
    service php-fpm start
    chkconfig php-fpm on
    if [ `yum list installed | grep php70 | wc -l` -ne 0 ]; then
        echo
    	green "【checked】 PHP7安装成功"
	echo
	echo
	sleep 2
	php_status=1
    fi
}

install_mysql(){

    green "==============="
    green "  3.安装MySQL"
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
    echo
    echo
    green "==============="
    green "  4.配置MySQL"
    green "==============="
    sleep 2
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
    echo
    echo
    green "==============="
    green "  5.安装nginx"
    green "==============="
    sleep 1
    rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
    yum install -y nginx
    systemctl enable nginx.service
    systemctl stop nginx.service
    rm -f /etc/nginx/conf.d/default.conf
    rm -f /etc/nginx/nginx.conf
    mkdir /etc/nginx/ssl
    if [ `yum list installed | grep nginx | wc -l` -ne 0 ]; then
    	echo
	green "【checked】 nginx安装成功"
	echo
	echo
	sleep 1
	mysql_status=1
    fi

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

}

config_php(){

    echo
    green "===================="
    green " 6.配置php和php-fpm"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/;" /etc/php.ini
    sed -i "s/pm.start_servers = 5/pm.start_servers = 3/;s/pm.min_spare_servers = 5/pm.min_spare_servers = 3/;s/pm.max_spare_servers = 35/pm.max_spare_servers = 8/;" /etc/php-fpm.d/www.conf
    systemctl restart php-fpm.service
    systemctl restart nginx.service

}


download_wp(){
    yum -y install  wget
}

install_wp(){

    green "==========================="
    green " WordPress环境已经安装完成"
    green " 数据库密码: $mysqlpasswd"
    green "==========================="
}


start_menu(){
    clear
    green "==============================="
    green " 介绍：一键安装wordpress环境"
    green " 作者：atrandys"
    green " 网站：www.atrandys.com"
    green " Youtube：Randy's 堡垒"
    green "==============================="
    green "1. 一键安装wordpress环境"
    yellow "0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
	check_os
	disable_selinux
        check_domain
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
