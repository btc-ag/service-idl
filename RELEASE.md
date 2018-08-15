Performing a release
====================

To perform a release, check first that the version in the master branch is set to the desired
version as a SNAPSHOT version. Please follow the ideas of semantic versioning when determining 
the next version number. 

For example, if you intend to publish a new minor release 1.5.0, the current version must be 
set to 1.5.0-SNAPSHOT files. 

If it is not, run the following commands locally:

    mvn versions:set -DnewVersion=1.5.0-SNAPSHOT
    mvn tycho-versions:update-eclipse-metadata

Then add, commit and push the changes, and merge them into master via a pull request.

After that, create a new branch from master with the name release/<versionNumber>, e.g. 
release/1.5.0. You can do this via the GitHub UI or locally using:

    git branch release/1.5.0
    git push -u origin release/1.5.0

This will trigger the TravisCI jobs that perform the release, i.e. 
* create a version tag in the repository
* create a release in GitHub
* upload release artifacts to oss.jfrog.org and GitHub

It does not create release notes yet.

In addition, it will create a pull request that will update the versions to the SNAPSHOT 
version of the next minor version, which you can merge into master, and then continue 
development. It is important that this pull request is merged before any other pull requests 
might be merged, since this would make the history of the master and the tagged version 
inconsistent.
