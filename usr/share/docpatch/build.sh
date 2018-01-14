#!/usr/bin/env bash


## DocPatch -- patching documents that matter
## Copyright (C) 2012-18 Benjamin Heisig <https://benjamin.heisig.name/>
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.


##
## Build script
##


## About this command:
export COMMAND_DESC="$COMMAND_BUILD"


## Checks whether everything is prepared before building the repository.
function checks {
    loginfo "Checking whether everything is prepared before building the repository..."

    logdebug "Checking whether repository is already built..."
    if [ -d "$REPO_DIR" ]; then
        lognotice "Repository is already built."
        askYesNo "Do you want to rebuild it?" || return 1
        rm -rf "$REPO_DIR" || return 1
    else
        logdebug "Repository has not been built yet."
    fi

    logdebug "Checks succeeded."
    return 0
}


## Creates a new repository.
function createRepo {
    loginfo "Creating a new repository..."

    logdebug "Creating directory ${REPO_DIR}..."
    exe "$MKDIR -p $REPO_DIR"
    if [ "$?" -gt 0 ]; then
        logwarning "Cannot create directory '${REPO_DIR}'."
        logerror "Failed to create a new repository."
        return 1
    fi
    logdebug "Directory created."

    logdebug "Changing into directory '${REPO_DIR}'..."
    cd "$REPO_DIR" || return 1

    logdebug "Initiating git repository..."
    exe "$GIT init"
    if [ "$?" -gt 0 ]; then
        logwarning "Cannot initiate git repository under '${REPO_DIR}'."
        logerror "Failed to create a new repository."
        return 1
    fi

    logdebug "New repository is created under '${REPO_DIR}'."
    return 0
}


## Creates meta information.
function createMetaInformation {
    loginfo "Creating meta information..."

    logdebug "Copying docpatch configuration file..."
    exe "$CP $DOCPATCH_CONF_SOURCE $DOCPATCH_CONF_TARGET"
    if [ "$?" -gt 0 ]; then
        logwarning "Cannot copy '${DOCPATCH_CONF_SOURCE}' to '${DOCPATCH_CONF_TARGET}'."
        logerror "Failed to create meta information."
        return 1
    fi
    logdebug "File copied."

    logdebug "Copying git configuration file..."
    if [ ! -r "$GIT_CONF_SOURCE" ]; then
        lognotice "Git configuration file under '${GIT_CONF_SOURCE}' is missing. Please consider creating it before building the repository."
    else
        exe "$CP $GIT_CONF_SOURCE $GIT_CONF_TARGET"
        if [ "$?" -gt 0 ]; then
            logwarning "Cannot copy '${GIT_CONF_SOURCE}' to '${GIT_CONF_TARGET}'."
            logerror "Failed to create meta information."
            return 1
        fi
        logdebug "File copied."
    fi

    logdebug "Copying git ignore file..."
    if [ ! -r "$GIT_IGNORE_SOURCE" ]; then
        lognotice "Git ignore file under '${GIT_IGNORE_SOURCE}' is missing. Please consider creating it before building the repository."
    else
        exe "$CP $GIT_IGNORE_SOURCE $GIT_IGNORE_TARGET"
        if [ "$?" -gt 0 ]; then
            logwarning "Cannot copy '${GIT_IGNORE_SOURCE}' to '${GIT_IGNORE_TARGET}'."
            logerror "Failed to create meta information."
            return 1
        fi
        logdebug "File copied."
    fi

    logdebug "Copying documentation file..."
    if [ ! -r "$README_SOURCE" ]; then
        lognotice "Documentation file under '${README_SOURCE}' is missing. Please consider creating it before building the repository."
    else
        exe "$CP $README_SOURCE $README_TARGET"
        if [ "$?" -gt 0 ]; then
            logwarning "Cannot copy '${README_SOURCE}' to '${README_TARGET}'."
            logerror "Failed to create meta information."
            return 1
        fi
        logdebug "File copied."
    fi

    logdebug "Copying meta JSON file..."
    if [ ! -r "$META_JSON_SOURCE" ]; then
        lognotice "Meta JSON file under '${META_JSON_SOURCE}' is missing. Please consider creating it before building the repository."
    else
        exe "$CP $META_JSON_SOURCE $META_JSON_TARGET"
        if [ "$?" -gt 0 ]; then
            logwarning "Cannot copy '${META_JSON_SOURCE}' to '${META_JSON_TARGET}'."
            logerror "Failed to create meta JSON file."
            return 1
        fi
        logdebug "File copied."
    fi

    logdebug "Meta information created."
    return 0
}


## Creates intitial version.
function createInitialVersion {
    loginfo "Creating initial version..."

    copyDocuments
    if [ "$?" -gt 0 ]; then
        logerror "Failed to create initial version."
        return 1
    fi

    logdebug "Initial version created."
    return 0
}


## Creates all revisions.
function createRevisions {
    local message_head
    local commit_date

    loginfo "Creating all revisions..."

    logdebug "Checking series file..."
    local series_file="${PATCH_DIR}/series"
    if [ ! -r "$series_file" ]; then
        logwarning "Cannot access series file '${series_file}'."
        logerror "Failed to create all revisions."
        return 1
    fi

    logdebug "Iterating through each patch..."
    while read patch ; do
        logdebug "Handling patch '${patch}'..."

        logdebug "Checking patch file..."
        local patch_file="${PATCH_DIR}/$patch"
        if [ ! -r "$patch_file" ]; then
            logwarning "Cannot access patch file '${patch_file}'."
            logerror "Failed to create all revisions."
            rewindPatches
            return 1
        fi
        logdebug "Patch file '${patch_file}' is ready to apply."

        logdebug "Checking message file..."
        local meta_file="${META_DIR}/${patch}.meta"
        if [ ! -r "$meta_file" ]; then
            logwarning "Cannot access message file '${meta_file}'."
            logerror "Failed to create all revisions."
            rewindPatches
            return 1
        fi

        nextPatch
        if [ "$?" -gt 0 ]; then
            logerror "Failed to create all revisions."
            rewindPatches
            return 1
        fi

        copyDocuments
        if [ "$?" -gt 0 ]; then
            logerror "Failed to create all revisions."
            rewindPatches
            return 1
        fi

        message_head=`"$HEAD" -n1 $meta_file`
        commit_date=`date -d "$(cat $meta_file | grep "Date" | cut -d " " -f 2)" +%s`

        addAndCommitAll "$message_head" "$commit_date"
        if [ "$?" -gt 0 ]; then
            logerror "Failed to create all revisions."
            rewindPatches
            return 1
        fi

        createTag "$patch" "$meta_file"
        if [ "$?" -gt 0 ]; then
            logerror "Failed to create all revisions."
            rewindPatches
            return 1
        fi

        logdebug "Finished with patch '${patch}'."
    done < "$series_file"
    logdebug "Each patch applied."

    rewindPatches
    if [ "$?" -gt 0 ]; then
        logerror "Failed to create all revisions."
        return 1
    fi

    logdebug "All revisions created."
    return 0
}


## Applies next patch.
function nextPatch {
    loginfo "Applying next patch..."

    logdebug "Changing into directory '${SRC_DIR}'..."
    cd "$SRC_DIR" || return 1

    logdebug "Calling quilt..."
    exe "$QUILT push"
    if [ "$?" -gt 0 ]; then
        logerror "Failed to apply next patch."
        return 1
    fi

    logdebug "Next patch applied."
    return 0
}


## Reverts all applied patches.
function rewindPatches {
    loginfo "Reverting all applied patches..."

    logdebug "Changing into directory '${SRC_DIR}'..."
    cd "$SRC_DIR" || return 1

    logdebug "Calling quilt..."
    exe "$QUILT pop -a"
    if [ "$?" -gt 0 ]; then
        logerror "Failed to revert all applied patches."
        return 1
    fi

    logdebug "All applied patches reverted."
    return 0
}


## Puts all files under version control and commits them.
##   $1 Commit message or file
##   $2 Commit date
function addAndCommitAll {
    loginfo "Putting all files under version control and committing them."

    logdebug "Changing into directory '${REPO_DIR}'..."
    cd "$REPO_DIR" || return 1

    logdebug "Putting all files under version control..."
    exe "$GIT add --all --force"
    if [ "$?" -gt 0 ]; then
        logwarning "Cannot put all files under version control"
        logerror "Failed to put all files under version control and commit them."
        return 1
    fi
    logdebug "Putting was successful."

    logdebug "Checking commit message..."
    if [ -z "$1" ]; then
        logwarning "There is no commit message."
        logerror "Failed to put all files under version control and commit them."
        return 1
    fi
    logdebug "Commit messages seems okay."

    logdebug "Checking commit date..."
    if [ -z "$2" ]; then
        logwarning "There is no commit date."
        local commit_date=0
    else
        local commit_date=$2
    fi
    logdebug "Commit date seems okay."


    logdebug "Committing files..."
    if [ -r "$1" ]; then
        logdebug "Take commit message from '${1}'."

        exe "$GIT commit --all --file $1"
        if [ "$?" -gt 0 ]; then
            logwarning "Cannot commit files."
            logerror "Failed to put all files under version control and commit them."
            return 1
        fi
    else
        logdebug "Take commit message from command line."

        # TODO This is a workaround because using --message causes the git error
        # "Paths with -a does not make sense."
        logdebug "Writing message to file..."
        local msg_file="${TMP_DIR}/${PID}_commit_msg"
        "$ECHO" "$1" > "$msg_file"

        exe "$GIT commit --all --file $msg_file"
        if [ "$?" -gt 0 ]; then
            logwarning "Cannot commit files."
            logerror "Failed to put all files under version control and commit them."
            return 1
        fi
    fi

    if [ "$COMMIT_DATES" != "now" ]; then
        if [[ "$COMMIT_DATES" = "valid" && "$commit_date" -lt 0 ]]; then
            commit_date=1
        fi

        exe "$GIT cat-file -p HEAD > $TMP_DIR/head.txt"
        exe "sed -i 's/> [0-9]\+ /> $commit_date /g' $TMP_DIR/head.txt"
        exe "$GIT hash-object -t commit -w $TMP_DIR/head.txt > $TMP_DIR/commit.txt"
        exe "$GIT update-ref -m 'commit: $1' refs/heads/master $(cat $TMP_DIR/commit.txt)"
        exe "rm $TMP_DIR/head.txt $TMP_DIR/commit.txt"
    fi

    logdebug "Commit was successful."

    logdebug "All files put under version control and committed."
    return 0
}


## Tags current revision.
##   $1 Version number
##   $2 Path to message file
function createTag {
    loginfo "Tagging current revision..."

    logdebug "Checking version number..."
    if [ "$1" -lt 0 ]; then
        logwarning "Version number is invalid."
        logerror "Failed to tag current revision."
        return 1
    fi
    logdebug "Version number is '${1}'."

    logdebug "Checking message file..."
    if [ ! -r "$2" ]; then
        logwarning "Cannot access message file."
        logerror "Failed to tag current revision."
        return 1
    fi
    logdebug "Message file is '${2}'."

    logdebug "Changing into directory '${REPO_DIR}'..."
    cd "$REPO_DIR" || return 1

    local cmd="$GIT tag"

    logdebug "Check whether tag will be signed..."
    if [ "$SIGN" -eq 1 ]; then
        logdebug "Tag will be signed."
        cmd="$cmd -s"
    else
        logdebug "Tag won\'t be signed."
    fi

    cmd="$cmd -F $2 $1"

    logdebug "Calling git-tag..."
    exe "$cmd"
    if [ "$?" -gt 0 ]; then
        logwarning "Failed to call git-tag."
        logerror "Failed to tag current revision."
        return 1
    fi
    logdebug "git-tag succeeded."

    logdebug "Revision tagged."
    return 0
}


## Counts patches.
## TODO unused code
function countPatches {
    loginfo "Counting patches..."

    PATCHES=`"$CAT" "$PATCH_DIR"/series | "$WC" -l`
    if [ "$?" -gt 0 ]; then
        logerror "Cannot count patches."
        return 1
    fi

    if [ "$PATCHES" -eq 1 ]; then
        logdebug "There is 1 patch."
    else
        logdebug "There are $PATCHES patches."
    fi

    logdebug "Patches counted."
    return 0
}


## Copies documents from source directory to repository.
function copyDocuments {
    loginfo "Copying documents..."

    logdebug "Source files: ${SRC_DIR}/*$INPUT_FORMAT_EXT"
    logdebug "Target directory: $REPO_DIR"

    exe "$CP ${SRC_DIR}/*$INPUT_FORMAT_EXT $REPO_DIR"
    if [ "$?" -gt 0 ]; then
        logerror "Failed to copy documents."
        return 1
    fi

    logdebug "Documents copied."
    return 0
}


## Main method
function main {
    local commit_title=""
    local commit_date=0

    checks || abort 11

    createRepo || abort 12

    createMetaInformation || abort 13
    #local message="Import meta information."
    #addAndCommitAll "$message" "-650419200" || abort 14
    #lognotice "$message"

    createInitialVersion || abort 15

    lognotice "Importing initial version..."
    commit_title=$(head -1 ${META_DIR}/0.meta)
    commit_date=$(date -d "$(cat ${META_DIR}/0.meta | grep "Announced" | cut -d " " -f 2)" +%s)
    addAndCommitAll "$commit_title" "$commit_date" || abort 16
    createTag "0" "${META_DIR}/0.meta" || abort 17

    lognotice "Importing revisions..."
    createRevisions || abort 18
}


## Prints command specific options.
function printCommandOptions {
    loginfo "Printing command specific options..."
    prntLn "    -s, --sign\t\tAdd a OpenPGP signature to commits and tags."
    prntLn "    --orig-dates\tUse real dates from \"Date\" for commit dates; may break because of negative UNIX timestamps"
    prntLn "    --valid-dates\tUse real dates but set older dates before 1970-01-01 to this date"
    logdebug "Options printed."
    return 0
}
