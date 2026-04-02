{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$git_state$character";
      right_format = "$status$all";
      directory = {
        truncation_length = 1;
        truncate_to_repo = false;
        fish_style_pwd_dir_length = 1;
      };
      git_branch = {
        format = "[$branch(:$remote_branch)]($style) ";
        style = "bright-green";
      };
      git_status = {
        format = "[($ahead_behind )](bright-green)[($conflicted$stashed$deleted$renamed$modified$typechanged$staged )](yellow)[($untracked )](bright-blue)";
        stashed = "*$count";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇡$ahead_count⇣$behind_count";
        conflicted = "=$count";
        deleted = "✘$count";
        renamed = "»$count";
        modified = "!$count";
        staged = "+$count";
        untracked = "?$count";
      };
      git_state = {
        format = "[$state( $progress_current/$progress_total)]($style) ";
        style = "bright-red";
        rebase = "rebase";
        merge = "merge";
        revert = "revert";
        cherry_pick = "cherry-pick";
        bisect = "bisect";
        am = "am";
        am_or_rebase = "am/rebase";
      };
      status = {
        disabled = false;
        pipestatus = true;
        symbol = "✘";
        pipestatus_format = "[$symbol$pipestatus]($style) ";
        pipestatus_segment_format = "$status";
      };
      package.disabled = true;
      cmd_duration.format = "[ $duration]($style) ";
      kubernetes = {
        disabled = false;
        format = "[$symbol$context(@$namespace)]($style) ";
        symbol = " ";
      };
      nix_shell = {
        format = "[$symbol($name )]($style)";
        symbol = " ";
      };
      golang = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
      };
      python = {
        format = "[$symbol$pyenv_prefix($version )(\\($virtualenv\\) )]($style)";
        symbol = " ";
      };
      rust = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
      };
    };
  };
}
