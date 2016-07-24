#!/bin/bash

set -e

# This PHP version needs an older bison
PATH=/opt/bison-2.3-installed/bin:$PATH
# This PHP version also needs an older autoconf
PATH=/opt/autoconf-2.13-installed/bin:$PATH
# This PHP version also needs an older flex
PATH=/opt/flex-2.5.4-installed/bin:$PATH

# Use a release version like 7.0.8 for a stable release
PHP_VERSION=5.1

# Dependencies

apt-get update

# Dependencies for building
apt-get install -y \
    make \
    gcc \
    g++

rm -rf /etc/php-${PHP_VERSION}
rm -rf /usr/local/php-${PHP_VERSION}

mkdir -p /etc/php-${PHP_VERSION}/conf.d
mkdir -p /etc/php-${PHP_VERSION}/cli/conf.d
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

CONFIGURE_STRING="--prefix=/usr/local/php-${PHP_VERSION}"

# Options for development
CONFIGURE_STRING="$CONFIGURE_STRING \
                  --enable-debug"

# Build CLI

./configure \
    $CONFIGURE_STRING \
    --enable-pcntl \
    --disable-dom \
    --disable-simplexml \
    --without-pear \
    --with-config-file-path=/etc/php-${PHP_VERSION}/cli \
    --with-config-file-scan-dir=/etc/php-${PHP_VERSION}/cli/conf.d

make -j2
make install

cd ..

PATH=/usr/local/php-${PHP_VERSION}/bin:/usr/local/php-${PHP_VERSION}/sbin:$PATH

# Symlink PHP into the path
ln -sf /usr/local/php-${PHP_VERSION}/bin/php /usr/bin/php-${PHP_VERSION}

# Ready

echo "Don't forget to run 'make test'."

