## VSCode

## Windows

```
CMD> del %USERPROFILE%\AppData\Roaming\Code\User\settings.jsonc
CMD> mklink %USERPROFILE%\AppData\Roaming\Code\User\settings.json <repository>\vscode\vscode-settings.json
CMD> .\install-extensions.bat
```

## Linux

```
mkdir -p ~/.config/Code/User
ln -sf $PWD/vscode-settings.jsonc ~/.config/Code/User/settings.json
setup/vscode-install-extensions.sh
```

## macOS

```
ln -sf $PWD/vscode-settings.jsonc ~/Library/Application\ Support/Code/User/settings.json
setup/vscode-install-extensions.sh
```
