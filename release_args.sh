#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Hook sourced by build/make/release.sh.
update_versions_modify_files() {
  local newReleaseVersion="${1}"
  local valuesYAML="k8s/helm/values.yaml"
  local componentPatchTplYAML="k8s/helm/component-patch-tpl.yaml"

  yq -i ".image.tag = \"${newReleaseVersion}\"" "${valuesYAML}"
  yq -i ".values.images.ldap |= sub(\":[^:]+$\", \":${newReleaseVersion}\")" "${componentPatchTplYAML}"
}

update_versions_stage_modified_files() {
  local valuesYAML="k8s/helm/values.yaml"
  local componentPatchTplYAML="k8s/helm/component-patch-tpl.yaml"

  git add "${valuesYAML}" "${componentPatchTplYAML}"
}
