cmake_minimum_required(VERSION 3.20)
project(lorelei_upstream_tests NONE)

if(NOT DEFINED TEST_MANIFEST)
    message(FATAL_ERROR "TEST_MANIFEST is required")
endif()

enable_testing()
include("${TEST_MANIFEST}")
