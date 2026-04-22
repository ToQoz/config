{ config, pkgs, ... }:
{
  home.sessionVariables = {
    Z_DATA_DIR = "${config.xdg.dataHome}/zsh";
    Z_CACHE_DIR = "${config.xdg.cacheHome}/zsh";
  };

  # Autoloaded site-functions: one function per file under functions/.
  # Real .zsh files avoid Nix heredoc escaping (''${...}) and play nicely
  # with editors and shellcheck.
  xdg.configFile."zsh/functions".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.repoPath}/home-manager/zsh/functions";

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
      fpath=(${pkgs.asdf-vm}/share/zsh/site-functions ${config.xdg.configHome}/zsh/functions $fpath)

      # Autoload claude here (not in .zshrc) so git aliases and other
      # non-interactive zsh subshells can resolve the wrapper.
      autoload -Uz claude
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

      # Site-functions dir already added to fpath in .zshenv.
      autoload -Uz select-repository ghq ai-commit ai-commit-all ai-commit-staged
      zle -N select-repository

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
