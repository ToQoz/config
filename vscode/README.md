## VSCode

## Windows

```
CMD> del %USERPROFILE%\AppData\Roaming\Code\User\settings.json
CMD> mklink %USERPROFILE%\AppData\Roaming\Code\User\settings.json <config>\settings.json

CMD> del %USERPROFILE%\AppData\Roaming\Code\User\extensions.json
CMD> mklink %USERPROFILE%\AppData\Roaming\Code\User\extensions.json <config>\extensions.json
```

## macOS

```
ln -sf <config>/settings.json ~/.vscode/settings.json
ln -sf <config>/extensions.json ~/.vscode/extensions.json
```