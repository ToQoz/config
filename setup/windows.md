## Windows

### Config files

```
[PS] $ New-Item -Path $Home\.claude -ItemType SymbolicLink -Value $Home\config\.config\claude
[PS] $ New-Item -Path $Home\.config\claude -ItemType SymbolicLink -Value $Home\config\.config\claude
```

### Invert mouse wheel

```
[PS] $ Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device` Parameters FlipFlopWheel -EA 0 | ForEach-Object { Set-ItemProperty $_.PSPath FlipFlopWheel 1 }
```

### winget

```
[PS] $ winget install 9P9TQF7MRM4R # Windows Subsystem for Linux

[PS] $ winget install Git.Git
[PS] $ winget install Microsoft.PowerToys

[PS] $ winget install CrystalDewWorld.CrystalDiskMark
[PS] $ winget install CrystalDewWorld.CrystalDiskInfo

[PS] $ winget install Elgato.StreamDeck
[PS] $ winget install geforce-experience
[PS] $ winget install corvusskk

[PS] $ winget install AgileBits.1Password
[PS] $ winget install 7Zip.7Zip
[PS] $ winget install gyazo
[PS] $ winget install Google.Drive
[PS] $ winget install DigitalScholar.Zotero
[PS] $ winget install 9NMPJ99VJBWV # Phone Link

[PS] $ winget install Canonical.Ubuntu.2204

[PS] $ winget install Microsoft.DotNet.SDK.9
[PS] $ winget install Microsoft.PowerShell
[PS] $ winget install Microsoft.WindowsTerminal
[PS] $ winget install Microsoft.VisualStudioCode
[PS] $ winget install Anyshere.Cursor
[PS] $ winget install Git.Git
[PS] $ winget install BurntSushi.ripgrep.MSVC
[PS] $ winget install jetbrainstoolbox
[PS] $ winget install 9PGCV4V3BK4W # DevToys
[PS] $ winget install nodejs-lts
[PS] $ winget install pnpm.pnpm

# Tauri
# https://gist.github.com/robotdad/83041ccfe1bea895ffa073919277
[PS] $ winget install Microsoft.VisualStudio.2022.Community --silent --override "--wait --quiet --add ProductLang En-us --add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended"
[PS] $ winget install Rustlang.Rustup

[PS] $ winget install Zen-Team.Zen-Browser
[PS] $ winget install Discord.Discord
[PS] $ winget install Notion.Notion
[PS] $ winget install Notion.NotionCalendar
[PS] $ winget install SlackTechnologies.Slack
[PS] $ winget install Zoom.Zoom

[PS] $ winget install --source msstore Raindrop

[PS] $ winget install TradingView.TradingViewDesktop
[PS] $ winget install XP8C9QZMS2PC1T # Brave
```

### rustup

```
[PS] $ rustup default stable-msvc
```

### pub

```
# Append ~\AppData\Local\Pub\Cache\bin to $PATH
[PS] $ dart pub global activate fvm
```
