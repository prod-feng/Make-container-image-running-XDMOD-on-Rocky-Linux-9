# Make-container-image-running-XDMOD-on-Rocky-Linux-9
Make container image running XDMOD on Rocky Linux 9, Singularity and apptainer

## 1) Make a sandbox using the rocklinux9-yum.def

```
mkdir /tmp/rocky-sandbox
cd /tmp/rocky-sandbox
singularity build --force --fakeroot --sandbox rocky9-sandbox/ /tmp/xdmod/rocky9-yum.def
```

## 2) Run the sandbox in writable mode to cutomize the OS.

```
#Start sandbox in writable mode
singularity shell --writable --fakeroot rocky9-sandbox/
#generate SSL key for HTTTPD
openssl req -newkey rsa:2048 -nodes -keyout /etc/pki/tls/private/localhost.key -x509 -days 3650 -out /etc/pki/tls/certs/localhost.crt
#Install PHP 7.4. XDMOD does not support PHP8+ yet.
dnf install https://rpms.remirepo.net/enterprise/remi-release-9.rpm -y
dnf module reset php
dnf module enable php:remi-7.4 -y
# Install other packages
dnf install php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mcrypt php-mbstring php-curl php-xml php-pear php-bcmath php-json php-pecl-apcu fuse-common squashfuse fuse-overlayfs kernel-modules-core -y --allowerasing
# Install XDMOD
dnf install https://github.com/ubccr/xdmod/releases/download/v11.0.3-2/xdmod-11.0.3-2.el8.noarch.rpm
# Copy and modify the httpd conf for XDMOD
cp /usr/share/xdmod/templates/apache.conf  /etc/httpd/conf.d/xdmod.conf 
```

For the /etc/httpd/conf.d/ssl.conf , and the new /etc/httpd/conf.d/xdmod.conf 
 change the listen port to a high number, that regular user can use on the host server and instance of the image, e.g.:
 
```
Listen 4430 https  (ssl.conf)
-------------------
<VirtualHost *:4430>
    # The ServerName and ServerAdmin parameters should be updated.
    ServerName x.x.x.x (xdmod.conf, compatible to your server)
```
## 3) Make the final image file using the rocklinux9-xdmod.def
