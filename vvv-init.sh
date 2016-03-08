# Provision WordPress Multisite stable as a base for the Activist Network Platform

# Make a database, if we don't already have one
echo -e "\nCreating database 'wordpress_anp' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS wordpress_anp"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON wordpress_anp.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
if [[ ! -d /srv/log/wordpress-anp ]]; then
    mkdir /srv/log/wordpress-anp
fi
touch /srv/log/wordpress-anp/error.log
touch /srv/log/wordpress-anp/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -d /srv/www/wordpress-anp ]]; then

    mkdir /srv/www/wordpress-anp
    cd /srv/www/wordpress-anp

    echo "Downloading WordPress Multisite (Subdomain Stable) for Activist Network Platform, see http://glocal.coop/activist-network-platform/"
    wp core download --allow-root

    echo "Configuring WordPress Multisite Subdomain Stable..."
    wp core config --dbname=wordpress_anp --dbuser=wp --dbpass=wp --extra-php --allow-root <<PHP
// Match any requests made via xip.io.
if ( isset( \$_SERVER['HTTP_HOST'] ) && preg_match('/^(wordpress-anp.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(.xip.io)\z/', \$_SERVER['HTTP_HOST'] ) ) {
    define( 'WP_HOME', 'http://' . \$_SERVER['HTTP_HOST'] );
    define( 'WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST'] );
}

define( 'WP_DEBUG'    , true );
define( 'WP_DEBUG_LOG', true );
PHP
    echo "Installing WordPress Multisite (Subdomain Stable) for Activist Network Platform..."
    wp core multisite-install --allow-root --url=wordpress-anp.dev --subdomains --title="Activist Network Platform (Subdomain) localDev" --admin_name=admin --admin_email="anp.admin@local.dev" --admin_password="password" --allow-root

    # Create site admin
    wp user create "siteadmin" "admin@local.dev" --user_pass="password"

    # Create sites 2-5
    wp site create --allow-root --slug=site2 --title="ANP Subsite (2)" --email="admin@local.dev"
    wp site create --allow-root --slug=site3 --title="ANP Subsite (3)" --email="admin@local.dev"
    wp site create --allow-root --slug=site4 --title="ANP Subsite (4)" --email="admin@local.dev"
    wp site create --allow-root --slug=site5 --title="ANP Subsite (5)" --email="admin@local.dev"

    echo "Installing Activist Network Platform pre-configuration using Composer..."
    git clone https://github.com/glocalcoop/activist-network-composer.git anp-composer
    mv anp-composer/composer.{json,lock} ./
    rm -rf anp-composer
    composer install

    wp plugin update --all
    wp theme update --all

    # Configure ANP's default multisite settings
    wp theme activate anp-network-main --url=wordpress-anp.dev
    wp theme enable anp-network-partner --network
    wp theme enable anp-network-subsite --network
    for url in `wp site list --field=url | grep "http://site[0-9]*"`
    do
        wp theme activate anp-network-subsite --url="$url" --quiet
    done

    # Create subsite users
    wp user create subscriber1 "subscriber1@local.dev" --role=subscriber --user_pass=password --url=site2.wordpress-anp.dev
    wp user create subscriber2 "subscriber2@local.dev" --role=subscriber --user_pass=password --url=site2.wordpress-anp.dev

else

    echo "Updating WordPress Multisite (Subdomain Stable) for Activist Network Platform..."
    cd /srv/www/wordpress-anp
    wp core upgrade --allow-root

fi
