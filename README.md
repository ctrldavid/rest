rest
====

apt-get update
apt-get install git

mkdir tmp
cd tmp
wget http://nodejs.org/dist/v0.10.20/node-v0.10.20-linux-x64.tar.gz
tar -xzf node-v0.10.20-linux-x64.tar.gz

ln -s ~/tmp/node-v0.10.20-linux-x64/bin/node /usr/sbin/node
ln -s ~/tmp/node-v0.10.20-linux-x64/bin/npm /usr/sbin/npm

npm install -g coffee-script

git clone git@github.com:ctrldavid/rest.git

