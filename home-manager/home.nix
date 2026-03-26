{ config, pkgs, llm-agents, ... }:

{
  imports = [
    ./sketchybar.nix
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
      wget
      tig
      slack
      llm-agents.packages.${pkgs.system}.claude-code
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
  };

  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require("wezterm")
      local config = wezterm.config_builder()

      config.automatically_reload_config = true
      config.window_background_opacity = 0.85
      config.macos_window_background_blur = 20

      config.hide_tab_bar_if_only_one_tab = true
      config.window_decorations = "RESIZE"
      -- config.use_fancy_tab_bar = false

      config.show_new_tab_button_in_tab_bar = false
      config.show_close_tab_button_in_tabs = false

      config.window_frame = {
        inactive_titlebar_bg = "none",
	active_titlebar_bg = "none",
      }

      config.window_background_gradient = {
        colors = { "#000000" },
      }

      config.colors = {
        tab_bar = {
	  inactive_tab_edge = "none",
	}
      }

      config.use_ime = true

      return config
    '';
  };

  programs.tmux = {
    enable = true;
    prefix = "C-t";

    extraConfig = ''
      set-option -g set-clipboard on
      set-option -g set-titles on
      set-option -g mouse off

      # Appearance {{{
      set -g status-position top
      set -g status-style fg=white,bg=black,dim
      set -g status-left-length 32
      set -g status-right-length 150

      set -g pane-border-style fg=white
      set -g pane-active-border-style fg=cyan,bg=black

      set -g window-status-format " #I #W "
      set -g window-status-current-format "#[fg=black,bg=white] [*#I] #W "
      set -g window-status-style fg=white,bg=black
      set -g window-status-current-style fg=green,bg=black
      set -g window-status-last-style fg=blue

      set -g status-right '#{?mouse,[M],}#{?window_zoomed_flag, [Z] ,} > #H > #(~/.tmux.d/bin/ssid) > %Y/%m/%d(%a)%H:%M#[default]'
      set -g message-style fg=white,bg=red,bold

      # set-window-option -g utf8 on
      set-window-option -g mode-keys vi
      set-window-option -g mode-style fg=black,bg=white
      # }}}

      unbind C-r
      bind C-r source-file ~/.tmux.conf \; display-message "Configuration reloaded"

      # Toggle mouse
      unbind m
      bind-key m \
        if-shell 'tmux show-options -g mouse | grep -q off' \
          'set-option -g mouse on' \
          'set-option -g mouse off' \; \
        refresh-client -S

      unbind P
      bind-key P command-prompt -p 'Capture pane and save it as file:' -I '~/.tmux.capture' 'capture-pane -S -32768 ; save-buffer %1 ; delete-buffer'

      # http://d.hatena.ne.jp/naoya/20130108/1357630895
      unbind e
      bind e command-prompt "split-window -p 65 'exec %%'"

      # Window keybindings {{{
      # New
      unbind c
      bind c new-window

      # Split
      unbind |
      bind | split-window -h -c "#{pane_current_path}"
      unbind -
      bind - split-window -v -c "#{pane_current_path}"
      bind 'c' new-window -c "#{pane_current_path}"

      # Swap
      # http://toqoz.hateblo.jp/entry/2013/10/12/025544
      set-option -g renumber-windows on
      unbind H
      bind -r H run-shell 'cw=$(tmux display-message -p "#I") && [ "$cw" -gt 0 ] && tmux swap-window -s "$cw" -t "$((cw - 1))"'
      unbind L
      bind -r L run-shell 'cw=$(tmux display-message -p "#I") && tmux swap-window -s "$cw" -t "$((cw + 1))"'

      # Resize
      # @option -r: is enable to repeat
      unbind C-h
      bind -r C-h resize-pane -L 6
      unbind C-l
      bind -r C-l resize-pane -R 6
      unbind C-j
      bind -r C-j resize-pane -D 6
      unbind C-k
      bind -r C-k resize-pane -U 6
      # }}}

      bind w choose-tree -N -w -f '#{==:#{session_name},#{session_name}}'

      # Pane keybindings {{{
      # Swap with previous pane.
      # @option -r: is enable to repeat
      unbind s
      bind -r s swap-pane -U

      # Move pane like Vim
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Kill
      unbind K
      bind K confirm-before -p "Kill this WINDOW? (y/n)" kill-window
      unbind Q
      bind Q confirm-before -p "Kill this SESSION? (y/n)" kill-session
      unbind P
      bind P confirm-before -p "Kill this PANE? (y/n)" kill-pane

      # Cut off target-pane from window including this, then be single pane in new window.
      unbind 1
      bind 1 break-pane
      # }}}

      # Copy mode settings {{{
      unbind y
      bind y copy-mode
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"
      unbind p
      bind p paste-buffer
      # }}}
    '';
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
