#!/bin/sh

set -e

sudo apt update
sudo apt upgrade

sudo apt install make tmux vim tig

# nodejs
# docker