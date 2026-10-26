{osConfig, ...}: {
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = osConfig.my.user.name;
      user.email = osConfig.my.user.email;

      alias = {
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        lga = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all";
        ll = "log --pretty=format:'%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]' --decorate --numstat";

        st = "status -s";

        co = "checkout";
        br = "branch";
        ci = "commit";
        ca = "commit -a";
        cm = "commit -m";
        cam = "commit -am";

        df = "diff";
        dc = "diff --cached";

        pr = "pull --rebase origin main";

        rbi = "rebase -i HEAD~10";

        unstage = "reset HEAD --";
        last = "log -1 HEAD";

        sl = "stash list";
        sa = "stash apply";
        ss = "stash save";
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      diff.colorMoved = "default";
      merge.conflictStyle = "diff3";
      rerere.enabled = true;
    };
  };
}
