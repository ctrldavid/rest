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

apt-get install build-essential

wget http://download.redis.io/releases/redis-2.6.16.tar.gz
tar xzf redis-2.6.16.tar.gz
cd redis-2.6.16
make

ln -s ~/tmp/redis-2.6.16/src/redis-server /usr/sbin/redis-server
ln -s ~/tmp/redis-2.6.16/src/redis-cli /usr/sbin/redis-cli
