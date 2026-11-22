## Дешифрування root_token:

``` shell
jq -r '.root_token' runtime/openbao-host/openbao-service/bootstrap.json |base64 -d | gpg --decrypt && echo
```

## Дешифрування ключів відновлення:

``` shell
jq -r '.recovery_keys_b64[0]' runtime/openbao-host/openbao-service/bootstrap.json |base64 -d | gpg --decrypt && echo
```
або
``` shell
jq -r '.recovery_keys_hex[0]' runtime/openbao-host/openbao-service/bootstrap.json | xxd -r -p | gpg --decrypt && echo
```
