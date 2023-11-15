## VSCode

## Windows

```
CMD> del %USERPROFILE%\AppData\Roaming\Code\User\settings.json
CMD> mklink %USERPROFILE%\AppData\Roaming\Code\User\settings.json <repository>\vscode\settings.json
CMD> .\install-extensions.bat
```

## Linux

```
mkdir -p ~/.config/Code/User
ln -sf $PWD/settings.json ~/.config/Code/User/settings.json
./install-extensions.sh
```

## macOS

```
ln -sf $PWD/settings.json ~/Library/Application\ Support/Code/User/settings.json
./install-extensions.sh
```
