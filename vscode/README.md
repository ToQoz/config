## VSCode

## Windows

```
CMD> del %USERPROFILE%\AppData\Roaming\Code\User\settings.json
CMD> mklink %USERPROFILE%\AppData\Roaming\Code\User\settings.json <config>\settings.json
<config>\windows\install-extensions.bat
```

## macOS

```
ln -sf $(git rev-parse --show-toplevel)/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
sh $(git rev-parse --show-toplevel)/vscode/install-extensions.bash
```