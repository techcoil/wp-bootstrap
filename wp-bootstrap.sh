#!/usr/bin/env bash

echo "Enter the name of the project directory: "
read name

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
echo "Host: "
read db_host

echo "User: "
read db_user

echo "Pass (hidden): "
read -s db_pass

echo "Schema name: "
read db_name

echo "Database Table Prefix: "
read db_prefix


function create_env_file {
	echo "; MySQL Config" > $1
	echo "db_host=$2" >> $1
	echo "db_user=$3" >> $1
	echo "db_pass=$4" >> $1
	echo "db_name=$5" >> $1
}

create_env_file "../.env.example"
create_env_file "../.env" $db_host $db_user $db_pass $db_name

wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_pass --dbhost=$db_host --dbprefix=$db_prefix --dbcharset=utf8mb4 --dbcollate=utf8mb4_general_ci

read -r -d '' env_func <<- DotEnvFunc



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
DotEnvFunc

mv wp-config.php ../wp-config.php
echo "$env_func" >> ../wp-config.php


function const_env {
        sed -i.bak "s/\(^define[\(] \\'$1\\', \)\\'.*\\'/\\1env('$2')/g" $3
}

const_env DB_PASSWORD db_pass ../wp-config.php
const_env DB_NAME db_name ../wp-config.php
const_env DB_USER db_user ../wp-config.php
const_env DB_HOST db_host ../wp-config.php

rm ../wp-config.php.bak

echo "Now, Initialing database"
echo "Site URL: "
read site_url

echo "Site Title: "
read title

echo "Admin Username: "
read user

echo "Admin Email: "
read admin_email

echo "Admin Password (hidden): "
read -s admin_pass

wp db create
wp core install --url=$site_url --title=$title --admin_user=$user --admin_email=$admin_email --admin_password=$admin_pass
