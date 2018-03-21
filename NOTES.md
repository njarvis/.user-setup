-- Python versions and pew

sudo -H apt-get install build-essential zlib1g-dev libbz2-dev libssl-dev libreadline-dev libncurses5-dev libsqlite3-dev libgdbm-dev lib
db-dev libexpat-dev libpcap-dev liblzma-dev libpcre3-dev

curl -kL https://raw.github.com/saghul/pythonz/master/pythonz-install | bash

sudo -H pip install pew

LDFLAGS="-Wl,-rpath,$HOME/.pythonz/pythons/CPython-2.7.14/lib" pythonz install --reinstall --shared 2.7.14
LDFLAGS="-Wl,-rpath,$HOME/.pythonz/pythons/CPython-3.5.4/lib" pythonz install --reinstall --shared 3.5.4
LDFLAGS="-Wl,-rpath,$HOME/.pythonz/pythons/CPython-3.6.4/lib" pythonz install --shared 3.6.4

pew new -d -p $(pythonz locate 2.7.14) -i setuptools_scm -i tox -i invoke py27
pew new -d -p $(pythonz locate 3.5.4) -i setuptools_scm -i tox -i invoke py35
pew new -d -p $(pythonz locate 3.6.4) -i setuptools_scm -i tox -i invoke py36

-- tmux from source

sudo -H apt install automake libevent-dev pkg-config libutempter-dev libncurses-dev
git clone https://github.com/tmux/tmux.git
cd tmux
sh autogen.sh
./configure --enable-utempter && make
