

$(/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | /usr/bin/jq -r --arg lbl "${label}" '.[] | select(.label | contains($lbl)) | .id')
