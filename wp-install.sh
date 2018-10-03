#!/bin/bash
yum -y install  wget unzip vim tcl expect expect-devel
echo "安装PHP7"
rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum -y install php70w php70w-mysql php70w-gd php70w-xml php70w-fpm
service php-fpm start
chkconfig php-fpm on
echo "安装mysql"
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
rpm -ivh mysql-community-release-el7-5.noarch.rpm
yum -y install mysql-server
chkconfig mysqld on
service mysqld start
echo "配置mysql"
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
EOF
echo -e "\ny\n$mysqlpasswd\n$mysqlpasswd\ny\ny\ny\ny\n" | mysql_secure_installation
echo -e "$mysqlpasswd\ncreate database wordpress_db;\nexit\n" | mysql -u root -p 
rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum install -y nginx
systemctl enable nginx.service
rm -f /etc/nginx/conf.d/default.conf
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
service nginx start
cd /usr/share/nginx/html
wget https://cn.wordpress.org/wordpress-4.9.4-zh_CN.zip
unzip wordpress-4.9.4-zh_CN.zip
mv wordpress/* ./
cp wp-config-sample.php wp-config.php
vim wp-config.php
echo "define('FS_METHOD', "direct");" >> /usr/share/nginx/html/wp-config.php
chown -R nginx /usr/share/nginx/html
vim /etc/nginx/nginx.conf
vim /etc/php.ini
vim /etc/php-fpm.d/www.conf


