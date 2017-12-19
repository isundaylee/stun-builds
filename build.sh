#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO="git@github.com:isundaylee/stun.git"
WD="$DIR/build/stun-builds"
BRANCH="master"
LAST_BUILT_FILE="$DIR/build/stun-builds.last"
PLATFORM=$1

if [[ "$PLATFORM" == "linux" ]]; then
    PLATFORM_NAME='Linux'
elif [[ "$PLATFORM" == "bsd" ]]; then
    PLATFORM_NAME='BSD'
elif [[ "$PLATFORM" == "osx" ]]; then
    PLATFORM_NAME='macOS'
else
    echo "Unknown platform: $PLATFORM"
    exit 1
fi
echo "Running $PLATFORM_NAME builds"

function initialize() {
    if [[ ! -e $WD ]]; then
        git clone "$REPO" "$WD"
    fi
}

function build_commit() {
    commit=$1
    tag=$2
    name=$3

    echo "Building commit $commit as $tag:$name"

    cd $WD
    git checkout $commit
    buck build dist:$PLATFORM

    cd $DIR
    mkdir -p $tag

    cp "$WD/buck-out/gen/dist/$PLATFORM/stun-$PLATFORM.zip" "$tag/$name.zip"
    echo "Build completed and saved to $tag/$name.zip"

    echo $commit > "$LAST_BUILT_FILE"
}

function build_new_commit() {
    cd $WD

    git checkout master
    git pull origin master

    if [[ -z $last_built ]]; then
        commit=$(git rev-parse $BRANCH)
    else
        commit=$(git log --abbrev=40 --pretty=format:"%h" $last_built..master | tail -1)
    fi

    if [[ -z $commit ]]; then
        echo "No new build to do."
        exit 0
    fi

    timestamp=$(git show -s --format=%ct $commit)

    if [[ $(uname) == 'Linux' ]]; then
        date=$(date --date "@$timestamp" +'%Y%m%d-%H%M%S')
    else
        date=$(date -r $timestamp +'%Y%m%d-%H%M%S')
    fi
    build_commit $commit "continuous" "$date-$PLATFORM-$commit"

    cd $DIR

    git add "$tag/$name.zip"
    git commit -m "Builds $commit on $PLATFORM_NAME"
    git pull --rebase origin master
    git push origin master
}

set -e

if [[ -e $LAST_BUILT_FILE ]]; then
    last_built=`cat "$LAST_BUILT_FILE"`
    echo "Last built commit was: $last_built"
else
    last_built=""
    echo "No build has been done yet."
fi

initialize
build_new_commit
