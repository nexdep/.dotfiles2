#!/bin/bash

# these tools are supposed to be installed after the github setup ubuntu script

SCRIPT_USER="marco"
SCRIPT_HOME="/home/$SCRIPT_USER"
SCRIPT_REPOS="$SCRIPT_HOME/repos"

mkdir -p "$SCRIPT_REPOS"

# install numjuggler with uv in a separate virtualenv
uv tool install numjuggler --with setuptools --python 3.7

# download cdgs tools from repo
cd "$SCRIPT_REPOS" || exit
if [ -d "cdgs-tools" ]; then
  cd "cdgs-tools" || exit
  git pull origin main
  uv tool uninstall cdgs-tools
  uv clean
  uv tool install --python 3.12 .
else
  git clone git@github.com:marco-de-pietri/cdgs-tools.git
  cd "cdgs-tools" || exit
  uv tool install --python 3.12 .
fi

# download FLUNED-repo from github
cd "$SCRIPT_REPOS" || exit
if [ -d "FLUNED-repository" ]; then
  cd "FLUNED-repository" || exit
  git pull origin main
else
  git clone git@github.com:marco-de-pietri/FLUNED-repository.git
fi

# download FLUNED-SL-repo from github
cd "$SCRIPT_REPOS" || exit
if [ -d "FLUNED-SL-repository" ]; then
  cd "FLUNED-SL-repository" || exit
  git pull origin main
else
  git clone git@github.com:marco-de-pietri/FLUNED-SL-repository.git
fi

cd "$SCRIPT_REPOS" || exit
if [ -d "groupjuggler" ]; then
  cd "groupjuggler" || exit
  git pull origin main
  uv tool uninstall groupjuggler
  uv clean
  uv tool install .
else
  git clone git@github.com:marco-de-pietri/groupjuggler.git
  cd "groupjuggler" || exit
  uv tool install .
fi
