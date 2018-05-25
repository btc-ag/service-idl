[![Build Status](https://travis-ci.org/btc-ag/service-idl.svg?branch=master)](https://travis-ci.org/btc-ag/service-idl)

[![codecov](https://codecov.io/gh/btc-ag/service-idl/branch/master/graph/badge.svg)](https://codecov.io/gh/btc-ag/service-idl)

[![Download](https://api.bintray.com/packages/btc-ag/service-idl/service-idl/images/download.svg)](https://bintray.com/btc-ag/service-idl/service-idl/_latestVersion)

This repository contains a Service IDL defined in Xtext, and several code generators for C++, Java, .NET and Google Protocol Buffers.

It is currently experimental, and not yet suitable for general use.

Using the standalone command line generator
===========================================

There is no release yet, but you can download the current snapshot from https://oss.jfrog.org/artifactory/oss-snapshot-local/com/btc/serviceidl/com.btc.serviceidl.plainjava/1.0.0-SNAPSHOT/com.btc.serviceidl.plainjava-1.0.0-SNAPSHOT.jar

When you downloaded it, you need to specify an IDL input file and an output directory, which must already exist:
```
java -jar com.btc.serviceidl.plainjava-1.0.0-SNAPSHOT.jar input.idl -outputPath out -cppProjectSystem cmake
```

Currently, the generator generates all artifacts (API, Proxy, Dispatcher, ...) for all target technologies (C++, C#/.NET, Java). This will be made configurable in the future.

Contributing
============

See the [contribution guidelines](CONTRIBUTING.md).
