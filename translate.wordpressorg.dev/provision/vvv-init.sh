#!/bin/bash

echo -e "\nNote: translate.wordpressorg.dev is out of sync with production and cannot be provisioned or updated."
echo "See https://github.com/WordPress/meta-environment/issues/54 for details and updates."
exit

SITE_DOMAIN="translate.wordpressorg.dev"
BASE_DIR=$( dirname $( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) ) )
PROVISION_DIR="$BASE_DIR/$SITE_DOMAIN/provision"
SITE_DIR="$BASE_DIR/$SITE_DOMAIN/public_html"

source $BASE_DIR/helper-functions.sh
wme_create_logs "$BASE_DIR/$SITE_DOMAIN/logs"
wme_svn_git_migration $SITE_DIR

if [ ! -L $SITE_DIR ]; then
	printf "\n#\n# Provisioning $SITE_DOMAIN\n#\n"

	wme_clone_meta_repository $BASE_DIR
	wme_symlink_public_dir $BASE_DIR $SITE_DOMAIN "translate.wordpress.org"

	# Setup GlotPress, templates, and plugins
	git clone git://glotpress.git.wordpress.org/ $SITE_DIR/glotpress

	cd $SITE_DIR
	ln -sr $BASE_DIR/meta-repository/translate.wordpress.org/public_html/gp-templates gp-templates
	ln -sr $BASE_DIR/meta-repository/translate.wordpress.org/includes/gp-plugins      gp-plugins

	cp $PROVISION_DIR/gp-config.php $SITE_DIR

	# Ignore external dependencies and Meta Environment tweaks
	IGNORED_FILES=(
		/gp-templates
		/gp-plugins
		/gp-config.php
	)
	wme_create_gitignore $SITE_DIR

else
	printf "\n#\n# Updating $SITE_DOMAIN\n#\n"

	git -C $SITE_DIR pull origin master
	git -C $SITE_DIR/glotpress pull origin master

fi

# Pull global header/footer
wme_pull_wporg_global_header $SITE_DIR gp_head
wme_pull_wporg_global_footer $SITE_DIR
