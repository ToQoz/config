{ pkgs, lib, ... }:
let
  # Dracula Color Palette
  colors = {
    background = "0xff282a36";
    backgroundTransparent = "0xcc282a36";
    currentLine = "0xff44475a";
    foreground = "0xfff8f8f2";
    comment = "0xff6272a4";
    green = "0xff50fa7b";
    purple = "0xffbd93f9";
    red = "0xffff5555";
    # Derived colors
    transparent = "0x00000000";
    black = "0xff21222c";
  };

  # Aerospace workspace plugin script
  # 各space itemが自分自身の状態のみを更新（イベント駆動 + ポーリング両対応）
  aerospacePlugin = pkgs.writeShellScript "aerospace.sh" ''
    AEROSPACE="/run/current-system/sw/bin/aerospace"

    # 自分のspace ID（space.1, space.2, ... から数字を抽出）
    SID=$(echo "$NAME" | sed 's/space\.//')

    # フォーカス中のワークスペースを取得（イベント時は環境変数、ポーリング時はコマンド実行）
    if [ -n "$FOCUSED_WORKSPACE" ]; then
      FOCUSED="$FOCUSED_WORKSPACE"
    else
      FOCUSED=$("$AEROSPACE" list-workspaces --focused 2>/dev/null || echo "1")
    fi

    if [ "$SID" = "$FOCUSED" ]; then
      sketchybar --set "$NAME" \
        background.color=${colors.foreground} \
        icon.color=${colors.background} \
	position=left \
        padding_left=0 \
        padding_right=0 \
        icon.padding_left=8 \
        icon.padding_right=10 \
        label.padding_left=0 \
        label.padding_right=0 \
        width=dynamic
    else
      WINDOWS=$("$AEROSPACE" list-windows --workspace "$SID" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$WINDOWS" -gt 0 ]; then
        sketchybar --set "$NAME" \
          background.color=${colors.transparent} \
          icon.color=${colors.foreground} \
	  position=left \
          padding_left=0 \
          padding_right=0 \
          icon.padding_left=8 \
          icon.padding_right=10 \
          label.padding_left=0 \
          label.padding_right=0 \
          width=dynamic
      else
        sketchybar --set "$NAME" \
          background.color=${colors.transparent} \
          icon.color=${colors.comment} \
	  position=left \
          padding_left=0 \
          padding_right=0 \
          icon.padding_left=8 \
          icon.padding_right=10 \
          label.padding_left=0 \
          label.padding_right=0 \
          width=dynamic
      fi
    fi
  '';

  # Volume plugin script
  volumePlugin = pkgs.writeShellScript "volume.sh" ''
    VOLUME=$(osascript -e 'output volume of (get volume settings)')
    MUTED=$(osascript -e 'output muted of (get volume settings)')

    if [ "$MUTED" = "true" ]; then
      ICON="󰖁"
      sketchybar --set "$NAME" icon="$ICON" label="mute"
    else
      if [ "$VOLUME" -ge 70 ]; then
        ICON="󰕾"
      elif [ "$VOLUME" -ge 30 ]; then
        ICON="󰖀"
      else
        ICON="󰕿"
      fi
      sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%"
    fi
  '';

  # Date plugin script
  datePlugin = pkgs.writeShellScript "date.sh" ''
    sketchybar --set "$NAME" label="$(date '+%m/%d (%a) %H:%M')"
  '';

  # IME plugin script
  imePlugin = pkgs.writeShellScript "ime.sh" ''
    IM=$(swift -e 'import Carbon; let s = TISCopyCurrentKeyboardInputSource().takeRetainedValue(); let p = TISGetInputSourceProperty(s, kTISPropertyLocalizedName)!; print(Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String)')
    sketchybar --set "$NAME" label="$IM"
  '';

  # Battery plugin script
  batteryPlugin = pkgs.writeShellScript "power.sh" ''
    PERCENTAGE=$(pmset -g batt | grep -Eo "[0-9]+%" | cut -d% -f1)
    CHARGING=$(pmset -g batt | grep 'AC Power')

    if [ -z "$PERCENTAGE" ]; then
      exit 0
    fi

    case ''${PERCENTAGE} in
      100)        ICON="󰁹" ;;
      9[0-9])     ICON="󰂂" ;;
      8[0-9])     ICON="󰂁" ;;
      7[0-9])     ICON="󰂀" ;;
      6[0-9])     ICON="󰁿" ;;
      5[0-9])     ICON="󰁾" ;;
      4[0-9])     ICON="󰁽" ;;
      3[0-9])     ICON="󰁼" ;;
      2[0-9])     ICON="󰁻" ;;
      1[0-9])     ICON="󰁺" ;;
      *)          ICON="󰂎" ;;
    esac

    COLOR=${colors.foreground}
    if [ -n "$CHARGING" ]; then
      ICON="󰂄"
    elif [ "$PERCENTAGE" -le 20 ]; then
      COLOR="${colors.red}"
    fi

    sketchybar --set battery icon="$ICON" icon.color="$COLOR" \
                --set "$NAME" label="$PERCENTAGE%"
  '';

  # Front app plugin script
  frontAppPlugin = pkgs.writeShellScript "front_app.sh" ''
    if [ "$SENDER" = "front_app_switched" ]; then
      sketchybar --set "$NAME" label="$INFO"
    fi
  '';

  # Main configuration
  sketchybarConfig = ''
    #!/bin/bash

    ##### Dracula Color Palette #####
    BACKGROUND_TRANSPARENT="${colors.backgroundTransparent}"
    CURRENT_LINE="${colors.currentLine}"
    FOREGROUND="${colors.foreground}"
    COMMENT="${colors.comment}"
    TRANSPARENT="${colors.transparent}"

    BRACKET_HEIGHT=20

    ############## BAR - Island Style ##############

    bar=(
      display=main
      height=28
      color="$BACKGROUND_TRANSPARENT"
      shadow=on
      position=top
      sticky=on
      padding_left=8
      padding_right=8
      margin=8
      corner_radius=12
      blur_radius=30
      notch_width=200
      y_offset=4
                )
    sketchybar --bar "''${bar[@]}"

    ############## GLOBAL DEFAULTS ##############

    default=(
      icon.font="Hack Nerd Font:Bold:14.0"
      icon.color="$FOREGROUND"
      icon.padding_left=6
      icon.padding_right=4
      label.font="Hack Nerd Font:Bold:12.0"
      label.color="$FOREGROUND"
      label.padding_left=4
      label.padding_right=6
      background.color="$TRANSPARENT"
      background.corner_radius=8
      background.height=28
      background.padding_left=2
      background.padding_right=2
        )
    sketchybar --default "''${default[@]}"

    ############## AEROSPACE EVENT ##############

    sketchybar --add event aerospace_workspace_change

    ############## LEFT ITEMS ##############

    # Apple Logo
    sketchybar --add item apple_logo left \
                --set apple_logo \
                      icon="" \
                      icon.font="SF Pro:Bold:16.0" \
                      icon.padding_left=8 \
                      icon.padding_right=4 \
                      background.color="$CURRENT_LINE" \
                      background.corner_radius=8 \
                      background.height=24 \
                      background.padding_right=8 \
                      padding_right=8 \
                      icon.padding_left=8 \
                      icon.padding_right=8 \
                      label.padding_left=0 \
                      label.padding_right=0 \
                      click_script="sketchybar --update"

    # Aerospace Workspaces
    SPACE_ICONS=("1" "2" "3" "4" "5")

    for i in "''${!SPACE_ICONS[@]}"; do
      sid="''${SPACE_ICONS[$i]}"
      # 10番目は表示を "0" にする
      if [ "$sid" = "10" ]; then
        display_icon="0"
      else
        display_icon="$sid"
      fi

      sketchybar --add item space.$sid left \
                  --set space.$sid \
                        icon="$display_icon" \
                        icon.font="Hack Nerd Font:Bold:12.0" \
                        icon.color="$COMMENT" \
                        icon.padding_left=8 \
                        icon.padding_right=8 \
                        background.color="$TRANSPARENT" \
                        background.corner_radius=6 \
                        background.height=24 \
                        click_script="aerospace workspace $sid" \
                        script="${aerospacePlugin}" \
                        update_freq=60 \
                  --subscribe space.$sid aerospace_workspace_change
    done

    # Front App (Window Title)
    sketchybar --add item front_app left \
                --set front_app \
                      icon.drawing=off \
                      label.font="Hack Nerd Font:Bold:12.0" \
                      label.color="$FOREGROUND" \
                      label.padding_left=12 \
                      script="${frontAppPlugin}" \
                --subscribe front_app front_app_switched

    ############## RIGHT ITEMS ##############

    # Date
    sketchybar --add item date right \
                --set date \
                      icon="󰥔" \
                      icon.font="Hack Nerd Font:Bold:14.0" \
                      update_freq=60 \
                      script="${datePlugin}"

    # Separator
    sketchybar --add item separator_datetime right \
                --set separator_datetime \
                      icon=│ \
                      icon.color="$COMMENT" \
                      icon.padding_left=4 \
                      icon.padding_right=4 \
                      background.drawing=off

    # IME
    sketchybar --add item ime right \
                --set ime \
		      update_freq=60 \
		      script="${imePlugin}"

    # Battery
    sketchybar --add item battery right \
                --set battery \
                      update_freq=60 \
                      script="${batteryPlugin}"

    # Separator
    sketchybar --add item separator_power right \
                --set separator_power \
                      icon=│ \
                      icon.color="$COMMENT" \
                      icon.padding_left=4 \
                      icon.padding_right=4 \
                      background.drawing=off

    # Volume
    sketchybar --add item volume right \
                --set volume \
                      icon=󰕾 \
                      icon.font="Hack Nerd Font:Bold:14.0" \
                      update_freq=60 \
                      script="${volumePlugin}" \
                --subscribe volume volume_change

    ############## BRACKETS - Island Groups ##############

    # Spaces bracket
    sketchybar --add bracket spaces_bracket '/space\..*/' \
                --set spaces_bracket \
                      background.color="$CURRENT_LINE" \
                      background.corner_radius=10 \
                      background.height=$BRACKET_HEIGHT

    # IME bracket
    sketchybar --add bracket ime_bracket ime \
                --set ime_bracket \
                      background.color="$CURRENT_LINE" \
                      background.corner_radius=10 \
                      background.height=$BRACKET_HEIGHT

    # Network bracket
    sketchybar --add bracket network_bracket volume \
                --set network_bracket \
                      background.color="$CURRENT_LINE" \
                      background.corner_radius=10 \
                      background.height=$BRACKET_HEIGHT

    # Power bracket
    sketchybar --add bracket power_bracket battery \
                --set power_bracket \
                      background.color="$CURRENT_LINE" \
                      background.corner_radius=10 \
                      background.height=$BRACKET_HEIGHT

    # DateTime bracket
    sketchybar --add bracket datetime_bracket date \
                --set datetime_bracket \
                      background.color="$CURRENT_LINE" \
                      background.corner_radius=10 \
                      background.height=$BRACKET_HEIGHT

    ############## FINALIZE ##############

    # 初期状態を設定 (現在のワークスペースを取得してハイライト)
    AEROSPACE="/run/current-system/sw/bin/aerospace"
    FOCUSED=$("$AEROSPACE" list-workspaces --focused 2>/dev/null || echo "1")
    sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$FOCUSED"

    sketchybar --update
  '';
in
{
  home.packages = lib.optionals pkgs.stdenv.isDarwin [
    pkgs.sketchybar
  ];

  xdg.configFile."sketchybar/sketchybarrc" = lib.mkIf pkgs.stdenv.isDarwin {
    text = sketchybarConfig;
    executable = true;
  };
}
