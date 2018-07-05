[![Build Status](https://travis-ci.org/btc-ag/service-idl.svg?branch=master)](https://travis-ci.org/btc-ag/service-idl)

[![codecov](https://codecov.io/gh/btc-ag/service-idl/branch/master/graph/badge.svg)](https://codecov.io/gh/btc-ag/service-idl)

[![Download](https://api.bintray.com/packages/btc-ag/service-idl/service-idl/images/download.svg)](https://bintray.com/btc-ag/service-idl/service-idl/_latestVersion)

This repository contains a Service IDL defined in Xtext, and several code generators for C++, Java, .NET and Google Protocol Buffers.

It is currently experimental, and not yet suitable for general use.

Using the standalone command line generator
===========================================

There is no release yet, but you can download the current snapshot from https://oss.jfrog.org/artifactory/oss-snapshot-local/com/btc/serviceidl/com.btc.serviceidl.plainjava/1.0.0-SNAPSHOT/com.btc.serviceidl.plainjava-1.0.0-SNAPSHOT.jar

When you downloaded it, you need to specify an IDL input file and output directories, which must already exist. You can either specify a common output directory for all target technologies:
```
java -jar com.btc.serviceidl.plainjava-1.0.0-SNAPSHOT.jar input.idl -outputPath out -cppProjectSystem cmake
```
Alternatively, you can specify specific output directories for each target technology, in which case only the generators for target technologies with a specified output directory will be used. 
For example, the following command will only generate .NET artifacts:
```
java -jar com.btc.serviceidl.plainjava-1.0.0-SNAPSHOT.jar input.idl -dotnetOutputPath outDotNet
```

Currently, the generator generates all artifacts (API, Proxy, Dispatcher, ...) for all target technologies (C++, C#/.NET, Java). This will be made configurable in the future.

Dependencies of generated code
==============================

Note: All generated C++ code, and the Proxy/Dispatcher/Codec modules generated by the .NET and Java code generators, currently depend on proprietary libraries. These may be made open-source in the future.

| Target technology | Main dependency          | Supported versions |
| ----------------- | ---------------          | ------------------ |
| C++               | BTC.CAB.ServiceComm[.SQ] | cpp.servicecomm: 0.10, 0.11, 0.12 |
| .NET              | BTC.CAB.ServiceComm.NET  | 0.6 |
| Java              | BTC.CAB.ServiceComm.Java | java.servicecomm: 0.3, 0.5 |

The default version is always the most recent version. An older version may be specified for the command line generator with the `-versions` parameter, e.g.
```
java -jar com.btc.serviceidl.plainjava-1.0.0-SNAPSHOT.jar input.idl -outputPath out -cppProjectSystem cmake -versions cpp.servicecomm=0.10
```

Currently generated .NET code is targeting .NET Framework version 4.6 or any compatible version.

Configuration when using the Eclipse plug-ins
=============================================

Configuration of the above-mentioned settings is also possible when using the Eclipse plug-ins, although no UI is provided for that.

Properties files can be placed in parallel to the IDL file, either at directory scope (.generator) or at file scope (foo.idl.generator). If both are present, first 
the settings from the directory scope properties are applied, and then the settings from the file scope properties, which may override the above.

The output directories cannot be configured via the properties files at the moment.

The command line runner also interprets these files. Command line options override both the directory and file scope properties in that case.

An example file would look like this:
```
languages = java,cpp
projectSystem = cmake
projectSet = full
versions = cpp.servicecomm=0.10
```

Contributing
============

See the [contribution guidelines](CONTRIBUTING.md).

Frequently Asked Questions
==========================

See [FAQ](FAQ.md).
