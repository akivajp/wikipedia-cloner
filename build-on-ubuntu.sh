#!/bin/bash

LANGUAGE_CODE="ja"

MEDIAWIKI_WIKI_NAME="Wikipedia"
MEDIAWIKI_ADMIN_USERNAME="Admin"
MEDIAWIKI_ADMIN_PASS="WikipediaAdmin"
MEDIAWIKI_DB_USER="wikiuser"
MEDIAWIKI_DB_PASS="wikipass"

MEDIAWIKI_MAJOR_VERSION="1.37"
MEDIAWIKI_VERSION="1.37.4"

MEDIAWIKI_BASENAME="mediawiki-${MEDIAWIKI_VERSION}"
MEDIAWIKI_ARCHIVE="${MEDIAWIKI_BASENAME}.tar.gz"
MEDIAWIKI_ARCHIVE_URL="https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_MAJOR_VERSION}/${MEDIAWIKI_ARCHIVE}"

YELLOW="\033[33m"
CLEAR="\033[0m"
show-exec() {
    timestamp=$(date "+%Y/%m/%d %H:%M:%S")
    echo -e "${YELLOW}[exec at ${timestamp}] $@${CLEAR}"
    eval "$@"
}

set -eu

export DEBIAN_FRONTEND="noninteractive"

install-packages() {
    show-exec apt-get update

    # デバッグ用途
    show-exec apt-get install -y neovim
    show-exec apt-get install -y iputils-ping

    # 必要パッケージのインストール
    show-exec apt-get install -y git
    show-exec apt-get install -y apache2
    show-exec apt-get install -y libapache2-mod-php
    show-exec apt-get install -y php-intl php-mbstring php-xml
    show-exec apt-get install -y php-mysql
    show-exec apt-get install -y php-apcu php-imagick php-gd
    show-exec apt-get install -y mariadb-server
    show-exec apt-get install -y wget
}

if [ ! -f /var/www/html/w/LocalSettings.php ]; then
    install-packages
fi

# データベースの起動
if service mysql status > /dev/null; then
    :
    #show-exec service mysql restart
else
    show-exec service mysql start
fi

# MediaWikiの利用準備
if [ ! -f /var/www/html/w/LocalSettings.php ]; then
    show-exec cd /var/www/html
    show-exec wget -c ${MEDIAWIKI_ARCHIVE_URL}
    show-exec tar zxvf ${MEDIAWIKI_ARCHIVE}
    if [ -d w ]; then
        show-exec unlink w
    fi
    show-exec ln -s ${MEDIAWIKI_BASENAME} w
fi

# MediaWikiの初期設定
if [ -f /var/www/html/index.html ]; then
    show-exec cd /var/www/html
    show-exec rm index.html
fi
show-exec cd /var/www/html/w
if [ -f LocalSettings.php ]; then
    show-exec rm LocalSettings.php
fi
show-exec php maintenance/install.php \
    ${MEDIAWIKI_WIKI_NAME} \
    ${MEDIAWIKI_ADMIN_USERNAME} \
    --pass ${MEDIAWIKI_ADMIN_PASS} \
    --dbuser ${MEDIAWIKI_DB_USER} \
    --dbpass ${MEDIAWIKI_DB_PASS} \
    --lang ${LANGUAGE_CODE} \
    --installdbuser root \
    --scriptpath /w \

show-exec sed -i -Ee "'s/^(\\\$wgServer\s*=).*$/#\\0\\n\1 WebRequest::detectServer();/'" LocalSettings.php
show-exec tee -a LocalSettings.php << 'EOS'
$wgArticlePath = "/wiki/$1";

EOS

show-exec sed -i -Ee "'s/^(\s+AllowOverride\s+)None/#\\0\\n\1All/'" /etc/apache2/apache2.conf
show-exec tee /var/www/html/.htaccess << 'EOS'
RewriteEngine on

RewriteRule ^$ /w/index.php [L]
RewriteRule ^wiki/(.*)$ /w/index.php/$1 [L]

RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d

EOS

show-exec a2enmod rewrite
show-exec service apache2 restart
