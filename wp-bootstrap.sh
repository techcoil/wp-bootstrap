#!/usr/bin/env bash

assets_dir="assets"

name=$1
dir_name=`echo "$name" | perl -pe 's/^(?:.*[^\w\-])?([\w\-]+)[^\w\-]?$/\1/'`


if [ -z $name ]; then
	echo "Usage: wp-bootstrap project_dir"
	exit 1
fi

if [ -d $name ]; then
	echo "Dir $name already exists"
	exit 1
fi

echo "Creating project dir"

mkdir $name
cd $name

mkdir public_html && cd public_html

wp core download

echo "Please enter database info"
echo "=========================="

read -p "Host: [localhost] " db_host
db_host=${db_host:-localhost}

read -p  "User: " db_user  

read -s -p "Pass (hidden): " db_pass
echo

read -p "Schema name: [$dir_name] " db_name
db_name=${db_name:-$dir_name}

read -p "Database Table Prefix: [wp_] " db_prefix
db_prefix=${db_prefix:-wp_}

function create_env_file {
  echo "WP_DEBUG=0" > $1
  echo "CONTENT_VERSION=1" >> $1
  echo "" >> $1
	echo "# MySQL Config" >> $1
	echo "WORDPRESS_DB_HOST=$2" >> $1
	echo "WORDPRESS_DB_USER=$3" >> $1
	echo "WORDPRESS_DB_PASS=$4" >> $1
	echo "WORDPRESS_DB_NAME=$5" >> $1
}

echo "Creating .env files"

create_env_file "../.env.example"
create_env_file "../.env" $db_host $db_user $db_pass $db_name


function create_wpcli_file {
	echo "path: public_html/" > $1
}

echo "Creating wp-cli file"

create_wpcli_file "../wp-cli.yml"


echo "wp config create --dbname=$db_name --dbuser=$db_user --dbpass=****** --dbhost=$db_host --dbprefix=$db_prefix"

wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_pass --dbhost=$db_host --dbprefix=$db_prefix

read -r -d '' env_func <<- DotEnvFunc
<?php 

function env(\$name, \$default = null) {
        static \$env_data;
        if(\$env_data === null) {
                \$env_data  = parse_ini_file( __DIR__ . '/.env');
        }

        if(!is_array(\$env_data)) {
                die('missing valid .env file');
        }

        if(array_key_exists(\$name, \$env_data)) {
                return \$env_data[\$name];
        } else if( (\$data = getenv(\$name)) !== false ) {
                return \$data;
        } else {
                return \$default;
        }
}

// END Tech.marketing Config Bootstrap code

DotEnvFunc

echo "Building wp-config"

echo "$env_func" > ../wp-config.php
tail -n +2 wp-config.php >> ../wp-config.php
rm -f wp-config.php


function const_env {
    if [ ! -z "$4" ]; then
        default=", ${4}"
    else
        default=""
    fi
        sed -i.bak "s/\(^define[\(] \\'$1\\', \)\\'.*\\'/\\1env('$2'${default})/g" $3
}

const_env DB_HOST WORDPRESS_DB_HOST ../wp-config.php
const_env DB_USER WORDPRESS_DB_USER ../wp-config.php
const_env DB_PASSWORD WORDPRESS_DB_PASS ../wp-config.php
const_env DB_NAME WORDPRESS_DB_NAME ../wp-config.php
const_env DB_COLLATE WORDPRESS_DB_COLLATE ../wp-config.php "'utf8mb4_general_ci'"
const_env DB_CHARSET WORDPRESS_DB_CHARSET ../wp-config.php "'utf8mb4'"

rm ../wp-config.php.bak

echo "Now, Initialing database"
read -p "Site URL: " site_url

read -p "Site Title: " title

read -p "Admin Username: " user

read -p "Admin Email: " admin_email

read -s -p "Admin Password (hidden): " admin_pass
echo

echo "/.env" > ../.gitignore
echo "/$assets_dir/uploads/*" >> ../.gitignore

mv wp-content $assets_dir

wp db create
echo "wp core install --url=$site_url --title=$title --skip-email --admin_user=$user --admin_email=$admin_email --admin_password=*****"
wp core install --url="$site_url" --title="$title" --skip-email --admin_user="$user" --admin_email="$admin_email" --admin_password="$admin_pass"
# Empty default WordPress blog description
wp option update blogdescription ''

read -r -d '' content_dir_php <<-PHPBlock
<?php

// BEGIN Tech.marketing Config Bootstrap code

if (!defined('WP_CLI')) {
        define('WP_CLI', false);
}


define('WP_DEBUG', boolval(env('WP_DEBUG', false)));
define('CLIENT_VERSION', env('CLIENT_VERSION', 1));

define ('WP_CONTENT_FOLDERNAME', '$assets_dir');

define ('WP_CONTENT_DIR', ABSPATH . WP_CONTENT_FOLDERNAME) ;

if(WP_CLI) {
        define('WP_SITEURL', '/');
        \$_SERVER['HTTP_HOST'] = '';
        \$_SERVER['SERVER_NAME'] = '';
        \$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
} else {
        define('WP_SITEURL', 'https://' . \$_SERVER['HTTP_HOST'] . '/');
}

define('WP_CONTENT_URL', WP_SITEURL . WP_CONTENT_FOLDERNAME);

PHPBlock

echo "$content_dir_php" > .tmp.php
tail -n +2 ../wp-config.php >> .tmp.php
mv .tmp.php ../wp-config.php

echo "Removing unneccessary themes"
wp theme list --format=csv | grep inactive | awk -F',' '{print $1}' | xargs wp theme uninstall

echo "Removing unneccessary plugins"
wp plugin list --format=csv | grep inactive | awk -F',' '{print $1}' | xargs wp plugin uninstall
