#!/bin/sh

set -e

arch="$(uname -m)"
pid="$$"
mkdir "/tmp/$pid"
cd "/tmp/$pid"

sudo pacman -Syyuu \
  which \
  wget \
  zip \
  unzip \
  make \
  htop \
  whois \
  apache \
  hey \
  dstat \
  git \
  docker \
  docker-compose \
  fish \
  tig \
  neovim \
  tmux \
  fzf \
  jq \
  mkcert \
  clang \
  ffmpeg \
  rsync \
  nodejs \
  go \
  percona-server-clients \
  percona-toolkit \
  aws-cli-v2

git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si

yay -Syyuu ghq-bin aws-sam-cli-bin aws-session-manager-plugin evans-bin k6

# KidsCannon commandline-tools
git clone https://github.com/KidsCannon/commandline-tools.git ~/.k8n/commandline-tools
source "$HOME/.k8n/commandline-tools/init.sh"
append-line-if-not-exists 'source "$HOME/.k8n/commandline-tools/init.sh"' ~/.bashrc

# go install
go install github.com/Songmu/ghg/cmd/ghg@v0.3.0
go install github.com/fujimura/git-gsub@v0.1.2

export PATH="$HOME/go/bin:$PATH"
append-line-if-not-exists 'PATH="$(ghg bin):$PATH"' ~/.bashrc
append-line-if-not-exists 'PATH="$HOME/go/bin:$PATH"' ~/.bashrc

# ghg get
ghg get github.com/tkuchiki/alp@v1.0.21


### asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
source "$HOME/.asdf/asdf.sh"
asdf plugin add nodejs
asdf plugin add pnpm
asdf plugin add go-sdk
asdf plugin add flutter
asdf plugin add erlang
asdf plugin add elixir
append-line-if-not-exists 'source "$HOME/.asdf/asdf.sh"' ~/.bashrc
append-line-if-not-exists 'source "$HOME/.asdf/completions/asdf.bash"' ~/.bashrc

## SDKMAN
curl -s https://get.sdkman.io | bash

## Fisher
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
fish -c 'fisher install reitzig/sdkman-for-fish'
fish -c 'fisher install rstacruz/fish-asdf'

## Link config
ln -sf "$HOME/config/.gitconfig" ~/.gitconfig
ln -sf "$HOME/config/.gitignore_global" ~/.gitignore_global
rm -fr "$HOME/.config/fish"
ln -sf "$HOME/config/.config/fish" ~/.config/fish
ln -sf "$HOME/config/.config/nvim" ~/.config/nvim
ln -sf "$HOME/config/.tmux.conf" ~/.tmux.conf
ln -sf "$HOME/config/.asdfrc" ~/.asdfrc
ln -sf "$HOME/config/.tool-versions" ~/.tool-versions
(cd ~ && asdf install)

## UTF-8
sudo append-line-if-not-exists 'en_US.UTF-8 UTF-8' /etc/locale.gen
sudo append-line-if-not-exists 'ja_JP.UTF-8 UTF-8' /etc/locale.gen
sudo locale-gen

# Systemd
# sudo systemctl enable --now sshd
sudo gpasswd -a $USER docker
sudo systemctl enable --now docker

rm "/tmp/$pid"
