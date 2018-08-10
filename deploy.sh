#!/bin/bash
set -x -e

if [ "$TRAVIS" != "true" ] ; then 
    echo "Not running on travis, not supported at the moment"
    exit 1
fi

cp .travis.settings.xml $HOME/.m2/settings.xml

if [[ "$TRAVIS_BRANCH" =~ ^release/ ]] ; then 
    RELEASE_VERSION=$(echo "$TRAVIS_BRANCH" | sed -e "s/release[/]//")

    if ! [[ "${RELEASE_VERSION}" =~ [0-9]+[.][0-9]+[.][0-9]+ ]] ; then
        echo "Invalid branch name: $TRAVIS_BRANCH"
        exit 1
    fi

    POM_VERSION=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | sed -n -e '/^\[.*\]/ !{ /^[0-9]/ { p; q } }'`

    if [ "${RELEASE_VERSION}-SNAPSHOT" != "${POM_VERSION}" ] ; then
        echo "Branch version ${RELEASE_VERSION} is not a SNAPSHOT or does not match POM version ${POM_VERSION}, assuming release was already done"
        exit 0
    fi

    # MANIFEST.MF files might have been modified during previous steps, so we need to revert 
    # these changes before release:prepare
    git stash save

    # Unshallow local repo to allow mvn release to work
    git fetch --unshallow
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin

    # Checkout branch (travis-ci has checked out the commit hash)
    # Note: if the branch has been updated in between, this will use a newer 
    # revision than before, but for making the release this should not usually 
    # happen, and should not matter anyway, since the newer revision would be 
    # used by a subsequent build and overwrite the tag
    git checkout $TRAVIS_BRANCH

    DEVELOPMENT_VERSION=$(python -c 'version = tuple(map(int, ("'${RELEASE_VERSION}'".split(".")))); print("%i.%i.%i" % (version[0], version[1]+1, 0))')
    
    mvn -B release:prepare -DreleaseVersion=${RELEASE_VERSION} -DdevelopmentVersion=${DEVELOPMENT_VERSION}-SNAPSHOT
    
    git config remote.origin.url https://sigiesec:${GITHUB_TOKEN}@github.com/btc-ag/service-idl.git
    git push origin v${RELEASE_VERSION}
    git push
    
    curl --fail -u sigiesec:${GITHUB_TOKEN} -X POST -d '{"title":"Start next development iteration after '${RELEASE_VERSION}' release", "base":"master", "head":"'${TRAVIS_BRANCH}'"}' https://api.github.com/repos/btc-ag/service-idl/pulls
elif [ "$TRAVIS_TAG" == "" ] ; then
    SNAPSHOT_FRAGMENT="-SNAPSHOT"
    BASE_VERSION=`mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | sed -n -e '/^\[.*\]/ !{ /^[0-9]/ { p; q } }' | sed -e 's/-SNAPSHOT//'`

    if [ "$TRAVIS_PULL_REQUEST" == "false" ] ; then
        if [ "$TRAVIS_BRANCH" != "master" ] ; then
            BRANCH_FRAGMENT="-${TRAVIS_BRANCH////-}"
        else
            BRANCH_FRAGMENT=""
        fi
    else
        BRANCH_FRAGMENT="-pr${TRAVIS_PULL_REQUEST}"
    fi

    cd com.btc.serviceidl.plainjava && mvn versions:set -DnewVersion=${BASE_VERSION}${BRANCH_FRAGMENT}${SNAPSHOT_FRAGMENT}

    mvn deploy -DskipTests
else
    # TODO alternatively, release:perform could be executed, but this would check out the same version that we are building right now; 
    # or, we could run this in the branch build job, and do nothing in the tag build job; the latter would allow us to only push the branch changes if the release was successful    
    
    ## write release.properties file, since the tag cannot be specified on the command line
    #echo scm.url=scm:git:https://github.com/btc-ag/service-idl.git >release.properties
    #echo scm.tag=${TRAVIS_TAG} >>release.properties    
    #rm .meta/p2-artifacts.properties
    #mvn -B release:perform
    
    mvn deploy -DskipTests
fi
