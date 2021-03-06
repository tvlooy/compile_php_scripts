#!/bin/bash

set -e

# Use a release version like 7.0.8 for a stable release
PHP_VERSION=7.1.0

TIMEZONE="Europe\/Brussels"
FPM_PORT=9071
FPM_USER=www-data
FPM_GROUP=www-data
APCU_VERSION=5.1.5

# Dependencies

apt-get update

# Dependencies for building
apt-get install -y \
    make \
    autoconf \
    gcc \
    bison \
    g++

# Dependencies for the selected extensions
apt-get install -y \
    libxml2-dev \
    libbz2-dev \
    libcurl4-openssl-dev \
    libltdl-dev \
    libpng12-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libxpm-dev \
    libimlib2-dev \
    libicu-dev \
    libreadline6-dev \
    libmcrypt-dev \
    libxslt1-dev \
    libssl-dev \
    libsystemd-dev

rm -rf /etc/php-${PHP_VERSION}
rm -rf /usr/local/php-${PHP_VERSION}

mkdir -p /etc/php-${PHP_VERSION}/conf.d
mkdir -p /etc/php-${PHP_VERSION}/{cli,fpm}/conf.d
mkdir /usr/local/php-${PHP_VERSION}

# Download

if [ ! -d php-src ]; then 
    git clone http://github.com/php/php-src.git
fi

cd php-src
git checkout PHP-${PHP_VERSION}

if [ -f Makefile ]; then
    make distclean
fi
git clean -xdf
./buildconf --force

CONFIGURE_STRING="--prefix=/usr/local/php-${PHP_VERSION} \
                  --enable-bcmath \
                  --with-bz2 \
                  --with-zlib \
                  --enable-zip \
                  --enable-calendar \
                  --enable-exif \
                  --enable-ftp \
                  --with-gettext \
                  --with-gd \
                  --with-jpeg-dir \
                  --with-png-dir \
                  --with-freetype-dir \
                  --with-xpm-dir \
                  --enable-mbstring \
                  --enable-mysqlnd \
                  --with-mysqli=mysqlnd \
                  --with-pdo-mysql=mysqlnd \
                  --with-openssl \
                  --enable-intl \
                  --enable-soap \
                  --with-readline \
                  --with-curl \
                  --with-mcrypt \
                  --with-xsl \
                  --disable-cgi"

# Options for development
CONFIGURE_STRING="$CONFIGURE_STRING \
                  --enable-debug"

# Build FPM

./configure \
    $CONFIGURE_STRING \
    --with-config-file-path=/etc/php-${PHP_VERSION}/fpm \
    --with-config-file-scan-dir=/etc/php-${PHP_VERSION}/fpm/conf.d \
    --disable-cli \
    --enable-fpm \
    --with-fpm-systemd \
    --with-fpm-user=${FPM_USER} \
    --with-fpm-group=${FPM_GROUP}

make -j2
make install

# Install config files

cp php.ini-production /etc/php-${PHP_VERSION}/fpm/php.ini
sed -i "s/;date.timezone =.*/date.timezone = ${TIMEZONE}/" /etc/php-${PHP_VERSION}/fpm/php.ini

cp sapi/fpm/php-fpm.conf.in /etc/php-${PHP_VERSION}/fpm/php-fpm.conf
sed -i "s#^include=.*/#include=/etc/php-${PHP_VERSION}/fpm/pool.d/#" /etc/php-${PHP_VERSION}/fpm/php-fpm.conf

mkdir /etc/php-${PHP_VERSION}/fpm/pool.d/
cp /usr/local/php-${PHP_VERSION}/etc/php-fpm.d/www.conf.default /etc/php-${PHP_VERSION}/fpm/pool.d/www.conf
sed -i "s/listen = 127.0.0.1:9000/listen = 127.0.0.1:${FPM_PORT}/g" /etc/php-${PHP_VERSION}/fpm/pool.d/www.conf

cat << EOF >/etc/systemd/system/php-${PHP_VERSION}-fpm.service
[Unit]
Description=The PHP FastCGI Process Manager
After=syslog.target network.target

[Service]
Type=notify
PIDFile=/var/run/php-${PHP_VERSION}-fpm.pid
ExecStart=/usr/local/php-${PHP_VERSION}/sbin/php-fpm --nodaemonize --fpm-config /etc/php-${PHP_VERSION}/fpm/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable php-${PHP_VERSION}-fpm
systemctl start php-${PHP_VERSION}-fpm

# Cleanup

make distclean
./buildconf --force

# Build CLI

./configure \
    $CONFIGURE_STRING \
    --enable-pcntl \
    --with-config-file-path=/etc/php-${PHP_VERSION}/cli \
    --with-config-file-scan-dir=/etc/php-${PHP_VERSION}/cli/conf.d

make -j2
make install

# Install config files

cp php.ini-production /etc/php-${PHP_VERSION}/cli/php.ini
sed -i "s/;date.timezone =.*/date.timezone = ${TIMEZONE}/" /etc/php-${PHP_VERSION}/cli/php.ini

# Build extensions

cd ..

PATH=/usr/local/php-${PHP_VERSION}/bin:/usr/local/php-${PHP_VERSION}/sbin:$PATH

# opcache
echo "zend_extension=opcache.so" > /etc/php-${PHP_VERSION}/conf.d/opcache.ini
ln -s /etc/php-${PHP_VERSION}/conf.d/opcache.ini /etc/php-${PHP_VERSION}/cli/conf.d/opcache.ini
ln -s /etc/php-${PHP_VERSION}/conf.d/opcache.ini /etc/php-${PHP_VERSION}/fpm/conf.d/opcache.ini

# apcu
printf "\n" | pecl install apcu-${APCU_VERSION}
echo "extension=apcu.so" > /etc/php-${PHP_VERSION}/conf.d/apcu.ini
ln -s /etc/php-${PHP_VERSION}/conf.d/apcu.ini /etc/php-${PHP_VERSION}/cli/conf.d/apcu.ini
ln -s /etc/php-${PHP_VERSION}/conf.d/apcu.ini /etc/php-${PHP_VERSION}/fpm/conf.d/apcu.ini

# Symlink PHP into the path
ln -sf /usr/local/php-${PHP_VERSION}/bin/php /usr/bin/php-${PHP_VERSION}

# Ready

echo "Don't forget to run 'make test'."

