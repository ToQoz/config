## VSCode

## Windows

```
CMD> del %USERPROFILE%\AppData\Roaming\Code\User\settings.json
CMD> mklink %USERPROFILE%\AppData\Roaming\Code\User\settings.json <repository>\vscode\settings.json
CMD> <repository>\vscode\windows\install-extensions.bat
```

## Linux

```
mkdir -p ~/.config/Code/User
ln -sf $PWD/settings.json ~/.config/Code/User/settings.json
bash install-extensions.bash
```

## macOS

```
ln -sf $PWD/settings.json ~/Library/Application\ Support/Code/User/settings.json
bash install-extensions.bash
```
