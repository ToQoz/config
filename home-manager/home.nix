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
  asdfConfigDir = "${config.xdg.configHome}/asdf";
  asdfDataDir = "${config.xdg.dataHome}/asdf";

  # Temporary version bump for `fence`.
  #
  # nixpkgs (as of this writing) ships fence 0.1.46, but we want 0.1.48 to
  # pick up upstream fixes. Once nixpkgs catches up to >= 0.1.48, delete this
  # override and restore the plain `fence` line in `home.packages`.
  #
  # Approach: inline `overrideAttrs` on `pkgs.fence`, bumping `version`, `src`,
  # and `vendorHash`. We intentionally avoid a full `nixpkgs.overlays` entry —
  # this flake sets `home-manager.useGlobalPkgs = true`, so overlays must live
  # at the nix-darwin level. A scoped override keeps the change local to its
  # one call site and trivial to delete.
  #
  # Note the two-argument form `(finalAttrs: _prevAttrs: ...)`: the upstream
  # definition (`pkgs/by-name/fe/fence/package.nix`) derives `src` from
  # `finalAttrs.version` via the `buildGoModule` fixed-point, so the new
  # version must be visible through `finalAttrs`. The single-arg form would
  # leave `src` pointing at v0.1.46.
  #
  # To refresh the hashes when bumping further:
  #   nix-prefetch-url --unpack https://github.com/Use-Tusk/fence/archive/refs/tags/vX.Y.Z.tar.gz
  #   nix hash to-sri --type sha256 <hash>        # -> src hash
  # For `vendorHash`, set it to `lib.fakeHash` (or any wrong value), run the
  # build, and copy the "got:" hash from the error.
  fence-0_1_48 = pkgs.fence.overrideAttrs (
    finalAttrs: _prevAttrs: {
      version = "0.1.48";
      src = pkgs.fetchFromGitHub {
        owner = "Use-Tusk";
        repo = "fence";
        tag = "v${finalAttrs.version}";
        hash = "sha256-OBbN/mSoQfpeBMl3KYD+fLVwB/ruux9jvk9HJjDmxU8=";
      };
      vendorHash = "sha256-Zfrst8fQNHP3KNpTQLIju9qo2hyozOWwbdNw0qCGhJ0=";
    }
  );
in
{
  imports = [
    ./android.nix
    ./chromium.nix
    ./direnv.nix
    ./fzf.nix
    ./gh.nix
    ./nix.nix
    ./starship.nix
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
      bun
      deno
      # fence  # re-enable once nixpkgs ships >= 0.1.48; see `fence-0_1_48` override in `let` block above
      fence-0_1_48
      asdf-vm
      vscode
      code-cursor
      zed-editor
      slack
      (callPackage ../packages/portless.nix { })
      (callPackage ../packages/mo.nix { })
      (callPackage ../packages/vite-plus.nix { })
      (callPackage ../packages/pi-coding-agent.nix { })
      sence.packages.${pkgs.stdenv.hostPlatform.system}.default
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.sketchybar
    ];

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
  home.activation.createXdgDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # less requires the parent directory to exist before it can write LESSHISTFILE
    mkdir -p "${config.xdg.dataHome}/less"
  '';

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
      # Claude
      "settings.local.json"
      # Misc
      ".todo.md"
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

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withRuby = false;
    withPython3 = false;
    sideloadInitLua = true;

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

  xdg.configFile."sketchybar".source = lib.mkIf pkgs.stdenv.isDarwin (
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/sketchybar"
  );

  home.file."Library/Application Support/Cursor/User/settings.json".source =
    lib.mkIf pkgs.stdenv.isDarwin (
      config.lib.file.mkOutOfStoreSymlink "${dotfiles}/vscode-family/cursor-settings.jsonc"
    );

  home.file.".claude/CLAUDE.md".source = ../dotfiles/agents/CLAUDE.md;
  home.file.".claude/skills/README.md".text = ''
    # Generated directory — do not edit here

    This directory is generated by Nix/Home Manager.
    Edits made here will be lost on the next `darwin-rebuild switch`.

    Canonical source for skills:
      ~/src/github.com/ToQoz/config/dotfiles/agents/skills/
  '';

  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    package = llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

    context = ../dotfiles/agents/CLAUDE.md;
    settings = {
      autoUpdates = false;
      includeCoAuthoredBy = false;
      enableAllProjectMcpServers = true;
      skipAutoPermissionPrompt = true;
      defaultMode = "plan";

      env = {
        CLAUDE_CODE_NO_FLICKER = "1";
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      };

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
          "Read(~/agents/**)"
          "Write(~/agents/**)"
          "Edit(~/agents/**)"
          "Bash(codex exec --sandbox read-only --ephemeral *)"
          "Bash(gh repo view --json defaultBranchRef --jq *)"
          "Bash(echo *)"
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
          "Bash(gh pr checks *)"
          "Bash(gh pr diff *)"
          "Bash(gh pr list *)"
          "Bash(gh pr status *)"
          "Bash(gh pr view *)"
          "Bash(gh run list *)"
          "Bash(gh run status *)"
          "Bash(gh run view *)"
          "Bash(gh run watch *)"
          "Bash(gh search *)"
          "Bash(nix build *)"
          "Bash(nix fmt *)"
          "Bash(nix log *)"
          "Bash(cargo tree *)"
          "Bash(npm list *)"
          "Bash(pnpm list *)"
          "Bash(agent-browser *)"
          "Bash(docker compose ps *)"
          "mcp__plugin_claude-code-home-manager_Figma__get_code"
          "mcp__plugin_claude-code-home-manager_Figma__get_code_connect_map"
          "mcp__plugin_claude-code-home-manager_Figma__get_design_context"
          "mcp__plugin_claude-code-home-manager_Figma__get_image"
          "mcp__plugin_claude-code-home-manager_Figma__get_metadata"
          "mcp__plugin_claude-code-home-manager_Figma__get_screenshot"
          "mcp__plugin_claude-code-home-manager_Figma__get_variable_defs"
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
      vercel = {
        path = vercel-agent-browser;
        subdir = "skills";
      };
    };
    skills = {
      enableAll = [
        "local"
        "anthropic"
        "vercel"
      ];
    };
    targets.claude.enable = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
