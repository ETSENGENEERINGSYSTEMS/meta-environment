#!/bin/bash
SITE_DOMAIN="wordcamp.dev"
BASE_DIR=$( dirname $( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) ) )
PROVISION_DIR="$BASE_DIR/$SITE_DOMAIN/provision"
SITE_DIR="$BASE_DIR/$SITE_DOMAIN/public_html"
SVN_PLUGINS=( camptix-network-tools email-post-changes tagregator )
WPCLI_PLUGINS="akismet buddypress bbpress camptix-pagseguro camptix-payfast-gateway jetpack json-rest-api wp-multibyte-patch wordpress-importer"
WPCLI_THEMES="twentyten twentyeleven twentytwelve twentythirteen"

source $BASE_DIR/helper-functions.sh
wme_create_logs "$BASE_DIR/$SITE_DOMAIN/logs"
wme_svn_git_migration

if [ ! -L $SITE_DIR ]; then
	printf "\n#\n# Provisioning $SITE_DOMAIN\n#\n"

	# Don't overwrite existing databases if we're just migrating from SVN to Git
	if [[ ! $MIGRATED_TO_GIT ]]; then
		wme_import_database "wordcamp_dev" $PROVISION_DIR
	fi

	wme_clone_meta_repository $BASE_DIR
	wme_symlink_content_dir $BASE_DIR $SITE_DIR "wordcamp.org"

	# Setup WordPress
	wp core download --path=$SITE_DIR/wordpress --allow-root
	cp $PROVISION_DIR/wp-config.php $SITE_DIR

	# todo do svn checkouts? maybe create helper function too?
	for i in "${SVN_PLUGINS[@]}"
	do :
		echo "$i https://plugins.svn.wordpress.org/$i/trunk" >> $PROVISION_DIR/svn-externals.tmp
	done

	#todo svn propset svn:externals -F $PROVISION_DIR/svn-externals.tmp $SITE_DIR/wp-content/plugins
	#svn up $SITE_DIR/wp-content/plugins
	rm -f $PROVISION_DIR/svn-externals.tmp

	# todo submodule? probably not
	git clone https://github.com/Automattic/camptix.git $SITE_DIR/wp-content/plugins/camptix

	# Setup mu-plugin for local development
	cp $PROVISION_DIR/sandbox-functionality.php $SITE_DIR/wp-content/mu-plugins/

	# Install extra plugins and themes
	wp plugin install $WPCLI_PLUGINS --path=$SITE_DIR/wordpress --allow-root
	wp theme  install $WPCLI_THEMES  --path=$SITE_DIR/wordpress --allow-root

else
	printf "\n#\n# Updating $SITE_DOMAIN\n#\n"

	git -C $SITE_DIR fetch origin master:master

	# todo setup array / loop for these? helper function?
	svn up $SITE_DIR/wp-content/plugins/camptix-network-tools
	svn up $SITE_DIR/wp-content/plugins/email-post-changes
	svn up $SITE_DIR/wp-content/plugins/tagregator

	git -C $SITE_DIR/wp-content/plugins/camptix pull origin master

	wp core   update                --path=$SITE_DIR/wordpress --allow-root
	wp plugin update $WPCLI_PLUGINS --path=$SITE_DIR/wordpress --allow-root
	wp theme  update $WPCLI_THEMES  --path=$SITE_DIR/wordpress --allow-root

fi
