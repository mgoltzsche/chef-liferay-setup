#!/bin/bash

# This runs as root on the server

RUBY_VERSION=2.0.0
CHEF_BINARY=/var/lib/gems/$RUBY_VERSION/bin/chef-solo

# Are we on a vanilla system?
if ! test -f "$CHEF_BINARY"; then
    echo 'CONFIGURING VANILLA SYSTEM'
    export DEBIAN_FRONTEND=noninteractive
    echo '
##############################################################################
# UPGRADING SYSTEM ###########################################################
##############################################################################' &&
    # Upgrade headlessly (this is only safe-ish on vanilla systems)
    apt-get update &&
    apt-get -o Dpkg::Options::="--force-confnew" \
        --force-yes -fuy dist-upgrade &&
    echo '
##############################################################################
# INSTALLING RVM #############################################################
##############################################################################' &&
    apt-get --force-yes -fuy install build-essential openssl libreadline6 \
	libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev \
	libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev \
	libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison &&
    curl -L https://get.rvm.io | bash -s stable --rails --autolibs=enabled &&
    source /usr/local/rvm/scripts/rvm &&
    echo '
##############################################################################
# INSTALLING RUBY 2.0.0 ######################################################
##############################################################################' &&
    rvm install $RUBY_VERSION \
	--with-openssl-dir=$HOME/.rvm/usr \
	--verify-downloads 1 &&
    rvm use --default $RUBY_VERSION &&
    echo '
##############################################################################
# INSTALLING CHEF ############################################################
##############################################################################' &&
    gem install --no-rdoc --no-ri chef
fi &&

echo '
##############################################################################
# APPLYING CHEF RECIPES ######################################################
##############################################################################' &&
"$CHEF_BINARY" -c solo.rb -j solo.json
