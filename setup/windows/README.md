## Windows

### Invert mouse wheel

```
[PS] $ Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device` Parameters FlipFlopWheel -EA 0 | ForEach-Object { Set-ItemProperty $_.PSPath FlipFlopWheel 1 }
```

### WSL2

```
[PS] # wsl --install
```

### Applications

```
[PS] $ winget install Git.Git
[PS] $ winget install Microsoft.PowerToys

[PS] $ winget install CrystalDewWorld.CrystalDiskMark
[PS] $ winget install CrystalDewWorld.CrystalDiskInfo

[PS] $ winget install geforce-experience
[PS] $ winget install corvusskk

[PS] $ winget install Canonical.Ubuntu.2004
[PS] $ winget install jetbrainstoolbox
[PS] $ winget install Microsoft.WindowsTerminal
[PS] $ winget install vscode

[PS] $ winget install 7Zip.7Zip
[PS] $ winget install gyazo
[PS] $ winget install Google.Drive
[PS] $ winget install nodejs-lts
[PS] $ winget install 9NMPJ99VJBWV # Phone Link
[PS] $ winget install Zoom.Zoom
```