#!/bin/bash -e
set -eux

echo "VersaNode OS (based on Debian GNU/Linux 13 \"trixie\")" > /etc/versanode-release

sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="VersaNode OS (Debian 13 trixie)"/' /etc/os-release
sed -i 's/^NAME=.*/NAME="VersaNode OS"/' /etc/os-release
sed -i '/^HOME_URL=/a VERSANODE_ID=versanode' /etc/os-release
sed -i '/^BUG_REPORT_URL=/a SUPPORT_URL="https:\/\/github.com\/Versa-Node\/versanode-os\/issues"' /etc/os-release

echo "versanode" > /etc/hostname
sed -i 's/^\(127\.0\.1\.1\s*\).*/\1versanode/' /etc/hosts || echo "127.0.1.1    versanode" >> /etc/hosts
