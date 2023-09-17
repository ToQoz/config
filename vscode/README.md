## VSCode

## Windows

```
CMD> del %USERPROFILE%\AppData\Roaming\Code\User\settings.json
CMD> mklink %USERPROFILE%\AppData\Roaming\Code\User\settings.json <repository>\vscode\settings.json
CMD> <repository>\vscode\windows\install-extensions.bat
```

## macOS

```
ln -sf <repository>/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
sh <repository>/vscode/install-extensions.bash
```
