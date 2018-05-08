#!/bin/bash
set -x -e

BASE_VERSION=1.0.0

if [ "$TRAVIS" != "true" ] ; then 
    echo "Not running on travis, not supported at the moment"
    exit 1
fi

if [ "$TRAVIS_PULL_REQUEST" == "false" ] ; then
    if [ "$TRAVIS_BRANCH" != "master" ] ; then
        BRANCH_FRAGMENT="-${TRAVIS_BRANCH////-}"
    else
        BRANCH_FRAGMENT=""
    fi
else
    BRANCH_FRAGMENT="-pr${TRAVIS_PULL_REQUEST}"
fi

SNAPSHOT_FRAGMENT="-SNAPSHOT" # TODO suppress on a release tag

cd com.btc.serviceidl.plainjava && mvn versions:set -DnewVersion=${BASE_VERSION}${BRANCH_FRAGMENT}${SNAPSHOT_FRAGMENT}

mvn deploy -DskipTests
