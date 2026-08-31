#!/usr/bin/env bash

# Some downloaders consult only one spelling of the conventional proxy
# variables. Fill an empty spelling from its configured counterpart while
# preserving explicitly configured, non-empty values on both sides.
normalize_proxy_environment() {
    if [[ -z ${HTTP_PROXY:-} && -n ${http_proxy:-} ]]; then
        export HTTP_PROXY=$http_proxy
    fi
    if [[ -z ${http_proxy:-} && -n ${HTTP_PROXY:-} ]]; then
        export http_proxy=$HTTP_PROXY
    fi

    if [[ -z ${HTTPS_PROXY:-} && -n ${https_proxy:-} ]]; then
        export HTTPS_PROXY=$https_proxy
    fi
    if [[ -z ${https_proxy:-} && -n ${HTTPS_PROXY:-} ]]; then
        export https_proxy=$HTTPS_PROXY
    fi

    if [[ -z ${NO_PROXY:-} && -n ${no_proxy:-} ]]; then
        export NO_PROXY=$no_proxy
    fi
    if [[ -z ${no_proxy:-} && -n ${NO_PROXY:-} ]]; then
        export no_proxy=$NO_PROXY
    fi
}
