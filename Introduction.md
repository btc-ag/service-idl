Introduction to the Service IDL
===============================

This document provides an introduction to the Service IDL.

Basic idea of the Service IDL
=============================

The idea of the Service IDL is to provide the means to define Service
APIs. We use the term "Service API" to denote APIs that are aimed at
remote usage, i.e. between different machines or different processes on
the same machine. Service APIs are therefore to be distinguished from
object-oriented APIs that are intended for local, intra-process usage
only. However, Service APIs should provide location transparency, i.e.
the direct user should not know whether the provider is located in the
same process, a different process on the same machine or on a different
machine. Service APIs should therefore be provided as regular interfaces
in the respective programming language. The implementation of such an
interface may either be a local implementation, or a *proxy* that
typically corresponds with a *dispatcher* on the provider side via a
remote application protocol.

Currently, the following generation targets are supported:
* In general, C++, JVM/Java and CLR/.NET are supported as target
  technologies.
* API generators exist for each of the target technologies (the C++
  generator makes use of the proprietary BTC.CAB.Commons framework).
* Proxy/dispatcher generators exist for the BTC.CAB.ServiceComm service
  communication APIs in each of the target technologies. The
  BTC.CAB.ServiceComm APIs are proprietary as of November 2018, but
  might be made available as Open Source in the future.
* The remote protocol is generated as Google Protocol Buffers messages.

Additional generators for the existing or additional target technologies
could be added. Currently, there is no extension mechanism that allows
an external addition, i.e. without modifying the existing code, but this
could be easily added using the Equinox/Eclipse Extension Point
facilities.

Relevant architectural guidelines
=================================

There are several architectural guidelines that are relevant in the
context of the Service IDL.

Architectural guidelines directly driving the design of the Service IDL:
* An API must be either service-oriented or object-oriented, but not a
  mixture of both.

Architectural guidelines relevant for the design of the generators:
* A service-oriented API should be implemented by an adapter to a
  corresponding object-oriented API
* A service implementation must not be bound to a specific hosting
  environment
* A service implementation must not depend on a specific communication
  protocol
* A service consumer must not depend on a specific communication
  protocol

Architectural guidelines relevant for suitable target technologies:
* Asynchronous communication should be preferred over synchronous
communication

Architectural guidelines that should be considered when designing APIs
using the Service IDL:
* Fine-granular operations must be avoided in service-oriented APIs
* Mutating operations should be idempotent
* Managing consumer-dependent state should be avoided

Basic Service IDL syntax
========================

One example of a very simple IDL looks like this:
```
module foo {
    main module bar {

        interface Test[guid=384E277A-C343-4F37-B910-C2CE6B37FC8E] {
            DoSomething() returns void;
        };
    }
}
```

The basic syntactical elements of the Service IDL are _modules_,
_interfaces_ and _operations_.
In addition, _data types_ and _exceptions_ can be declared.

Modules
-------

Modules are used for structuring the name space (corresponding to
namespaces or packages in implementation technologies). Modules can be
nested hierarchically. One module should be designated as the main
module. If no module is explicitly marked as the main module, there are
some rules to infer an implicit main module, but this behaviour might be
deprecated in the future and eventually removed.

The main module may have submodules, which contain definitions, but
there may not be any definitions outside the main module.

The name of the main module should match the name of the IDL file. In
the example above, the main module is named `foo.bar`, therefore the IDL
file should be called `foo.bar.idl`.

A module may contain nested _modules_, _interfaces_, _data types_
and _exceptions_.


Interfaces
----------

Interfaces can be declared within a module. Interface are declared using
the `interface` keyword.

An interface has a name (`Test` in the example above) and must specify a
`guid`. An empty interface definition looks like this:
```
interface Test[guid=384E277A-C343-4F37-B910-C2CE6B37FC8E] {};
```
As an advanced feature, interface can extend other interfaces, but this
feature is currently discouraged.

An interface may contain _operations_, _data types_ and
_exceptions_.

When generating code, for each IDL interface the following elements are
generated:
* a programmatic interface in the target technology in the API module
* a proxy that implements the programmatic interface
* a dispatcher that uses an implementation of the programmatic interface

The guid is used to identify the service type in remote uses, while the
name is used only informationally.

Operations
----------

Operations can be declared within an interface as follows:
```
    DoSomething(in sequence<string> inputSequence) returns void;
    query GetSomething() returns sequence<failable uuid>;
```

Operations can be _commands_ (mutating operations) or _queries_
(non-mutating operations), the latter of which are denoted by the
`query` keyword.

An operation can _asynchronous_ (the default) or _synchronous_ or
(denoted by the `sync` keyword). The return type of an asynchronous
method is a _future_ of the given value type, while the return type of a
synchronous method is the plain value type. You should prefer not the
specify methods as synchronous. Future versions of the IDL generator
might choose to configure this on a different level.

Every operation has
* a name (`DoSomething` and `QuerySomething` in the example above),
* an arbitrary number of parameters
* a return type
* optionally, a `raises` declaration specifying exception types that
  may be thrown by implementations of the method

Parameters have
* a direction (in or out)
* a type
* a name

When generating code, for each IDL operation, the following elements are
generated:
* a method in the generated programmatic interface
* a protocol message type encoding the parameters
* a protocol message type encoding the result type
* corresponding handlers in the proxy and dispatcher


Data types
----------

Currently, the following basic builtin data types are supported:
* byte
* int16
* int32
* int64
* char
* string
* float
* double
* boolean
* uuid

The following constructs exist to define more advanced types for use as
operation parameter and return types:
* sequence: A sequence represents a finite number of elements of the
specified value type. As an advanced use, the sequence value type can be
marked as `failable`, the details of which are beyond the scope of this
introduction. An example of a sequence type is `sequence<int16>`.
* structures: see section below
* type aliases: these are not currently covered by this introduction
* enums: these are not currently covered by this introduction

The value type of sequences can be any other type, including basic
builtin types, user-defined data structures, and other sequence types.


Data types: structures
----------------------

Data structures can be declared within a module or an interface. Data
structures are declared using the `struct` keyword.

Data structures can be declared as follows:
```
struct KeyValuePair {
    string key;
    string value;
};
```

The declaration specified the name of the data structure, and contains a
declaration of any number of _attributes_. Each attribute has a _data
type_ (see below) and an _attribute name_. In addition, an attribute may
be marked as `optional`.

When generating code, for each IDL data structure, the following
elements are generated:
* a programmatic data structure in the API (if defined within an
interface) or Common (if defined outside an interface) module
* a protocol message type
* corresponding conversion routines that are used by handlers in the
proxy and dispatcher if the type is referenced in an operation signature


Exceptions
----------

Exceptions can be declared within a module or an interface. Exceptions
are declared using the `exception` keyword.

Exceptions can be declared as follows:
```
exception FooException {};
exception BarException : FooException {};
```

The first exception (`FooException`) does not declare a supertype, which
leaves it to the generator to use an implementation-defined supertype.
The second exception (`BarException`) derives from `FooException`, i.e.
when catching FooException, instances of BarException will also be
caught.

Note that there are curly braces within the exception declaration. The
IDL syntax already supports the declaration of custom attributes, but
this is not currently supported properly by the generators (as of
version 1.0.0). You will yield invalid code if an exception declares
custom attributes.


Workflows
=========

After you have written an IDL file, you can apply the code generator
to it. To get an idea what is happening, we first describe a basic
command line workflow you can run locally. However, usually you want to
consume binary packages, which would be hard to achieve reproducibly
from a local machine, so a continuous delivery workflow is described
afterwards.


Basic local command line workflow
---------------------------------

Releases are available via
[GitHub](https://github.com/btc-ag/service-idl/releases) or via
[Artifactory](https://oss.jfrog.org/artifactory/oss-release-local/com/btc/serviceidl/com.btc.serviceidl.plainjava/).

When you downloaded it, you need to specify an IDL input file and output
directories, which must already exist. You can either specify a common
output directory for all target technologies:
```
java -jar com.btc.serviceidl.plainjava-1.0.0.jar input.idl -outputPath out -cppProjectSystem cmake
```
Alternatively, you can specify specific output directories for each
target technology, in which case only the generators for target
technologies with a specified output directory will be used. For
example, the following command will only generate .NET artifacts:
```
java -jar com.btc.serviceidl.plainjava-1.0.0.jar input.idl -dotnetOutputPath outDotNet
```

Currently, the generator generates all artifacts (API, Proxy,
Dispatcher, ...) for all target technologies (C++, C#/.NET, Java) by
default.


Continous delivery workflow
---------------------------

On the [BTC internal CAB Jenkins](https://ci.psi.de) that provides
continuous integration & delivery services, a dedicated support has been
implemented to simplify building and publishing artifacts from an IDL
file as much as possible. Please refer to the documentation of
ci.psi.de for general information on using the Jenkins, and on how
the release process works.

An example can be found under
https://bitbucket.btc.psi.de/projects/BTCCABCOM/repos/serviceidl-demo/browse

To set this up for your IDL file, first create a Bitbucket repository,
and add the IDL file. In addition, you need to add a Jenkinsfile that
controls what is built:
```
@Library("cab") _

cab {
    def idl_file = 'foo.bar.idl'

    def config = cpp_idl_build(idl: idl_file, compiler: ["vc15"])
    cpp_publish(config: config)

    net_idl_build(idl: idl_file)
    nuget_publish(usePaket: true)

    java_idl_build(idl: idl_file)
    // java_idl_build already publishes artifacts
}
```

This example contains section for C++, .NET and Java, which use the IDL
generator to generate code in each of the technologies, build the
generated code, and publish technology-specific packages. The
Jenkinsfile may contain any subset of these sections, if you only need
packages for some of these technologies.

Optionally, you can also add a `.generator` file that contains
non-default settings for the IDL generators, e.g. version overrides for
the target technologies.

