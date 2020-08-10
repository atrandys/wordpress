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

yum -y install net-tools socat
Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
if [ -n "$Port80" ]; then
    process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
    red "==========================================================="
    red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
    red "==========================================================="
    exit 1
fi
if [ -n "$Port443" ]; then
    process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
    red "============================================================="
    red "检测到443端口被占用，占用进程为：${process443}，本次安装结束"
    red "============================================================="
    exit 1
fi
if [ -f "/etc/selinux/config" ]; then
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" != "SELINUX=disabled" ]; then
        green "检测到SELinux开启状态，添加放行80/443端口规则"
        yum install -y policycoreutils-python >/dev/null 2>&1
        semanage port -m -t http_port_t -p tcp 80
        semanage port -m -t http_port_t -p tcp 443
    fi
fi
firewall_status=`systemctl status firewalld | grep "Active: active"`
if [ -n "$firewall_status" ]; then
    green "检测到firewalld开启状态，添加放行80/443端口规则"
    firewall-cmd --zone=public --add-port=80/tcp --permanent
    firewall-cmd --zone=public --add-port=443/tcp --permanent
    firewall-cmd --reload
fi
}

check_domain(){
    green "======================="
    yellow "请输入绑定到本VPS的域名"
    green "======================="
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
    	green "============================="
	    green "域名解析正常，开始安装wordpress"
	    green "============================="
	    sleep 1s
	    download_wp
	    install_php7
        install_mysql
        install_nginx
	    config_php
        install_wp
    else
        red "================================"
	    red "域名解析地址与本VPS IP地址不一致"
	    red "本次安装失败，请确保域名解析正常"
	    red "================================"
	    exit 1
    fi
}

install_php7(){

    green "==============="
    green " 1.安装必要软件"
    green "==============="
    sleep 1
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    wget https://rpms.remirepo.net/enterprise/remi-release-7.rpm
    rpm -Uvh remi-release-7.rpm epel-release-latest-7.noarch.rpm
    #sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
    yum -y install  unzip vim tcl expect curl socat
    echo
    echo
    green "============"
    green "2.安装PHP7.4"
    green "============"
    sleep 1
    yum -y install php74 php74-php-gd  php74-php-pdo php74-php-mbstring php74-php-cli php74-php-fpm php74-php-mysqlnd php74-php-xml
    service php74-php-fpm start
    chkconfig php74-php-fpm on
    if [ `yum list installed | grep php74 | wc -l` -ne 0 ]; then
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
    #wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
	wget https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm
    rpm -ivh mysql80-community-release-el7-3.noarch.rpm
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
    originpasswd=`cat /var/log/mysqld.log | grep password | head -1 | rev  | cut -d ' ' -f 1 | rev`
    mysqlpasswd=`mkpasswd -l 18 -d 2 -c 3 -C 4 -s 5 | sed $'s/[\'\/\;\"\:]//g'`
cat > ~/.my.cnf <<EOT
[mysql]
user=root
password="$originpasswd"
EOT
    mysql  --connect-expired-password  -e "alter user 'root'@'localhost' identified by '$mysqlpasswd';"
    systemctl restart mysqld
    sleep 5s
cat > ~/.my.cnf <<EOT
[mysql]
user=root
password="$mysqlpasswd"
EOT
    mysql  --connect-expired-password  -e "create database wordpress_db;"


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

    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh  --issue  -d $your_domain  --standalone
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /etc/nginx/ssl/$your_domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer
	
cat > /etc/nginx/conf.d/default.conf<<-EOF
server {
    listen 80 default_server;
    server_name _;
    return 404;  
}
server {
    listen 443 ssl default_server;
    server_name _;
    ssl_certificate /etc/nginx/ssl/fullchain.cer; 
    ssl_certificate_key /etc/nginx/ssl/$your_domain.key;
    return 404;
}
server { 
    listen       80;
    server_name  $your_domain;
    rewrite ^(.*)$  https://\$host\$1 permanent; 
}
server {
    listen 443 ssl http2;
    server_name $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html;
    ssl_certificate /etc/nginx/ssl/fullchain.cer; 
    ssl_certificate_key /etc/nginx/ssl/$your_domain.key;
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

}

config_php(){

    echo
    green "===================="
    green " 6.配置php和php-fpm"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/;" /etc/opt/remi/php74/php.ini
    sed -i "s/pm.start_servers = 5/pm.start_servers = 3/;s/pm.min_spare_servers = 5/pm.min_spare_servers = 3/;s/pm.max_spare_servers = 35/pm.max_spare_servers = 8/;" /etc/opt/remi/php74/php-fpm.d/www.conf
    systemctl restart php74-php-fpm.service
    systemctl restart nginx.service
    ~/.acme.sh/acme.sh  --issue --force  -d $your_domain  --nginx
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /etc/nginx/ssl/$your_domain.key \
        --fullchain-file /etc/nginx/ssl/fullchain.cer \
	--reloadcmd  "systemctl restart nginx"	

}


download_wp(){

    yum -y install  wget
    mkdir /usr/share/wordpresstemp
    cd /usr/share/wordpresstemp/
    wget https://cn.wordpress.org/latest-zh_CN.zip
    if [ ! -f "/usr/share/wordpresstemp/latest-zh_CN.zip" ]; then
    	red "从cn官网下载wordpress失败，尝试从github下载……"
	wget https://github.com/atrandys/wordpress/raw/master/latest-zh_CN.zip    
    fi
    if [ ! -f "/usr/share/wordpresstemp/latest-zh_CN.zip" ]; then
	red "我它喵的从github下载wordpress也失败了，请尝试手动安装……"
	green "从wordpress官网下载包然后命名为latest-zh_CN.zip，新建目录/usr/share/wordpresstemp/，上传到此目录下即可"
	exit 1
    fi
}

install_wp(){

    green "===================="
    green "  7.安装wordpress"
    green "===================="
    echo
    echo
    sleep 1
    cd /usr/share/nginx/html
    mv /usr/share/wordpresstemp/latest-zh_CN.zip ./
    unzip latest-zh_CN.zip >/dev/null 2>&1
    mv wordpress/* ./
    cp wp-config-sample.php wp-config.php
    green "===================="
    green "  8.配置wordpress"
    green "===================="
    echo
    echo
    sleep 1
    sed -i "s/database_name_here/wordpress_db/;s/username_here/root/;s?password_here?$mysqlpasswd?;" /usr/share/nginx/html/wp-config.php
    echo "define('FS_METHOD', "direct");" >> /usr/share/nginx/html/wp-config.php
    chown -R nginx:root /usr/share/nginx/html/
    chmod -R 777 /usr/share/nginx/html/wp-content
    green "==========================================================="
    green " WordPress服务端配置已完成，请打开浏览器访问您的域名进行前台配置"
    green " 数据库密码等信息参考文件：/usr/share/nginx/html/wp-config.php"
    green "==========================================================="
}

uninstall_wp(){
    red "============================================="
    red "你的wordpress数据将全部丢失！！你确定要卸载吗？"
    read -s -n1 -p "按回车键开始卸载，按ctrl+c取消"
    yum remove -y php74 php74-php-gd  php74-php-pdo php74-php-mbstring php74-php-cli php74-php-fpm php74-php-mysqlnd mysql nginx
    rm -rf /usr/share/nginx/html/*
    rm -rf /var/lib/mysql	
    rm -rf /usr/lib64/mysql
    rm -rf /usr/share/mysql
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
    green " Youtube：Randy's 堡垒"
    green "======================================="
    green "1. 一键安装wordpress"
    red "2. 卸载wordpress"
    yellow "0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
	check_os
	disable_selinux
        check_domain
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
