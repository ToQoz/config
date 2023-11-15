
### Export pfx and Install it to Windows

Export pfx from WSL VM.

```
cd "$(mkcert -CAROOT)"
openssl pkcs12 -export -inkey rootCA-key.pem -in rootCA.pem -out rootCA.pfx
explorer.exe .
```

Select `Certificate Store = Trusted Root Certification Authorities`
