#!/bin/bash

# This runs as root on the server

RUBY_VERSION=2.0.0-p247
RVM_DIR='/usr/local/rvm'
RUBY_BIN_DIR="$RVM_DIR/rubies/ruby-$RUBY_VERSION/bin"
GEM_BIN_DIR="$RVM_DIR/gems/ruby-$RUBY_VERSION/bin"
CHEF_SOLO="$GEM_BIN_DIR/chef-solo"
PATH="$PATH:$RVM_DIR/bin:$RUBY_BIN_DIR:$GEM_BIN_DIR"

# Are we on a vanilla system?
if [ ! -f "$CHEF_SOLO" ]; then
	export DEBIAN_FRONTEND=noninteractive
	echo "\
==============================================================================
  UPGRADING SYSTEM
==============================================================================" &&
	apt-get update &&
	apt-get -o Dpkg::Options::="--force-confnew" \
		--force-yes -fuy dist-upgrade &&
	echo "\
==============================================================================
  INSTALLING RVM
==============================================================================" &&
	echo '* Installing requirements' &&
	apt-get --force-yes -fuy install build-essential openssl libreadline6 \
		libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev \
		libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev \
		libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison &&
	echo '* Compiling RVM' &&
	\curl -L https://get.rvm.io | bash -s stable --autolibs=enabled &&
	echo "\
==============================================================================
  INSTALLING RUBY
==============================================================================" &&
	echo "* Installing Ruby $RUBY_VERSION" &&
	rvm install $RUBY_VERSION \
		--with-openssl-dir=$HOME/.rvm/usr \
		--verify-downloads 1 &&
	echo '* Setting default Ruby version' &&
	source /usr/local/rvm/scripts/rvm &&
	rvm use --default $RUBY_VERSION &&
	echo "\
==============================================================================
  INSTALLING CHEF
==============================================================================" &&
	gem install --no-rdoc --no-ri chef
fi &&

echo "\
==============================================================================
  APPLYING CHEF RECIPES
==============================================================================" &&
"$CHEF_SOLO" -c solo.rb -j solo.json
