# Set these to the desired values
COMPONENT_IMAGE?=registry.cloudogu.com/k8s/ldap:$(VERSION)
COMPONENT_ARTIFACT_ID?=lop-idp-ldap
COMPONENT_VERSION?=$(VERSION)
COMPONENT_BUILD_IMAGE?=cloudogu/$(COMPONENT_ARTIFACT_ID):$(COMPONENT_VERSION)
ARTIFACT_ID?=$(COMPONENT_ARTIFACT_ID)
IMAGE?=$(COMPONENT_BUILD_IMAGE)
GOTAG?=1.26.0
BINARY_HELM_VERSION?=v3.20.0

STAGE?=production

include build/make/variables.mk
include build/make/clean.mk

K8S_COMPONENT_SOURCE_VALUES = ${HELM_SOURCE_DIR}/values.yaml
K8S_COMPONENT_TARGET_VALUES = ${HELM_TARGET_DIR}/values.yaml
HELM_PRE_GENERATE_TARGETS = helm-values-update-image-version
HELM_POST_GENERATE_TARGETS = helm-values-replace-image-repo template-image-pull-policy
IMAGE_IMPORT_TARGET=image-import

CHECK_VAR_TARGETS=check-all-vars-without-image
HELM_SOURCE_DIR=k8s/helm

include build/make/k8s-component.mk

.PHONY: docker-build-component
docker-build-component:
	@echo "Building component image $(COMPONENT_IMAGE)..."
	@DOCKER_BUILDKIT=1 docker build --target component -t $(COMPONENT_IMAGE) .

.PHONY: component-build
component-build: docker-build-component

.PHONY: helm-values-update-image-version
helm-values-update-image-version: $(BINARY_YQ)
	@echo "Updating the image version in source values.yaml to ${VERSION}..."
	@$(BINARY_YQ) -i e ".image.tag = \"${VERSION}\"" ${K8S_COMPONENT_SOURCE_VALUES}

.PHONY: helm-values-replace-image-repo
helm-values-replace-image-repo: $(BINARY_YQ)
	@if [[ ${STAGE} == "development" ]]; then \
      		echo "Setting dev image repo in target values.yaml!" ;\
    		$(BINARY_YQ) -i e ".image.registry=\"$(shell echo '${IMAGE_DEV}' | sed 's/\([^\/]*\)\/\(.*\)/\1/')\"" ${K8S_COMPONENT_TARGET_VALUES} ;\
    		$(BINARY_YQ) -i e ".image.repository=\"$(shell echo '${IMAGE_DEV}' | sed 's/\([^\/]*\)\/\(.*\)/\2/')\"" ${K8S_COMPONENT_TARGET_VALUES} ;\
    	fi

.PHONY: template-image-pull-policy
template-image-pull-policy: $(BINARY_YQ)
	@if [[ "${STAGE}" == "development" ]]; then \
          echo "Setting pull policy to always!" ; \
          $(BINARY_YQ) -i e ".imagePullPolicy=\"Always\"" "${K8S_COMPONENT_TARGET_VALUES}" ; \
    fi
