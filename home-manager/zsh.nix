{ config, pkgs, ... }:
{
  home.sessionVariables = {
    Z_DATA_DIR = "${config.xdg.dataHome}/zsh";
    Z_CACHE_DIR = "${config.xdg.cacheHome}/zsh";
  };

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
      ai-commit-all() { git add -A; claude -p "/commit $*"; }
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
}
