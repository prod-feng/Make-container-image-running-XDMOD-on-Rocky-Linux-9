# Make-container-image-running-XDMOD-on-Rocky-Linux-9
Make container image running XDMOD on Rocky Linux 9, Singularity and apptainer. 

Using sandbox to make it more versatile and easy to be tuned to diffrent systems.

### singularity-ce version 4.3.7-1.el9, Rocky 9. XDMOD 11.0.3-2.

### N.B. version incompatibility:
singularity-ce 4.5 does not work with "Bootstrap: yum". The error message you get is(should be a bug somewhere):
```
FATAL:   While performing build: conveyor failed to get: while generating yum config: while creating /tmp/build-temp-3875677088/rootfs/etc/bootstrap-yum.conf: openat /etc/bootstrap-yum.conf: path escapes from parent
```

If you switch to bootstrap from Docker, then the sandbox can work, but at the final SIF building stage, it will fail(bug? to improvement for DOCKER bootstrap):

```
FATAL:   While performing build: packer failed to pack: while inserting base environment: build: failed to make environment symlinks: symlinkat /.singularity.d/runscript singularity: file exists
```

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
dnf install php php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mcrypt php-mbstring php-curl php-xml php-pear php-bcmath php-json php-pecl-apcu fuse-common squashfuse fuse-overlayfs kernel-modules-core sudo procps tzdata vim-enhanced vim-minimal -y --allowerasing


# Install XDMOD
dnf install https://github.com/ubccr/xdmod/releases/download/v11.0.3-2/xdmod-11.0.3-2.el8.noarch.rpm


# Copy and modify the httpd conf for XDMOD
cp /usr/share/xdmod/templates/apache.conf  /etc/httpd/conf.d/xdmod.conf 
```

For the /etc/httpd/conf.d/ssl.conf , and the new /etc/httpd/conf.d/xdmod.conf 
 change the listen port to a high number, which a regular user can use on the host server and also on the instance of the container image, e.g.:
 
```
Listen 4430 https  (ssl.conf)

-------------------

<VirtualHost *:4430> (xdmod.conf )
    # The ServerName and ServerAdmin parameters should be updated.
    ServerName x.x.x.x (xdmod.conf, compatible to your server)
```


The XDMOD does not support MYSQL 8 very well. So we will use Mariadb10 instead:

```
yum install mariadb
```

Since we can not run systemctl to manage mariadb service,  we will take care of its initializtion later.

NB: the container instance does not support systemd service. So we will have to prepare our own startup script to do all these things, like start httpd service, start mysql db,etc.

Prepare a script as a runscript for the container image, save it in /usr/binrun-xdmod

```
Singularity> cat /usr/bin/run-xdmod 
#!/bin/bash
#Startup script for the XDMOD image
#Called from rockylinux9-xdmod.def
#
#Start httpd
httpd -k start
#
#Start PHP-FPM service
/usr/sbin/php-fpm --nodaemonize &
#
#Start Mariadb 
sudo -u mysql mysqld  --skip-networking &
```

Change this script to be excutable:

```
chmod a+x /usr/bin/run-xdmod
```

This script will be called in "rockylinux9-xdmod.def" when you build the final image:

```
exec /usr/bin/run-xdmod "$@"
```

### Finnaly run "xdmod-setup" to configure the XDMOD database.

You do not need to setup everything, but most important part is the database and tables.

Inside the sandbox instance:
```
xdmod-setup


# Or if you have already configured XDMOD, them copy these files to /etc/xdmod folder.

portal_settings.ini
resource_specs.json
resources.json
```
## 3) Make the final image file using the rocklinux9-xdmod.def

Now build the image:

```
singularity build --fakeroot  rocky9-sandbox-xdmod.sif rocky9-xdmod.def
```

## 4) Start and initialize the image


Before start the image, setup a work folder to run XDMOD, to save the log files, and most importantly where to store the Mariadb database files. E.g., 

```
mkdir /tmp/test-xdmod/var/log
mkdir /tmp/test-xdmod/run
mkdir /tmp/test-xdmod/var/lib

```
The /tmp/test-xdmod/var/lib will be owned by user "mysql" inside the image instance, mapped to the Subuid/Subgid later by the "run-xdmod" script.

Now start:
```
singularity  instance start --fakeroot -B /tmp/test-xdmod/var/log:/var/log -B /tmp/test-xdmod/run:/run -B /tmp/test-xdmod/var/lib:/var/lib /tmp/rocky9-xdmod-mariadb.sif myxdmod
```

Still we wil need final touch:

```
#Get into the instance
singularity shell instance://myxdmod

# Initialize Mariadb data files(without them mariadb will fail):
mariadb-install-db --user=mysql  --basedir=/usr --datadir=/var/lib/mysql


#re-start mariadb. (only this time,it is not needed anymore later)
sudo -u mysql mysqld  --skip-networking &
```

Now you can start "xdmod-shredder" and "xdmod-ingestor".


There are many more things you can tune again from the SANDBOX, and then rebuild the image.


