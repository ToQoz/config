{
  lib,
  config,
  pkgs,
  llm-agents,
  anthropic-skills,
  vercel-agent-browser,
  sence,
  ...
}:
let
  root = "${config.home.homeDirectory}/src/github.com/ToQoz/config";
  dotfiles = "${root}/dotfiles";
in
{
  imports = [
    ./agents/agent-skills.nix
    ./agents/claude-code.nix
    ./agents/mcp.nix
    ./android.nix
    ./asdf.nix
    ./chromium.nix
    ./direnv.nix
    ./fzf.nix
    ./gh.nix
    ./git.nix
    ./neovim.nix
    ./nix.nix
    ./packages.nix
    ./sketchybar.nix
    ./starship.nix
    ./tmux.nix
    ./vscode-family.nix
    ./wezterm.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "toqoz";
  home.homeDirectory = "/Users/toqoz";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = { };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/toqoz/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    XDG_DATA_HOME = config.xdg.dataHome; # for .tig_history
    # EDITOR = "emacs";
    Z_DATA_DIR = "${config.xdg.dataHome}/zsh";
    Z_CACHE_DIR = "${config.xdg.cacheHome}/zsh";
    LESSHISTFILE = "${config.xdg.dataHome}/less/history";
    WGETHSTS = "${config.xdg.cacheHome}/wget/hsts";
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.scripts"
  ];

  # local scripts
  home.file.".scripts".source = config.lib.file.mkOutOfStoreSymlink "${root}/scripts";
  home.activation.createXdgDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # less requires the parent directory to exist before it can write LESSHISTFILE
    mkdir -p "${config.xdg.dataHome}/less"
  '';

  programs.zsh = {
    enable = true;
    package = pkgs.emptyDirectory;
    dotDir = "${config.xdg.configHome}/zsh";
    history = {
      path = "${config.xdg.stateHome}/zsh/history";
      # Keep extra history in memory for smarter trimming before save.
      size = 200000;
      save = 150000;
      # Store timestamps and durations with history entries.
      extended = true;
      # Drop a command if it is identical to the previous entry.
      ignoreDups = true;
      # When trimming history, remove older duplicate entries first.
      expireDuplicatesFirst = true;
      # Do not record commands that start with a space.
      ignoreSpace = true;
    };
    syntaxHighlighting = {
      enable = true;
    };
    autosuggestion = {
      enable = false;
      strategy = [
        "history"
        "completion"
      ];
    };
    enableCompletion = true; # For autocomplete
    shellAliases = {
      # Wrap interactive claude with sence in auto permission mode.
      auto-claude = "sence --profile code:claude --interactive -- claude --permission-mode auto";
    };
    # .zshenv
    envExtra = ''
      source "${pkgs.asdf-vm}/etc/profile.d/asdf-prepare.sh"
      fpath=(${pkgs.asdf-vm}/share/zsh/site-functions $fpath)

      # Why claude() is in .zshenv: it's used by git aliases
      claude() {
        local print=false
        local args=()
        while [[ $# -gt 0 ]]; do
          case "$1" in
            -p) print=true; shift ;;
            *) args+=("$1"); shift ;;
          esac
        done

        if $print; then
          local hr="$(printf '%*s\n' "$(tput cols)" "" | tr ' ' '-')"
          command claude --output-format stream-json --verbose "''${args[@]}" | jq -cr '
            if .type == "assistant" then
              (.message.content[] | .text // empty)
            elif .type == "result" then
              .result
            elif (.type == "user" or .type == "system" or .type == "rate_limit_event") then
              empty
            else @json
            end | ., "'"$hr"'"
          '
        else
          command claude "''${args[@]}"
        fi
      }
    '';
    # .zprofile
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    '';
    # .zshrc (completion)
    completionInit = ''
      # Show group headers
      zstyle ':completion:*:descriptions' format '[%d]'
      # extact -> case sensitive -> case insensitive → fuzzy
      zstyle ':completion:*' matcher-list ''' 'm:{a-z}={A-Z}' '+m:{A-Z}={a-z}' 'r:|=*' 'l:|=* r:|=*'
      # Disable zsh completion UI
      zstyle ':completion:*' menu no
    '';
    # .zshrc
    initContent = ''
      setopt IGNORE_EOF
      # Remove superfluous blanks before saving a command.
      setopt HIST_REDUCE_BLANKS

      # fzf integration
      source <(fzf --zsh)

      # fzf-tab
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      # Preview for cd
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 $realpath'

      autoload -U edit-command-line
      zle -N edit-command-line

      # Never auto-execute on paste; Enter is always required.
      autoload -Uz bracketed-paste-magic
      zle -N bracketed-paste bracketed-paste-magic

      select-repository() {
        local root d
        root=$(ghq root)
        d=$(ghq list -p | sed "s|^$root/github.com/|github:|; s|^$root/||" | fzf --no-sort --exact)
        if [ $? = 0 -a -n "$d" ]; then
          d=''${d/#github:/$root/github.com/}
          # If still relative (non-github host), prepend root
          [[ "$d" != /* ]] && d="$root/$d"
          cd "$d"
          zle reset-prompt
        fi
      }
      zle -N select-repository

      ai-commit() { claude -p "/commit $*"; }
      ai-commit-staged() { claude -p "/commit-staged $*"; }

      ghq() {
        if [[ "$1" == "get" ]]; then
          local repo=""
          for arg in "''${@:2}"; do
            [[ "$arg" != -* ]] && repo="$arg" && break
          done

          if [[ -n "$repo" ]]; then
            # Normalize just enough for `ghq list` substring match
            local q="''${repo##*:}"; q="''${q#//}"; q="''${q%.git}"
            # Default host to github.com when only user/project is given
            [[ "$q" == */*/* ]] || q="github.com/$q"
            mkdir -p "$(command ghq root)/''${q%/*}" || return
            command ghq "$@"
            local status=$?
            local path
            path="$(command ghq list --full-path "$q" 2>/dev/null)"
            path="''${path%%$'\n'*}"
            [[ -n "$path" ]] && cd "$path"
            return $status
          fi
        fi
        command ghq "$@"
      }

      # C-Space: Start completion
      bindkey '^@' fzf-tab-complete
      # C-g: Use editor to edit command line
      bindkey "^g" edit-command-line
      # C-x g
      bindkey "^xg" select-repository
      # Unbind C-t (fzf file widget) so tmux prefix passes through
      bindkey -r '^t'
      # Cmd-r: Redo
      bindkey "^[r" redo # Cmd-r
    '';
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
