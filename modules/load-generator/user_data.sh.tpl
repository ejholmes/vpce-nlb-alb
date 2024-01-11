#!/usr/bin/bash

set -exo pipefail

curl https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 > /usr/local/bin/hey && chmod +x /usr/local/bin/hey

exec /usr/local/bin/hey -z 1h -q 20 -disable-keepalive http://${endpoint} > /tmp/results.txt
