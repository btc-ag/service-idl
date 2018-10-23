Please refer to the [general contribution guidelines for BTC community projects](https://github.com/btc-ag/community/blob/master/CONTRIBUTING.md), and take note of the following guidelines specific to this repository:

As noted in the general contribution guidelines, there are some obstacles to allow to work with forks. In particular, for the service-idl, this currently has the following issue:
- There are integration tests that should be run before merging a branch. Since the dependencies of these integration tests are non-public for now, the artifacts must be deployed from the branch build so that the integration tests can access them. This works easily only from the upstream repository.

There is one repository-specific rerequisite for merging a PR:
- the external [integration tests](https://ci.bop-dev.de/job/cab/job/BF/job/serviceidl-integrationtests/job/master/) must run successfully.
