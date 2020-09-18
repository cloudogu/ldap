#!/bin/bash
set -o errexit
set -o nounset
set -o
FROM_VERSION="${1}"
TO_VERSION="${2}"
WAIT_TIMEOUT=600
CURL_LOG_LEVEL="--silent"
FAILED_PLUGIN_NAMES=""

##### functions declaration
######

echo "Running post-upgrade script..."

if [[ ${FROM_VERSION} =~ ^2.4.4((4-.*)|(7-.*)|(4-.*))$ ]]; then
  echo "Set add_unique to true..."
  doguctl config add_unique "true"
fi

doguctl config post_upgrade_running false
