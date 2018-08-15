Git workflow for contributions
==============================

In principle, the [forking workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/forking-workflow) should be used. 
However, there are currently some obstacles to this:
- There are integration tests that should be run before merging a branch. Since the dependencies of these integration tests
  are non-public for now, the artifacts must be deployed from the branch build so that the integration tests can access them.
  This works easily only from the upstream repository.

Therefore, for now, you should create feature branches in the upstream repository, but treat them as if they were branches in a fork. 
To mark them as yours, start the branch name with your GitHub user name.

The following examples assume the remote name for the upstream repo is `upstream` and your GitHub user name is `myname`.

To start a new branch, use the following commands:
```
git checkout -b myname-add-cool-new-feature upstream/master
git push -u upstream myname-add-cool-new-feature
```

Work in your feature branch
---------------------------

While you work in your feature branch, you may in principle do whatever you want, but it makes sense to keep the Prerequisites for merging a PR (see below) in mind, to avoid unnecessary rework. Please be polite to the reviewers, and check these prerequisites for yourself.

For example, you can use `git commit --fixup <SHA1>` to mark changes as a fixup to any previous commit with the given hash, but keeping them as a separate commit for the moment (which you can easily revert again). When you are satisfied with your feature branch, you can semi-automatically squash these fixup commits with their respective base commits by using the following commands:
```
git rebase -i upstream/master # this opens an editor, where the fixups are automatically rearranged
git push --force-with-lease
```

To update your branch when the upstream master has changed, use the following commands: 
```
git fetch upstream
git rebase upstream/master # this may require resolving conflicts
git push --force-with-lease
```
You should do this regularly to avoid conflicts to accumulate, which makes them harder to resolve.

Once your branch is ready for review, go to your branch web URL, e.g. https://github.com/btc-ag/service-idl/tree/myname-add-cool-new-feature and click on "Compare & Pull Request".

If you think the branch is ready for review, but not yet for merging, please include the prefix "[WiP]" (work in progress) in the title.

Prerequisites for merging a PR
------------------------------

Generally, the status checks must be successful for a PR to be merged, i.e.
* build and test CI jobs must run successfully
* the changes must have been reviewed, and all open discussions either resolved in the code (possibly by adding TODO comments), or [GitHub issues](https://github.com/btc-ag/service-idl/issues) been created (for larger-scale issues).

In addition, 
* no merge or fixup commits must be contained in the branch,
* the external [integration tests](https://ci.bop-dev.de/job/cab/job/BF/job/serviceidl-integrationtests/job/master/) must run successfully.

### Compatibility

Changes must generally be backwards-compatible.

Features that should be removed must be declared as deprecated first. They can only be removed in the next major revision, and only if there are no substantial objections to removal.

### Scope of a PR

The scope of a PR may vary dramatically. A small PR might contain a single fix for a spelling error. A large PR might contribute support for a new target language.

While in principle, a PR may combine unrelated changes as long as the conventions for each individual commit are upheld, it is usually not advisable to make a PR unnecessarily large. This makes it harder to review, and may prolong the time the PR is not ready for merge, require repeated rebasing, and thus unnecessary work.

When it turns out that a PR contains separable parts, some of which are already ready to merge, and some are not, it may make sense to split the PR up (and therefore the feature branch it was created from), so that the ready-to-merge parts can be merged immediately.

### Scope of a commit

Each commit should be a transition from a buildable state to a buildable state. (Tests may be broken by an individual commit).

Each commit should have a specific focus. Do not mix separable changes in a single commit. If you write an enumeration of different aspects in the commit messages, this is a strong indication that a commit should be split up.

If you try out different solutions in development, and create a series of commits for the different attempts, these should be squashed together before the PR is merged, regardless of whether they are marked as fixup commits or not.

### Commit messages

At the moment, no specific conventions for commit messages are in effect. However, they should be concise and specific. A commit should not contain any changes that cannot be easily related to the commit message.

### Test/code coverage

The changes in a PR should be covered by tests. In case of an internal refactoring, this may already be sufficiently achieved by existing tests. In case of new features, this will require adding tests as well. In case code that was previously uncovered by tests is being changed, it is advisable to add tests first. This may be more stringently enforced after the first release has been made.

### Formatting

Ensure proper formatting of all files. For Java and Xtend, use the Eclipse formatter.

Use the following workspace settings for the Java formatter, which are used by the Xtend formatter:
* Tab policy: Spaces only
* Indentation size: 4

Unfortunately, they cannot be set in the project settings as of Xtend 2.14 (see https://bugs.eclipse.org/bugs/show_bug.cgi?id=405956).

Currently, this is not automatically checked and it is hard to check this manually, so please handle this responsibly.

### Xtend code style

In general, all conventions under http://wiki.e-konzern.de/display/BTCCABCOM/Conventions apply (not available publicly at the time of writing).

There are some specific conventions regarding Xtend code style:
* Access and storage class modifiers for members
** Order: Always place the access modifier ('public', 'protected', 'private') first (if any), then maybe the storage class modifier 'static', and then 'def', 'override', 'val' or 'var'.
** DO NOT specify the default access modifier explicitly. Attributes are private by default, methods are public by default.
* Use of return
** A function should not use an explicit return if it consists only of a single expression, regardless of its complexity, which is preceded by a sequence of final variable declarations
* Declaration of return type
** A function should declare a return type if and only if
*** it cannot be inferred, or
*** the desired return type is more general than the inferred return type (i.e. to hide implementation details)
