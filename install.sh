#!/bin/bash

# This runs as root on the server

chef_binary=/var/lib/gems/1.9.1/bin/chef-solo

# Are we on a vanilla system?
if ! test -f "$chef_binary"; then
    export DEBIAN_FRONTEND=noninteractive
    # Upgrade headlessly (this is only safe-ish on vanilla systems)
    apt-get update &&
    apt-get -o Dpkg::Options::="--force-confnew" \
        --force-yes -fuy dist-upgrade &&
    # Install Ruby and Chef
    apt-get install -y ruby-rvm &&
    apt-get install -y libyaml-dev &&
    rvm get stable &&
    rvm pkg install openssl &&
    rvm install 2.0.0 \
	--with-openssl-dir=$HOME/.rvm/usr \
	--verify-downloads 1 &&
    rvm use 2.0.0 &&
    gem install --no-rdoc --no-ri chef
fi &&

"$chef_binary" -c solo.rb -j solo.json
