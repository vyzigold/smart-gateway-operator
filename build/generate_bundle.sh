#!/usr/bin/env bash
set -e
REL=$(dirname "$0")

# shellcheck source=build/metadata.sh
. "${REL}/metadata.sh"

generate_version() {
    echo "-- Generating operator version"
    UNIXDATE=$(date '+%s')
    OPERATOR_BUNDLE_VERSION=${OPERATOR_CSV_MAJOR_VERSION}.${UNIXDATE}
    echo "---- Operator Version: ${OPERATOR_BUNDLE_VERSION}"
}

create_working_dir() {
    echo "-- Create working directory"
    WORKING_DIR=${WORKING_DIR:-"/tmp/${OPERATOR_NAME}-bundle-${OPERATOR_BUNDLE_VERSION}"}
    mkdir -p "${WORKING_DIR}"
    echo "---- Created working directory: ${WORKING_DIR}"
}

generate_dockerfile() {
    echo "-- Generate Dockerfile for bundle"
    sed -E "s#<<OPERATOR_BUNDLE_VERSION>>#${OPERATOR_BUNDLE_VERSION}#g;s#<<BUNDLE_CHANNELS>>#${BUNDLE_CHANNELS}#g;s#<<BUNDLE_DEFAULT_CHANNEL>>#${BUNDLE_DEFAULT_CHANNEL}#g" "${REL}/../${BUNDLE_PATH}/Dockerfile.in" > "${WORKING_DIR}/Dockerfile"
    echo "---- Generated Dockerfile complete"
}

generate_bundle() {
    echo "-- Generate bundle"
    REPLACE_REGEX="s#<<CREATED_DATE>>#${CREATED_DATE}#g;s#<<OPERATOR_IMAGE>>#${OPERATOR_IMAGE}#g;s#<<OPERATOR_TAG>>#${OPERATOR_TAG}#g;s#<<RELATED_IMAGE_BRIDGE_SMARTGATEWAY>>#${RELATED_IMAGE_BRIDGE_SMARTGATEWAY}#g;s#<<RELATED_IMAGE_BRIDGE_SMARTGATEWAY_TAG>>#${RELATED_IMAGE_BRIDGE_SMARTGATEWAY_TAG}#g;s#<<RELATED_IMAGE_CORE_SMARTGATEWAY>>#${RELATED_IMAGE_CORE_SMARTGATEWAY}#g;s#<<RELATED_IMAGE_CORE_SMARTGATEWAY_TAG>>#${RELATED_IMAGE_CORE_SMARTGATEWAY_TAG}#g;s#<<OPERATOR_BUNDLE_VERSION>>#${OPERATOR_BUNDLE_VERSION}#g;s#1.99.0#${OPERATOR_BUNDLE_VERSION}#g;s#<<BUNDLE_OLM_SKIP_RANGE_LOWER_BOUND>>#${BUNDLE_OLM_SKIP_RANGE_LOWER_BOUND}#g"

    pushd "${REL}/../"
    ${OPERATOR_SDK} generate bundle --channels ${BUNDLE_CHANNELS} --default-channel ${BUNDLE_DEFAULT_CHANNEL} --manifests --metadata --version "${OPERATOR_BUNDLE_VERSION}" --output-dir "${WORKING_DIR}"  --package ${OPERATOR_NAME}
    popd

    echo "---- Replacing variables in generated manifest"
    sed -i -E "${REPLACE_REGEX}" "${WORKING_DIR}/manifests/${OPERATOR_NAME}.clusterserviceversion.yaml"
    echo "---- Generated bundle complete at ${WORKING_DIR}/manifests/${OPERATOR_NAME}.clusterserviceversion.yaml"
}

build_bundle_instructions() {
    echo "-- Commands to create a bundle build"
    echo docker build -t "${OPERATOR_BUNDLE_IMAGE}:${OPERATOR_BUNDLE_VERSION}" -f "${WORKING_DIR}/Dockerfile" "${WORKING_DIR}"
    echo docker push ${OPERATOR_BUNDLE_IMAGE}:${OPERATOR_BUNDLE_VERSION}
}


# generate templates
echo "## Begin bundle creation"
generate_version
create_working_dir
generate_dockerfile
generate_bundle
build_bundle_instructions
echo "## End Bundle creation"
