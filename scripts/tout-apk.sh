#!/bin/bash
tr -d '\r' < /mnt/c/wc14/scripts/tout-arm64.sh > /tmp/t-lf.sh; bash /tmp/t-lf.sh 2>&1 | tail -14
tr -d '\r' < /mnt/c/wc14/scripts/apk.sh > /tmp/ap-lf.sh; bash /tmp/ap-lf.sh < /dev/null
