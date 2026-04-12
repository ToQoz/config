{
  lib,
  config,
  pkgs,
  llm-agents,
  anthropic-skills,
  ...
}:
let
  root = "${config.home.homeDirectory}/src/github.com/ToQoz/config";
  dotfiles = "${root}/dotfiles";
  asdfConfigDir = "${config.xdg.configHome}/asdf";
  asdfDataDir = "${config.xdg.dataHome}/asdf";
in
{
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

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages =
    with pkgs;
    [
      mkcert
      wget
      tmux
      tig
      ghq
      lazygit
      ripgrep
      fd
      asdf-vm
      vscode
      code-cursor
      zed-editor
      slack
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.sketchybar
    ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

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
    # EDITOR = "emacs";
    Z_DATA_DIR = "${config.xdg.dataHome}/zsh";
    Z_CACHE_DIR = "${config.xdg.cacheHome}/zsh";
    ASDF_CONFIG_FILE = "${asdfConfigDir}/.asdfrc";
    ASDF_DATA_DIR = "${asdfDataDir}";
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.scripts"
  ];

  # local scripts
  home.file.".scripts".source = config.lib.file.mkOutOfStoreSymlink "${root}/scripts";
  # tmux
  xdg.configFile."tmux".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/tmux";
  # asdf
  xdg.configFile."asdf/.asdfrc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/asdf/.asdfrc";
  home.file.".tool-versions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/asdf/.tool-versions";
  home.activation.installAsdfPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${
      lib.makeBinPath (
        with pkgs;
        [
          asdf-vm
          git
          #curl
          #gnugrep
          #coreutils
          #gnutar
          #gzip
          #unzip
          #gawk
          #findutils
        ]
      )
    }:$PATH"
    export ASDF_DATA_DIR="${asdfDataDir}"
    export ASDF_CONFIG_FILE="${asdfConfigDir}/.asdfrc"
    mkdir -p "$ASDF_DATA_DIR" "${asdfConfigDir}"
    if ! asdf plugin list | grep -qx nodejs; then
      asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
    fi
    if ! asdf plugin list | grep -qx pnpm; then
      asdf plugin add pnpm https://github.com/jonathanmorley/asdf-pnpm.git
    fi
    if ! asdf plugin list | grep -qx deno; then
      asdf plugin add deno https://github.com/asdf-community/asdf-deno.git
    fi
  '';

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.wezterm = {
    enable = true;
  };
  xdg.configFile."wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/wezterm";

  programs.starship = {
    enable = true;
  };
  # ref. https://github.com/starship/starship/issues/896
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/starship/config.toml";

  programs.zsh = {
    enable = true;
    package = pkgs.emptyDirectory;
    dotDir = "${config.xdg.configHome}/zsh";
    history.path = "${config.xdg.stateHome}/zsh/history";
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
    # .zshenv
    envExtra = ''
      source "${pkgs.asdf-vm}/etc/profile.d/asdf-prepare.sh"
      fpath=(${pkgs.asdf-vm}/share/zsh/site-functions $fpath)
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

      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      # Preview for cd
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 $realpath'

      autoload -U edit-command-line
      zle -N edit-command-line

      select-repository() {
        local d
        d=$(ghq list -p | fzf --no-sort --exact)
        if [ $? = 0 -a -n "$d" ]; then
          cd $d
          zle reset-prompt
        fi
      }
      zle -N select-repository

      select-history() {
        BUFFER=$(history -n 1 | perl -e 'print reverse <>' | fzf --no-sort --exact --query "$LBUFFER")
        CURSOR=$#BUFFER
        zle clear-screen
      }
      zle -N select-history

      # C-Space: Start completion
      bindkey '^@' fzf-tab-complete
      # C-g: Use editor to edit command line
      bindkey "^g" edit-command-line
      # C-x g
      bindkey "^xg" select-repository
      # C-r: Alt bck-i-search
      bindkey '^r' select-history
      # Cmd-r: Redo
      bindkey "^[r" redo # Cmd-r
    '';
  };

  programs.git = {
    enable = true;

    # Keep global ignores minimal — repo-specific rules belong in .gitignore
    ignores = [
      # OS
      ".DS_Store"
      "Thumbs.db"
      # Editor
      ".*~"
      "#*#"
      "*.sw[po]"
      # Build
      "*.out"
      # Env
      ".env"
      "*.env$"
    ];

    settings = {
      user = {
        name = "Takatoshi Matsumoto";
        email = "toqoz403@gmail.com";
      };
      alias = {
        s = "!git stash list && git status -sb";
        dw = "diff --color-words";
        co = "checkout";
        ci = "commit -v";
        fi = "commit -v --fixup HEAD";
        br = "branch";
        wc = "whatchanged";
        unstage = "reset HEAD --";
        # http://qiita.com/uasi/items/f19a120e012c0c75d856
        uncommit = "reset HEAD^";
        recommit = "commit -c ORIG_HEAD";
      };

      core = {
        autocrlf = "input";
        quotepath = false;
        precomposeunicode = true;
        ignorecase = false;
      };

      push.default = "simple";
      grep.lineNumber = true;
      diff.algorithm = "histogram";
      merge.tool = "vimdiff";

      github.user = "ToQoz";
      ghq.root = "~/src";
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withRuby = false;
    withPython3 = false;

    extraWrapperArgs = [
      "--set"
      "TELESCOPE_FZY_NATIVE"
      "${pkgs.vimPlugins.telescope-fzy-native-nvim}"
    ];

    extraPackages = with pkgs; [
      skkDictionaries.l
      lua-language-server
      typescript-language-server
      nixd # Nix Language Server
      bash-language-server
      vim-language-server
      emmet-language-server
      stylua # Lua formatter
      nixfmt
      vimPlugins.telescope-fzy-native-nvim # To avoid build steps
    ];
  };

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim";

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  xdg.configFile."sketchybar".source = lib.mkIf pkgs.stdenv.isDarwin (
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/sketchybar"
  );

  home.file."Library/Application Support/Cursor/User/settings.json".source =
    lib.mkIf pkgs.stdenv.isDarwin (
      config.lib.file.mkOutOfStoreSymlink "${dotfiles}/vscode-family/cursor-settings.jsonc"
    );

  home.file.".claude/CLAUDE.md".source = ../dotfiles/agents/CLAUDE.md;

  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    package = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

    memory.source = ../dotfiles/agents/CLAUDE.md;
    settings = {
      autoUpdates = false;
      includeCoAuthoredBy = false;
      enableAllProjectMcpServers = true;

      permissions = {
        deny = [
          "Bash(sudo *)"
          "Read(.env)"
          "Edit(.env)"
          "Read(*.env)"
          "Edit(*.env)"
          "Read(*.vars)"
          "Edit(*.vars)"
        ];
        allow = [
          "Bash(find *)"
          "Bash(grep *)"
          "Bash(head *)"
          "Bash(ls *)"
          "Bash(mkdir *)"
          "Bash(tail *)"
          "Bash(git add *)"
          "Bash(git apply *)"
          "Bash(git blame *)"
          "Bash(git checkout *)"
          "Bash(git cherry-pick *)"
          "Bash(git commit *)"
          "Bash(git diff *)"
          "Bash(git fetch *)"
          "Bash(git log *)"
          "Bash(git merge *)"
          "Bash(git mv *)"
          "Bash(git pull *)"
          "Bash(git rm *)"
          "Bash(git show *)"
          "Bash(git stash *)"
          "Bash(git status *)"
          "Bash(gh pr diff *)"
          "Bash(gh pr list *)"
          "Bash(gh pr status *)"
          "Bash(gh pr view *)"
          "Bash(gh run list *)"
          "Bash(gh run status *)"
          "Bash(gh run view *)"
          "Bash(gh run watch *)"
          "Bash(nix build *)"
          "Bash(nix fmt *)"
          "Bash(nix log *)"
          "Bash(cargo tree *)"
          "Bash(npm list *)"
          "Bash(pnpm list *)"
          "Bash(docker compose ps *)"
          "mcp__Figma__get_code"
          "mcp__Figma__get_code_connect_map"
          "mcp__Figma__get_image"
          "mcp__Figma__get_metadata"
          "mcp__Figma__get_screenshot"
          "mcp__Figma__get_variable_defs"
        ];
      };
    };
  };

  programs.mcp = {
    enable = true;
    servers = {
      # Since the Remote MCP Server does not support multiple accounts, I will use the MCP Server from the Desktop app.
      Figma = {
        type = "http";
        url = "http://127.0.0.1:3845/mcp";
      };
    };
  };

  programs.agent-skills = {
    enable = true;
    sources = {
      local = {
        path = ../dotfiles/agents/skills;
        filter.maxDepth = 1;
      };
      anthropic = {
        path = anthropic-skills;
        subdir = "skills";
      };
    };
    skills = {
      enableAll = [
        "local"
        "anthropic"
      ];
    };
    targets.claude.enable = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
