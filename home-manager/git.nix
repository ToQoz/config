{ ... }:
{
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
}
