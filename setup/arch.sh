#!/bin/sh

set -e

arch="$(uname -m)"
pid="$$"
mkdir "/tmp/$pid"
cd "/tmp/$pid"

sudo pacman -Syyuu \
  base-devel \
  fakeroot \
  man-db \
  which \
  xsel \
  wget \
  zip \
  unzip \
  make \
  whois \
  dstat \
  htop \
  dnsutils \
  nmap \
  apache \
  hey \
  fish \
  neovim \
  tmux \
  git \
  tig \
  rsync \
  fzf \
  ripgrep \
  jq \
  direnv \
  docker \
  docker-compose \
  clang \
  nodejs \
  deno \
  go \
  rustup \
  github-cli \
  python-cfn-lint \
  percona-server-clients \
  percona-toolkit \
  aws-cli-v2 \
  mkcert \
  ffmpeg \
  imagemagick

# Tauri deps: https://tauri.app/v1/guides/getting-started/prerequisites/#setting-up-linux
sudo pacman -Syu \
    webkit2gtk \
    base-devel \
    curl \
    wget \
    file \
    openssl \
    appmenu-gtk-module \
    gtk3 \
    libappindicator-gtk3 \
    librsvg \
    libvips

git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si

yay -Syyuu \
  ghq-bin \
  aws-sam-cli-bin \
  aws-session-manager-plugin \
  k6 \
  ddosify \
  cfn-lint \
  awslogs \
  evans-bin \
  tauri \
  bun-bin \
  claude-code \
  google-gemini-cli

claude config set -g autoUpdaterStatus disabled
claude config set -g preferredNotifChannel terminal_bell

claude mcp add --scope user --transport sse Figma "http://127.0.0.1:3845/sse"

# KidsCannon commandline-tools
git clone https://github.com/KidsCannon/commandline-tools.git ~/.k8n/commandline-tools
source "$HOME/.k8n/commandline-tools/init.sh"

# go install
go install github.com/Songmu/ghg/cmd/ghg@v0.3.0
go install github.com/fujimura/git-gsub@v0.1.2
PATH="$HOME/go/bin:$PATH"
PATH="$(ghg bin):$PATH"

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

## Fisher
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
fish -c 'fisher install reitzig/sdkman-for-fish'
fish -c 'fisher install rstacruz/fish-asdf'

## CockroachDB
# Visit Releases to download the CockroachDB archive for the architecture of your Linux host. The archive contains the cockroach binary and the supporting libraries that are used to provide spatial features. Extract the archive and optionally copy the cockroach binary into your PATH so you can execute cockroach commands from any shell. If you get a permission error, use sudo.
# https://www.cockroachlabs.com/docs/v23.1/install-cockroachdb-linux
# https://www.cockroachlabs.com/docs/releases/

wget https://binaries.cockroachdb.com/cockroach-v23.1.13.linux-amd64.tgz
tar -xf cockroach-v23.1.13.linux-amd64.tgz
rm cockroach-v23.1.13.linux-amd64.tgz
sudo mv cockroach-v23.1.13.linux-amd64 /opt/cockroach

## Cleanup
rm -fr "$HOME/.config/fish"

## Link config
ln -sf "$HOME/config/.gitconfig" ~/.gitconfig
ln -sf "$HOME/config/.gitignore_global" ~/.gitignore_global
ln -sf "$HOME/config/.config/fish" ~/.config/fish
ln -sf "$HOME/config/.config/nvim" ~/.config/nvim
ln -sf "$HOME/config/.config/claude" ~/.config/claude
ln -sf "$HOME/config/.config/claude" ~/.claude
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
