#!/bin/bash
SITE_DOMAIN="wordcamp.dev"
BASE_DIR=$( dirname $( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) ) )
PROVISION_DIR="$BASE_DIR/$SITE_DOMAIN/provision"
SITE_DIR="$BASE_DIR/$SITE_DOMAIN/public_html"
SVN_PLUGINS=( camptix-network-tools email-post-changes tagregator )
WPCLI_PLUGINS=( akismet buddypress bbpress camptix-pagseguro camptix-payfast-gateway jetpack json-rest-api wp-multibyte-patch wordpress-importer )
WPCLI_THEMES=( twentyten twentyeleven twentytwelve twentythirteen )

source $BASE_DIR/helper-functions.sh
wme_create_logs "$BASE_DIR/$SITE_DOMAIN/logs"
wme_svn_git_migration $SITE_DIR

if [ ! -L $SITE_DIR ]; then
	printf "\n#\n# Provisioning $SITE_DOMAIN\n#\n"

	# Don't overwrite existing databases if we're just migrating from SVN to Git
	if [[ ! $MIGRATED_TO_GIT ]]; then
		wme_import_database "wordcamp_dev" $PROVISION_DIR
	fi

	wme_clone_meta_repository $BASE_DIR
	wme_symlink_public_dir $BASE_DIR $SITE_DOMAIN "wordcamp.org"

	# Setup WordPress
	wp core download --path=$SITE_DIR/wordpress --allow-root
	cp $PROVISION_DIR/wp-config.php $SITE_DIR

	for i in "${SVN_PLUGINS[@]}"
	do :
		svn co https://plugins.svn.wordpress.org/$i/trunk $SITE_DIR/wp-content/plugins/$i
	done

	git clone https://github.com/Automattic/camptix.git $SITE_DIR/wp-content/plugins/camptix

	# Setup mu-plugin for local development
	cp $PROVISION_DIR/sandbox-functionality.php $SITE_DIR/wp-content/mu-plugins/

	# Install extra plugins and themes
	wp plugin install ${WPCLI_PLUGINS[@]} --path=$SITE_DIR/wordpress --allow-root
	wp theme  install ${WPCLI_THEMES[@]}  --path=$SITE_DIR/wordpress --allow-root

	# Ignore external dependencies and Meta Environment tweaks
	IGNORED_FILES=(
		/wordpress
		/wp-content/mu-plugins/sandbox-functionality.php
		/wp-content/plugins/camptix
		/wp-config.php
	)
	IGNORED_FILES=( "${IGNORED_FILES[@]}" "${SVN_PLUGINS[@]}" "${WPCLI_PLUGINS[@]}" "${WPCLI_THEMES[@]}" )
	wme_create_gitignore $SITE_DIR

else
	printf "\n#\n# Updating $SITE_DOMAIN\n#\n"

	git -C $SITE_DIR fetch origin master:master
	# todo fatal: Refusing to fetch into current branch refs/heads/master of non-bare repository
	# appropriate to use `--update-head-ok`, or maybe misunderstanding the whole thing?

	for i in "${SVN_PLUGINS[@]}"
	do :
		svn up $SITE_DIR/wp-content/plugins/$i
	done

	git -C $SITE_DIR/wp-content/plugins/camptix fetch origin master:master

	wp core   update                     --path=$SITE_DIR/wordpress --allow-root
	wp plugin update ${WPCLI_PLUGINS[@]} --path=$SITE_DIR/wordpress --allow-root
	wp theme  update ${WPCLI_THEMES[@]}  --path=$SITE_DIR/wordpress --allow-root

fi
