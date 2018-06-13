Are there comparable technologies to the Service IDL? What are the differences?
==============================================================================

TODO

* Google Protobuf Buffers IDL
* Apache Thrift
* OMG IDL

What is a Service API? What is an OO API?
=========================================

The Service IDL was developed based on the idea that there are Service APIs and OO APIs are distinct concepts, and that
there should be no hybrids between these two concepts. Based on that, the Service IDL focuses on Service APIs.

The details of this distinction are beyond the scope of this FAQ, but some essential aspects include that
* a Service API's parameters and return types are non-opaque DTOs and may contain only externalized references to objects via IDs, URIs etc.
* an OO API's parameters are opaque and are interface types themselves, which offer methods that return object references
* a good Service API has coarse-grained operations only
* the user of a Service API must be prepared for latency and operational failures

I would like to also generate an OO API/data model that corresponds with my Service API/data model. How do I do that?
=====================================================================================================================

This is out of scope of the Service IDL. The kind of information that is currently modeled in the Service IDL is not 
sufficient to enable such a generation, and extending the Service IDL to support this would blur its scope and the 
necessary extensions would probably be much more complex than the existing modeling constructs.

To generate corresponding Service and OO data models at least for specific cases, a distinct data modeling DSL might be 
used, which can then also generate some mapper between the data models.

This will not cover generation of Service and OO APIs itself (in the sense of the "interface" keyword in the service IDL). 
Such a generation is probably not implementable in general from a common source model.

I would like to generate an OO API, Service API and bidirectional mappers betweens these APIs. How do I do that?
================================================================================================================

In addition to the answer to the previous question, this is probably not what you want. This is something like Java RMI 
implicitly does at runtime, and unconstrained use of such a technology leads to a wealth of problems. The non-functional 
properties of using an OO API, which is implemented via a Service API, are not foreseeable for its user, including latency 
and operational failures.

I already have defined some data types in my target technology, which I would like to use in my Service IDL specification. How do I do that?
============================================================================================================================================

You don't. It is an explicit design decision not to support this. Bear in mind that you would need to model a mapping for the type
for all target technologies, and specify a serialization format for it. This would make the IDL language and generators much more complex. 
In addition, programming languages offer much more options to model data types than the Service IDL does, so supporting arbitrary types would 
be much more complex than you might think. If these types are part of an existing non-generated Service API, these can probably be replaced by
generated types. If these types are part of something else, you might be mixing OO and Service layers, and the Service IDL is designed
based on the assumption that these should not mixed.

