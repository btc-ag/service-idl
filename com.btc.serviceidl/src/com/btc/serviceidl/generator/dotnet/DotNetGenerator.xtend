/*********************************************************************
* \author see AUTHORS file
* \copyright 2015-2018 BTC Business Technology Consulting AG and others
*
* This program and the accompanying materials are made
* available under the terms of the Eclipse Public License 2.0
* which is available at https://www.eclipse.org/legal/epl-2.0/
*
* SPDX-License-Identifier: EPL-2.0
**********************************************************************/
/**
 * \file       DotNetGenerator.xtend
 * 
 * \brief      Xtend generator for C# .NET artifacts from an IDL
 */

package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.FeatureProfile
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import com.google.common.collect.Sets
import java.util.ArrayList
import java.util.Arrays
import java.util.Calendar
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.Optional
import java.util.Set
import java.util.UUID
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.util.Pair
import org.eclipse.xtext.util.Tuples

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

class DotNetGenerator
{
   // constants
   val DOTNET_FRAMEWORK_VERSION = DotNetFrameworkVersion.NET40
   
   // global variables
   private var Resource resource
   private var IFileSystemAccess file_system_access
   private var IQualifiedNameProvider qualified_name_provider
   private var IScopeProvider scope_provider
   private var IDLSpecification idl
   
   private var param_bundle = new ParameterBundle.Builder()
   
   private val typedef_table = new HashMap<String, String>
   private val namespace_references = new HashSet<String>
   private val referenced_assemblies = new HashSet<String>
   private var nuget_packages = new NuGetPackageResolver
   private val project_references = new HashMap<String, String>
   private val vsSolution = new VSSolution
   private val cs_files = new HashSet<String>
   private val protobuf_files = new HashSet<String>
   private var protobuf_project_references = new HashMap<String, HashMap<String, String>>
   private var extension TypeResolver typeResolver
   private var extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
   
   def public void doGenerate(Resource res, IFileSystemAccess fsa, IQualifiedNameProvider qnp, IScopeProvider sp, Set<ProjectType> projectTypes, HashMap<String, HashMap<String, String>> pr)
   {
      resource = res
      file_system_access = fsa
      qualified_name_provider = qnp
      scope_provider = sp
      protobuf_project_references = pr
      param_bundle.reset(ArtifactNature.DOTNET)
      
      idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
            
      // iterate module by module and generate included content
      for (module : idl.modules)
      {
         processModule(module, projectTypes)
      }
   }
   
   def private void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {
      param_bundle = ParameterBundle.createBuilder(com.btc.serviceidl.util.Util.getModuleStack(module))
      param_bundle.reset(ArtifactNature.DOTNET)
      
      if (!module.virtual)
      {
         // generate common data types and exceptions, if available
         if ( module.containsTypes )
            if (projectTypes.contains(ProjectType.COMMON)) generateCommon(module)

         // generate Protobuf project, if necessary
         if ( module.containsTypes || module.containsInterfaces )
            if (projectTypes.contains(ProjectType.PROTOBUF)) generateProtobuf(module)

         // generate proxy/dispatcher projects for all contained interfaces
         if (module.containsInterfaces)
         {
            generateInterfaceProjects(module, projectTypes)
            if (projectTypes.contains(ProjectType.SERVER_RUNNER)) generateServerRunner(module)
            if (projectTypes.contains(ProjectType.CLIENT_CONSOLE)) generateClientConsole(module)
         }
      }
      
      // process nested modules
      for (nested_module : module.nestedModules)
         processModule(nested_module, projectTypes)
   }
   
   def private void generateInterfaceProjects(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        Sets.intersection(projectTypes, new HashSet<ProjectType>(Arrays.asList(
            ProjectType.SERVICE_API,
            ProjectType.IMPL,
            ProjectType.PROXY,
            ProjectType.DISPATCHER,
            ProjectType.TEST
        ))).forEach[generateProjectStructure(it, module)]
   }
   
   def private void generateProjectStructure(ProjectType project_type, ModuleDeclaration module)
   {
      reinitializeProject(project_type)
      val project_root_path = getProjectRootPath()
      
      for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         param_bundle.reset(com.btc.serviceidl.util.Util.getModuleStack(interface_declaration))
         generateProject(project_type, interface_declaration, project_root_path)
      }
      
      generateVSProjectFiles(project_root_path)
   }
   
   def private void generateProject(ProjectType project_type, InterfaceDeclaration interface_declaration, String project_root_path)
   {
      switch (project_type)
      {
      case SERVICE_API:
      {
         generateServiceAPI(project_root_path, interface_declaration)
      }
      case DISPATCHER:
      {
         addGoogleProtocolBuffersReferences()
         generateDispatcher(project_root_path, interface_declaration)
      }
      case IMPL:
      {
         generateImpl(project_root_path, interface_declaration)
      }
      case PROXY:
      {
         addGoogleProtocolBuffersReferences()
         generateProxy(project_root_path, interface_declaration)
      }
      case TEST:
      {
         generateTest(project_root_path, interface_declaration)
      }
      default:
         throw new IllegalArgumentException("Project type currently not supported: " + param_bundle.projectType)
      }
   }
   
   def private void generateCommon(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.COMMON)
      
      val project_root_path = getProjectRootPath()
      
      var file_content = 
      '''
         «FOR element : module.moduleComponents»
            «IF !(element instanceof InterfaceDeclaration)»
               «toText(element, module)»

            «ENDIF»
         «ENDFOR»
      '''

      val common_file_name = Constants.FILE_NAME_TYPES
      cs_files.add(common_file_name)
      
      file_system_access.generateFile(project_root_path + common_file_name.cs, generateSourceFile(file_content))
      
      generateVSProjectFiles(project_root_path)
   }
   
   def private void generateVSProjectFiles(String project_root_path)
   {
      val project_name = vsSolution.getCsprojName(param_bundle)
      
      // generate project file
      file_system_access.generateFile(project_root_path + Constants.SEPARATOR_FILE + project_name.csproj, generateCsproj(cs_files))
      
      // generate mandatory AssemblyInfo.cs file
      file_system_access.generateFile(project_root_path + Constants.SEPARATOR_FILE + "Properties" + Constants.SEPARATOR_FILE + "AssemblyInfo.cs", generateAssemblyInfo(project_name))
   
      // NuGet (optional)
      if (!nuget_packages.resolvedPackages.empty)
         file_system_access.generateFile(project_root_path + Constants.SEPARATOR_FILE + "packages.config", generatePackagesConfig)
   }
   
   def private String generatePackagesConfig()
   {
      val packages = new HashMap<String, String>
      for (nuget_package : nuget_packages.resolvedPackages)
         packages.put(nuget_package.packageID, nuget_package.packageVersion)

      '''
      <?xml version="1.0" encoding="utf-8"?>
      <packages>
        «FOR package_id : packages.keySet»
          <package id="«package_id»" version="«packages.get(package_id)»" targetFramework="«DOTNET_FRAMEWORK_VERSION.toString.toLowerCase»" />
        «ENDFOR»
      </packages>
      '''
   }
   
   def private String generateAssemblyInfo(String project_name)
   {
      val is_exe = isExecutable(param_bundle.projectType)
      
      '''
      using System.Reflection;
      using System.Runtime.CompilerServices;
      using System.Runtime.InteropServices;
      
      // General Information about an assembly is controlled through the following 
      // set of attributes. Change these attribute values to modify the information
      // associated with an assembly.
      [assembly: AssemblyTitle("«project_name»")]
      [assembly: AssemblyDescription("")]
      [assembly: AssemblyConfiguration("")]
      [assembly: AssemblyProduct("«project_name»")]
      «IF !is_exe»
      [assembly: AssemblyCompany("BTC Business Technology Consulting AG")]
      [assembly: AssemblyCopyright("Copyright (C) BTC Business Technology Consulting AG «Calendar.getInstance().get(Calendar.YEAR)»")]
      [assembly: AssemblyTrademark("")]
      [assembly: AssemblyCulture("")]
      «ENDIF»
      
      // Setting ComVisible to false makes the types in this assembly not visible 
      // to COM components.  If you need to access a type in this assembly from 
      // COM, set the ComVisible attribute to true on that type.
      [assembly: ComVisible(false)]
      
      // The following GUID is for the ID of the typelib if this project is exposed to COM
      [assembly: Guid("«UUID.nameUUIDFromBytes((project_name+"Assembly").bytes).toString.toLowerCase»")]
      '''
   }
   
   def private void reinitializeFile()
   {
      namespace_references.clear
   }
   
   def private void reinitializeProject(ProjectType project_type)
   {
      reinitializeFile
      param_bundle.reset(project_type)
      referenced_assemblies.clear
      project_references.clear
      protobuf_files.clear
      nuget_packages = new NuGetPackageResolver
      cs_files.clear
      
      typeResolver = new TypeResolver(DOTNET_FRAMEWORK_VERSION, qualified_name_provider, 
          namespace_references, referenced_assemblies, project_references, vsSolution, param_bundle
      )
      basicCSharpSourceGenerator = new BasicCSharpSourceGenerator(typeResolver, typedef_table, idl)      
   }
   
   def private void generateImpl(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val impl_class_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
      val api_fully_qualified_name = resolve(interface_declaration)
      
      val anonymous_event = com.btc.serviceidl.util.Util.getAnonymousEvent(interface_declaration)
      
      cs_files.add(impl_class_name)
      file_system_access.generateFile(
         src_root_path + impl_class_name.cs,
         generateSourceFile(
         '''
         public class «impl_class_name» : «IF anonymous_event !== null»«resolve("BTC.CAB.ServiceComm.NET.Base.ABasicObservable")»<«resolve(anonymous_event.data)»>, «ENDIF»«api_fully_qualified_name.shortName»
         {
            «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
               /// <see cref="«api_fully_qualified_name».«function.name»"/>
               public «makeReturnType(function)» «function.name»(
                  «FOR param : function.parameters SEPARATOR ","»
                     «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function).asParameter»
                  «ENDFOR»
               )
               {
                  «makeImplementatonStub(function)»
               }
            «ENDFOR»
            
            «FOR event : interface_declaration.events.filter[name !== null]»
               «val event_name = toText(event, interface_declaration)»
               /// <see cref="«api_fully_qualified_name».Get«event_name»"/>
               public «event_name» Get«event_name»()
               {
                  «makeDefaultMethodStub»
               }
            «ENDFOR»
         }
         '''
         )
      )
      
   }
   
   def private void generateDispatcher(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val dispatcher_class_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
      val api_class_name = resolve(interface_declaration).shortName
      
      cs_files.add(dispatcher_class_name)
      
      val events = interface_declaration.events
      
      val protobuf_request = getProtobufRequestClassName(interface_declaration)
      val protobuf_response = getProtobufResponseClassName(interface_declaration)
      val service_fault_handler = "serviceFaultHandler"
      
      // special case: the ServiceComm type InvalidRequestReceivedException has
      // the namespace BTC.CAB.ServiceComm.NET.API.Exceptions, but is included
      // in the assembly BTC.CAB.ServiceComm.NET.API; if we use the resolve()
      // method, a non-existing assembly is referenced, so we do it manually
      namespace_references.add("BTC.CAB.ServiceComm.NET.API.Exceptions")
      
      file_system_access.generateFile(
         src_root_path + dispatcher_class_name.cs,
         generateSourceFile(
         '''
         public class «dispatcher_class_name» : «resolve("BTC.CAB.ServiceComm.NET.Base.AServiceDispatcherBase")»
         {
            private readonly «api_class_name» _dispatchee;
            
            private readonly «resolve("BTC.CAB.ServiceComm.NET.ProtobufUtil.ProtoBufServerHelper")» _protoBufHelper;
            
            private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IServiceFaultHandlerManager")» _faultHandlerManager;
            
            «FOR event : events»
            private «resolve("System.Collections.Generic.List")»<«resolve("BTC.CAB.ServiceComm.NET.API.IEventPublisherRegistration")»> _remote«event.data.name»Publishers;
            private «resolve("System.Collections.Generic.List")»<«resolve("System.IDisposable")»> _local«event.data.name»Subscriptions;
            «ENDFOR»
            
            public «dispatcher_class_name»(«api_class_name» dispatchee, ProtoBufServerHelper protoBufHelper)
            {
               _dispatchee = dispatchee;
               _protoBufHelper = protoBufHelper;

               «FOR event : events»
               _remote«event.data.name»Publishers = new List<IEventPublisherRegistration>();
               _local«event.data.name»Subscriptions = new List<IDisposable>();
               «ENDFOR»

               _faultHandlerManager = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.ServiceFaultHandlerManager")»();

               var «service_fault_handler» = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.ProtobufServiceFaultHandler")»();

               «makeExceptionRegistration(service_fault_handler, com.btc.serviceidl.util.Util.getRaisedExceptions(interface_declaration))»

               _faultHandlerManager.RegisterHandler(«service_fault_handler»);
            }
            
            «FOR event : events»
               «val event_type = event.data»
               «val protobuf_class_name = resolve(event_type, ProjectType.PROTOBUF)»
               private «protobuf_class_name» Marshal«event_type.name»(«resolve(event_type)» arg)
               {
                  return («protobuf_class_name») «resolveCodec(event_type)».encode(arg);
               }
            «ENDFOR»
            
            /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.ProcessRequest"/>
            public override «resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")» ProcessRequest(IMessageBuffer requestBuffer, «resolve("BTC.CAB.ServiceComm.NET.Common.IPeerIdentity")» peerIdentity)
            {
               var request = «protobuf_request».ParseFrom(requestBuffer.PopFront());
               
               «FOR func : interface_declaration.functions»
               «val request_name = func.name.toLowerCase.toFirstUpper + Constants.PROTOBUF_REQUEST»
               «val is_void = func.returnedType.isVoid»
               «IF func != interface_declaration.functions.head»else «ENDIF»if (request.Has«request_name»)
               {
                  «val out_params = func.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                  «IF !out_params.empty»
                     // prepare [out] parameters
                     «FOR param : out_params»
                        var «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
                     «ENDFOR»
                     
                  «ENDIF»
                  // call actual method
                  «IF !is_void»var result = «ENDIF»_dispatchee.«func.name»
                     (
                        «FOR param : func.parameters SEPARATOR ","»
                           «val is_input = (param.direction == ParameterDirection.PARAM_IN)»
                           «val use_codec = GeneratorUtil.useCodec(param, param_bundle.artifactNature)»
                           «val decodeMethod = getDecodeMethod(param.paramType)»
                           «IF is_input»
                              «IF use_codec»(«resolveDecode(param.paramType)») «resolveCodec(param.paramType)».«decodeMethod»(«ENDIF»«IF use_codec»«resolve(param.paramType, ProjectType.PROTOBUF).alias("request")»«ELSE»request«ENDIF».«request_name».«param.paramName.toLowerCase.toFirstUpper»«IF (com.btc.serviceidl.util.Util.isSequenceType(param.paramType))»List«ENDIF»«IF use_codec»)«ENDIF»
                           «ELSE»
                              out «param.paramName.asParameter»
                           «ENDIF»
                        «ENDFOR»
                     )«IF !func.sync».«IF is_void»Wait()«ELSE»Result«ENDIF»«ENDIF»;«IF !func.sync» // «IF is_void»await«ELSE»retrieve«ENDIF» the result in order to trigger exceptions«ENDIF»

                  // deliver response
                  var responseBuilder = «protobuf_response».Types.«com.btc.serviceidl.util.Util.asResponse(func.name)».CreateBuilder()
                     «val use_codec = GeneratorUtil.useCodec(func.returnedType, param_bundle.artifactNature)»
                     «val method_name = if (com.btc.serviceidl.util.Util.isSequenceType(func.returnedType)) "AddRange" + func.name.toLowerCase.toFirstUpper else "Set" + func.name.toLowerCase.toFirstUpper»
                     «val encodeMethod = getEncodeMethod(func.returnedType)»
                     «IF !is_void».«method_name»(«IF use_codec»(«resolveEncode(func.returnedType)») «resolveCodec(func.returnedType)».«encodeMethod»(«ENDIF»«IF use_codec»«resolve(func.returnedType).alias("result")»«ELSE»result«ENDIF»«IF use_codec»)«ENDIF»)«ENDIF»
                     «FOR param : out_params»
                        «val param_name = param.paramName.asParameter»
                        «val use_codec_param = GeneratorUtil.useCodec(param.paramType, param_bundle.artifactNature)»
                        «val method_name_param = if (com.btc.serviceidl.util.Util.isSequenceType(param.paramType)) "AddRange" + param.paramName.toLowerCase.toFirstUpper else "Set" + param.paramName.toLowerCase.toFirstUpper»
                        «val encode_method_param = getEncodeMethod(param.paramType)»
                        .«method_name_param»(«IF use_codec_param»(«resolveEncode(param.paramType)») «resolveCodec(param.paramType)».«encode_method_param»(«ENDIF»«IF use_codec_param»«resolve(param.paramType).alias(param_name)»«ELSE»«param_name»«ENDIF»«IF use_codec_param»)«ENDIF»)
                     «ENDFOR»
                     ;
                  
                  var response = «protobuf_response».CreateBuilder().Set«func.name.toLowerCase.toFirstUpper»Response(responseBuilder).Build();
                  return new «resolve("BTC.CAB.ServiceComm.NET.Common.MessageBuffer")»(response.ToByteArray());
               }
               «ENDFOR»

               throw new InvalidRequestReceivedException("Unknown or invalid request");
            }
            
            /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.ServiceFaultHandlerManager"/>
            public override IServiceFaultHandlerManager ServiceFaultHandlerManager
            {
               get { return _faultHandlerManager; }
            }
            
            /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.AttachEndpoint"/>
            public override void AttachEndpoint(IServerEndpoint endpoint)
            {
               base.AttachEndpoint(endpoint);
               
               «FOR event : events»
                  «val event_type = event.data»
                  «val event_api_class_name = resolve(event_type)»
                  // registration for «event_type.name»
                  endpoint.EventRegistry.CreateEventRegistration(«event_api_class_name».«eventTypeGuidProperty»,
                     «resolve("BTC.CAB.ServiceComm.NET.API.EventKind")».EventKindPublishSubscribe, «event_api_class_name».«eventTypeGuidProperty».ToString());
                  var remote«event_type.name»Publisher = endpoint.EventRegistry.PublisherManager.RegisterPublisher(
                              «event_api_class_name».«eventTypeGuidProperty»);
                  _remote«event_type.name»Publishers.Add(remote«event_type.name»Publisher);
                  var local«event_type.name»Subscription = _dispatchee«IF event.name !== null».Get«getObservableName(event)»()«ENDIF».Subscribe(
                  new «event_type.name»Observer(remote«event_type.name»Publisher));
                  _local«event_type.name»Subscriptions.Add(local«event_type.name»Subscription);
               «ENDFOR»
            }
            
            «FOR event : events»
            «val event_type = event.data»
            «val event_api_class_name = resolve(event_type)»
            «val event_protobuf_class_name = resolve(event_type, ProjectType.PROTOBUF)»
            class «event_type.name»Observer : IObserver<«event_api_class_name»>
            {
                private readonly IObserver<IMessageBuffer> _messageBufferObserver;

                public «event_type.name»Observer(IObserver<IMessageBuffer> messageBufferObserver)
                {
                    _messageBufferObserver = messageBufferObserver;
                }

                public void OnNext(«event_api_class_name» value)
                {
                    «event_protobuf_class_name» protobufEvent = «resolveCodec(event.data)».encode(value) as «event_protobuf_class_name»;
                    byte[] serializedEvent = protobufEvent.ToByteArray();
                    _messageBufferObserver.OnNext(new MessageBuffer(serializedEvent));
                }

                public void OnError(Exception error)
                {
                    throw new NotSupportedException();
                }

                public void OnCompleted()
                {
                    throw new NotSupportedException();
                }
            }
            «ENDFOR»
            
            /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.DetachEndpoint"/>
            public override void DetachEndpoint(IServerEndpoint endpoint)
            {
               base.DetachEndpoint(endpoint);
               
               «FOR event : events»
               «val event_type = event.data»
               foreach (var eventSubscription in _local«event_type.name»Subscriptions)
               {
                  eventSubscription.Dispose();
               }
               
               foreach (var eventPublisher in _remote«event_type.name»Publishers)
               {
                  eventPublisher.Dispose();
               }
               «ENDFOR»
            }
         }
         '''
         )
      )
   }
   
   def private void generateProtobuf(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.PROTOBUF)
      
      val project_root_path = getProjectRootPath()
      addGoogleProtocolBuffersReferences()
      
      if (module.containsTypes)
      {
         generateProtobufProjectContent(module, project_root_path)
      }
      for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         generateProtobufProjectContent(interface_declaration, project_root_path)
      }
      
      generateVSProjectFiles(project_root_path)
   }
   
   def private void generateProtobufProjectContent(EObject owner, String project_root_path)
   {
      val codec_name = GeneratorUtil.getCodecName(owner)
      cs_files.add(codec_name)
      file_system_access.generateFile(project_root_path + codec_name.cs,
         generateSourceFile(generateProtobufCodec(owner, codec_name)))
      if (owner instanceof ModuleDeclaration)
      {
         protobuf_files.add(Constants.FILE_NAME_TYPES)
      }
      else if (owner instanceof InterfaceDeclaration)
      {
         protobuf_files.add(owner.name)
      }
      
      // resolve dependencies across interfaces
      for (element : owner.eAllContents.toIterable)
      {
         resolveProtobufDependencies(element, owner)
      }
   }
   
   def private dispatch void resolveProtobufDependencies(EObject element, EObject owner)
   { /* no-operation dispatch method to match all non-handled cases */ }
   
   def private dispatch void resolveProtobufDependencies(StructDeclaration element, EObject owner)
   {
      resolve(element, ProjectType.PROTOBUF)
      
      for (member : element.members)
      {
         resolveProtobufDependencies(member, owner)
      }
   }
   
   def private dispatch void resolveProtobufDependencies(EnumDeclaration element, EObject owner)
   {
      resolve(element, ProjectType.PROTOBUF)
   }
   
   def private dispatch void resolveProtobufDependencies(ExceptionDeclaration element, EObject owner)
   {
      resolve(element, ProjectType.PROTOBUF)
      
      if (element.supertype !== null)
         resolveProtobufDependencies(element.supertype, owner)
   }
   
   def private dispatch void resolveProtobufDependencies(FunctionDeclaration element, EObject owner)
   {
      for (param : element.parameters)
      {
         resolveProtobufDependencies(param.paramType, owner)
      }
      
      if (!element.returnedType.isVoid)
         resolveProtobufDependencies(element.returnedType, owner)
   }
   
   def private dispatch void resolveProtobufDependencies(AbstractType element, EObject owner)
   {
      if (element.referenceType !== null)
         resolveProtobufDependencies(element.referenceType, owner)
   }
   
   def private String generateProtobufCodec(EObject owner, String class_name)
   {
      reinitializeFile
      resolve("System.Collections.Generic.IEnumerable")
      resolve("System.Linq.Enumerable")
      
      // collect all data types which are relevant for encoding
      val data_types = GeneratorUtil.getEncodableTypes(owner)
      
      '''
   public static class «class_name»
   {
      public static IEnumerable<TOut> encodeEnumerable<TOut, TIn>(IEnumerable<TIn> plainData)
      {
         return plainData.Select(item => (TOut) encode(item)).ToList();
      }

      public static int encodeByte(byte plainData)
      {
         return plainData;
      }

      public static int encodeShort(short plainData)
      {
         return plainData;
      }
      
      public static int encodeChar(char plainData)
      {
         return plainData;
      }

      public static «resolve("Google.ProtocolBuffers.ByteString")» encodeUUID(«resolve("System.Guid")» plainData)
      {
         return Google.ProtocolBuffers.ByteString.CopyFrom(plainData.ToByteArray());
      }

      // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
      public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<byte> plainData)
      {
         return plainData.Select(item => (int)item).ToList();
      }

      // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
      public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<short> plainData)
      {
          return plainData.Select(item => (int)item).ToList();
      }
      
      // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
      public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<char> plainData)
      {
          return plainData.Select(item => (int)item).ToList();
      }
      
      // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
      public static IEnumerable<«resolve("Google.ProtocolBuffers.ByteString")»> encodeEnumerable<TOut, TIn>(IEnumerable<«resolve("System.Guid")»> plainData)
      {
          return plainData.Select(item => encodeUUID(item)).ToList();
      }
      
      public static «resolve("System.object")» encode(object plainData)
      {
         if (plainData === null)
            throw new «resolve("System.ArgumentNullException")»();

         «FOR data_type : data_types»
         if (plainData.GetType() == typeof(«resolve(data_type)»))
         {
            «makeEncode(data_type, owner)»
         }
         «ENDFOR»
         
         return plainData;
      }
      
      public static IEnumerable<TOut> decodeEnumerable<TOut, TIn>(IEnumerable<TIn> encodedData)
      {
         return encodedData.Select(item => (TOut) decode(item)).ToList();
      }
      
      public static IEnumerable<byte> decodeEnumerableByte(IEnumerable<int> encodedData)
      {
         return encodedData.Select(item => (byte) item).ToList();
      }
      
      public static IEnumerable<short> decodeEnumerableShort (IEnumerable<int> encodedData)
      {
         return encodedData.Select(item => (short)item).ToList();
      }
      
      public static IEnumerable<char> decodeEnumerableChar (IEnumerable<int> encodedData)
      {
         return encodedData.Select(item => (char)item).ToList();
      }
      
      public static IEnumerable<«resolve("System.Guid")»> decodeEnumerableUUID (IEnumerable<«resolve("Google.ProtocolBuffers.ByteString")»> encodedData)
      {
         return encodedData.Select(item => decodeUUID(item)).ToList();
      }
      
      public static byte decodeByte(int encodedData)
      {
         return (byte) encodedData;
      }
      
      public static short decodeShort(int encodedData)
      {
         return (short) encodedData;
      }
      
      public static char decodeChar(int encodedData)
      {
         return (char) encodedData;
      }
      
      public static «resolve("System.Guid")» decodeUUID(«resolve("Google.ProtocolBuffers.ByteString")» encodedData)
      {
         return new System.Guid(encodedData.ToByteArray());
      }
      
      public static object decode(object encodedData)
      {
         if (encodedData === null)
            throw new «resolve("System.ArgumentNullException")»();

         «FOR data_type : data_types»
         if (encodedData.GetType() == typeof(«resolve(data_type, ProjectType.PROTOBUF)»))
         {
            «makeDecode(data_type, owner)»
         }
         «ENDFOR»

            return encodedData;
         }
      }
      '''
   }

   def private dispatch String makeEncode(EnumDeclaration element, EObject owner)
   {
      val api_type_name = resolve(element)
      val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)
      
      '''
      «api_type_name» typedData = («api_type_name») plainData;
      «FOR item : element.containedIdentifiers»
         «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «api_type_name».«item»)
            return «protobuf_type_name».«item»;
      «ENDFOR»
      else
         throw new «resolve("System.ArgumentOutOfRangeException")»("Unknown value " + typedData.ToString() + " for enumeration «element.name»");
      '''
   }
   
   def private dispatch String makeEncode(StructDeclaration element, EObject owner)
   {
      makeEncodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
   }
   
   def private dispatch String makeEncode(ExceptionDeclaration element, EObject owner)
   {
      makeEncodeStructOrException(element, element.allMembers, Optional.empty)
   }
   
   def private String makeEncodeStructOrException(EObject element, Iterable<MemberElementWrapper> members, Optional<Collection<AbstractTypeDeclaration>> type_declarations)
   {
      val api_type_name = resolve(element)
      val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)
      
      '''
      «api_type_name» typedData = («api_type_name») plainData;
      var builder = «protobuf_type_name».CreateBuilder();
      «FOR member : members»
         «val codec = resolveCodec(member.type)»
         «val useCodec = GeneratorUtil.useCodec(member.type, param_bundle.artifactNature)»
         «val encodeMethod = getEncodeMethod(member.type)»
         «val method_name = if (com.btc.serviceidl.util.Util.isSequenceType(member.type)) "AddRange" + member.name.toLowerCase.toFirstUpper else "Set" + member.name.toLowerCase.toFirstUpper»
         «IF com.btc.serviceidl.util.Util.isAbstractCrossReferenceType(member.type) && !(com.btc.serviceidl.util.Util.isEnumType(member.type))»
         if (typedData.«member.name.asProperty» !== null)
         {
             builder.«method_name»(«IF useCodec»(«resolveEncode(member.type)») «codec».«encodeMethod»(«ENDIF»typedData.«member.name.asProperty»«IF useCodec»)«ENDIF»);
         }
         «ELSE»
            «val is_nullable = (member.optional && member.type.valueType)»
            «val is_optional_reference = (member.optional && !member.type.valueType)»
            «IF com.btc.serviceidl.util.Util.isByte(member.type) || com.btc.serviceidl.util.Util.isInt16(member.type) || com.btc.serviceidl.util.Util.isChar(member.type)»
               «IF is_nullable»if (typedData.«member.name.asProperty».HasValue) «ENDIF»builder.«method_name»(typedData.«member.name.asProperty»«IF is_nullable».Value«ENDIF»);
            «ELSE»
               «IF is_nullable»if (typedData.«member.name.asProperty».HasValue) «ENDIF»«IF is_optional_reference»if (typedData.«member.name.asProperty» !== null) «ENDIF»builder.«method_name»(«IF useCodec»(«resolveEncode(member.type)») «codec».«encodeMethod»(«ENDIF»typedData.«member.name.asProperty»«IF is_nullable».Value«ENDIF»«IF useCodec»)«ENDIF»);
            «ENDIF»
         «ENDIF»
      «ENDFOR»
      «IF type_declarations.present»
         «FOR struct_decl : type_declarations.get.filter(StructDeclaration).filter[declarator !== null]»
            «val codec = resolveCodec(struct_decl)»
            «val member_name = struct_decl.declarator»
            builder.Set«member_name.toLowerCase.toFirstUpper»((«protobuf_type_name».Types.«struct_decl.name») «codec».encode(typedData.«member_name.asProperty»));
         «ENDFOR»
         «FOR enum_decl : type_declarations.get.filter(EnumDeclaration).filter[declarator !== null]»
            «val codec = resolveCodec(enum_decl)»
            «val member_name = enum_decl.declarator»
            builder.Set«member_name.toLowerCase.toFirstUpper»((«protobuf_type_name».Types.«enum_decl.name») «codec».encode(typedData.«member_name»));
         «ENDFOR»
      «ENDIF»
      return builder.BuildPartial();
      '''
   }

   def private String getEncodeMethod (EObject type)
   {
      val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(type)
      val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(type)
      if (is_sequence)
         "encodeEnumerable<" + resolveEncode(ultimate_type) + ", " + toText(ultimate_type, null) + ">"
      else if (com.btc.serviceidl.util.Util.isByte(type))
         "encodeByte"
      else if (com.btc.serviceidl.util.Util.isInt16(type))
         "encodeShort"
      else if (com.btc.serviceidl.util.Util.isChar(type))
         "encodeChar"
      else if (com.btc.serviceidl.util.Util.isUUIDType(type))
         "encodeUUID"
      else 
         "encode"
   }

   def private dispatch String makeEncode(AbstractType element, EObject owner)
   {
      if (element.referenceType !== null)
         return makeEncode(element.referenceType, owner)
   }

   def private dispatch String makeDecode(EnumDeclaration element, EObject owner)
   {
      val api_type_name = resolve(element)
      val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)
      
      '''
      «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
      «FOR item : element.containedIdentifiers»
         «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «protobuf_type_name».«item»)
            return «api_type_name».«item»;
      «ENDFOR»
      else
         throw new «resolve("System.ArgumentOutOfRangeException")»("Unknown value " + typedData.ToString() + " for enumeration «element.name»");
      '''
   }

   def private String resolveEncode(EObject element)
   {
      if (com.btc.serviceidl.util.Util.isUUIDType(element))
         return resolve("Google.ProtocolBuffers.ByteString").toString
      
      if (com.btc.serviceidl.util.Util.isByte(element) || com.btc.serviceidl.util.Util.isInt16(element) || com.btc.serviceidl.util.Util.isChar(element))
         return "int"
      
      if (com.btc.serviceidl.util.Util.isSequenceType(element))
         return resolve("System.Collections.Generic.IEnumerable") + '''<«resolveEncode(com.btc.serviceidl.util.Util.getUltimateType(element))»>'''
      
      return resolve(element, ProjectType.PROTOBUF).toString
   }

   def private String resolveDecode(EObject element)
   {
      if (com.btc.serviceidl.util.Util.isUUIDType(element))
         return resolve("System.Guid").fullyQualifiedName
      
      if (com.btc.serviceidl.util.Util.isByte(element))
         return "byte"
      
      if (com.btc.serviceidl.util.Util.isInt16(element))
         return "short"
      
      if (com.btc.serviceidl.util.Util.isInt16(element))
         return "char"
      
      if (com.btc.serviceidl.util.Util.isSequenceType(element))
         return resolve("System.Collections.Generic.IEnumerable") + '''<«resolveDecode(com.btc.serviceidl.util.Util.getUltimateType(element))»>'''
      
      return resolve(element).toString
   }

   def private dispatch String makeDecode(StructDeclaration element, EObject owner)
   {
      makeDecodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
   }

   def private dispatch String makeDecode(ExceptionDeclaration element, EObject owner)
   {
      makeDecodeStructOrException(element, element.allMembers, Optional.empty)
   }

   def private String makeDecodeStructOrException(EObject element, Iterable<MemberElementWrapper> members, Optional<Collection<AbstractTypeDeclaration>> type_declarations)
   {
      val api_type_name = resolve(element)
      val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)
      
      '''
      «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
      return new «api_type_name» (
         «FOR member : members SEPARATOR ","»
            «val codec = resolveCodec(member.type)»
            «val useCodec = GeneratorUtil.useCodec(member.type, param_bundle.artifactNature)»
            «val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(member.type)»
            «val is_optional = member.optional»
            «IF com.btc.serviceidl.util.Util.isByte(member.type) || com.btc.serviceidl.util.Util.isInt16(member.type) || com.btc.serviceidl.util.Util.isChar(member.type)»
            «member.name.asParameter»: «IF is_optional»(typedData.«hasField(member)») ? «ENDIF»(«resolve(member.type)») typedData.«member.name.toLowerCase.toFirstUpper»«IF is_optional» : («toText(member.type, null)»?) null«ENDIF»
            «ELSE»
            «val decode_method = getDecodeMethod(member.type)»
            «member.name.asParameter»: «IF is_optional»(typedData.«hasField(member)») ? «ENDIF»«IF useCodec»(«resolveDecode(member.type)») «codec».«decode_method»(«ENDIF»typedData.«member.name.toLowerCase.toFirstUpper»«IF is_sequence»List«ENDIF»«IF useCodec»)«ENDIF»«IF is_optional» : «IF member.type.isNullable»(«toText(member.type, null)»?) «ENDIF»null«ENDIF»
            «ENDIF»
         «ENDFOR»
         «IF type_declarations.present»
            «FOR struct_decl : type_declarations.get.filter(StructDeclaration).filter[declarator !== null] SEPARATOR ","»
               «val codec = resolveCodec(struct_decl)»
               «val member_name = struct_decl.declarator»
               «member_name.asParameter»: («resolve(struct_decl)») «codec».decode(typedData.«member_name.toLowerCase.toFirstUpper»)
            «ENDFOR»
            «FOR enum_decl : type_declarations.get.filter(EnumDeclaration).filter[declarator !== null] SEPARATOR ","»
               «val codec = resolveCodec(enum_decl)»
               «val member_name = enum_decl.declarator»
               «member_name.asParameter»: («api_type_name + Constants.SEPARATOR_PACKAGE + enum_decl.name») «codec».decode(typedData.«member_name.toLowerCase.toFirstUpper»)
            «ENDFOR»
         «ENDIF»
         );
      '''
   }

   def private String getDecodeMethod (EObject type)
   {
      val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(type)
      if (is_sequence)
      {
         val ultimateType = com.btc.serviceidl.util.Util.getUltimateType(type)
         if (ultimateType instanceof PrimitiveType && (ultimateType as PrimitiveType).integerType !== null)
         {
            if ((ultimateType as PrimitiveType).isByte)
               "decodeEnumerableByte"
            else if ((ultimateType as PrimitiveType).isInt16)
               "decodeEnumerableShort"
         }
         else if (ultimateType instanceof PrimitiveType && (ultimateType as PrimitiveType).charType !== null)
            "decodeEnumerableChar"
         else if (ultimateType instanceof PrimitiveType && (ultimateType as PrimitiveType).uuidType !== null)
            "decodeEnumerableUUID"
         else
            "decodeEnumerable<" + toText(ultimateType, type) + ", " + resolveProtobuf(ultimateType) + ">" 
      }
      else if (com.btc.serviceidl.util.Util.isByte(type))
         return "decodeByte"
      else if (com.btc.serviceidl.util.Util.isInt16(type))
         return "decodeShort"
      else if (com.btc.serviceidl.util.Util.isChar(type))
         return "decodeChar"
      else if (com.btc.serviceidl.util.Util.isUUIDType(type))
         return "decodeUUID"
      else 
         "decode"
   }

   def private dispatch String makeDecode(AbstractType element, EObject owner)
   {
      if (element.referenceType !== null)
         return makeDecode(element.referenceType, owner)
   }

   def private void generateClientConsole(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.CLIENT_CONSOLE)
      
      val project_root_path = getProjectRootPath()
      
      val program_name = "Program"
      cs_files.add(program_name)
      file_system_access.generateFile(project_root_path + program_name.cs,
         generateSourceFile(generateCsClientConsoleProgram(program_name, module).toString)
      )
      
      file_system_access.generateFile(project_root_path + "App".config, generateAppConfig(module))
      
      val log4net_name = log4NetConfigFile
      file_system_access.generateFile(project_root_path + log4net_name, generateLog4NetConfig(module))
      
      generateVSProjectFiles(project_root_path)
   }

   def private generateCsClientConsoleProgram(String class_name, ModuleDeclaration module)
   {
      reinitializeFile

      new ClientConsoleProgramGenerator(basicCSharpSourceGenerator, nuget_packages).generate(class_name, module)      
   }

   def private void generateServerRunner(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.SERVER_RUNNER)
      
      val project_root_path = getProjectRootPath()
      
      val program_name = "Program"
      cs_files.add(program_name)
      file_system_access.generateFile(project_root_path + program_name.cs,
         generateSourceFile(generateCsServerRunnerProgram(program_name, module))
      )
      
      file_system_access.generateFile(project_root_path + "App".config, generateAppConfig(module))
      
      val log4net_name = log4NetConfigFile
      file_system_access.generateFile(project_root_path + log4net_name, generateLog4NetConfig(module))
      
      generateVSProjectFiles(project_root_path)
   }
   
   def private String generateLog4NetConfig(ModuleDeclaration module)
   {
      '''
      <log4net>
         <appender name="RollingLogFileAppender" type="log4net.Appender.RollingFileAppender">
            <file value="log_«GeneratorUtil.transform(param_bundle.with(TransformType.PACKAGE).build).toLowerCase».txt"/>
            <appendToFile value="true"/>
            <datePattern value="yyyyMMdd"/>
            <rollingStyle value="Date"/>
            <MaxSizeRollBackups value="180" />
            <filter type="log4net.Filter.LevelRangeFilter">
               <acceptOnMatch value="true"/>
               <levelMin value="INFO"/>
               <levelMax value="FATAL"/>
            </filter>
            <layout type="log4net.Layout.PatternLayout">
               <conversionPattern value="%-5p %-25d thr:%-5t %9rms %c{1},%M: %m%n"/>
            </layout>
         </appender>
      
         <appender name="ColoredConsoleAppender" type="log4net.Appender.ColoredConsoleAppender">
            <mapping>
               <level value="ERROR" />
               <foreColor value="White" />
               <backColor value="Red, HighIntensity" />
            </mapping>
            <mapping>
               <level value="INFO" />
               <foreColor value="Cyan" />
            </mapping>
            <mapping>
               <level value="DEBUG" />
               <foreColor value="Green" />
            </mapping>
            <layout type="log4net.Layout.PatternLayout">
               <conversionPattern value="%date [%thread] %-5level %logger [%property{NDC}] - %message%newline" />
            </layout>
         </appender>
      
         <root>
            <level value="DEBUG" />
            <appender-ref ref="RollingLogFileAppender" />
            <appender-ref ref="ColoredConsoleAppender" />
         </root>
      </log4net>
      '''
   }
   
   def private String generateCsServerRunnerProgram(String class_name, ModuleDeclaration module)
   {
      reinitializeFile
      
      nuget_packages.resolvePackage("CommandLine")
      
      '''
      /// <summary>
      /// This application is a simplified copy of the BTC.CAB.ServiceComm.NET.ServerRunner. It only exists to have a context to start the demo server
      /// explicitly under this name or directly from VisualStudio. The configuration can also be used directly with the generic
      /// BTC.CAB.ServiceComm.NET.ServerRunner.
      /// </summary>
      public class «class_name»
      {
         public static int Main(«resolve("System.string")»[] args)
         {
            var options = new «resolve("BTC.CAB.ServiceComm.NET.ServerRunner.ServerRunnerCommandLineOptions")»();
            if (!«resolve("CommandLine.Parser")».Default.ParseArguments(args, options))
            {
               return 0;
            }
      
            «resolve("Spring.Context.IApplicationContext").alias("var")» ctx = «resolve("Spring.Context.Support.ContextRegistry")».GetContext();
         
            try
            {
               var serverRunner = new «resolve("BTC.CAB.ServiceComm.NET.ServerRunner.SpringServerRunner")»(ctx, options.ConnectionString);
               serverRunner.Start();
               // shutdown
               «resolve("System.Console")».WriteLine("Press any key to shutdown the server");
               Console.Read();
               serverRunner.Stop();
               return 0;
            }
            catch («resolve("System.Exception")» e)
            {
               Console.WriteLine("Exception thrown by ServerRunner: "+ e);
               return 1;
            }
         }
      }
      '''
   }

   def private generateAppConfig(ModuleDeclaration module)
   {
      reinitializeFile
      new AppConfigGenerator(basicCSharpSourceGenerator).generateAppConfig(module)
   }

   def private void generateTest(String project_root_path, InterfaceDeclaration interface_declaration)
   {
      val test_name = getTestClassName(interface_declaration)
      cs_files.add(test_name)
      file_system_access.generateFile(project_root_path + test_name.cs,
         generateSourceFile(generateCsTest(test_name, interface_declaration))
      )
      
      val impl_test_name = interface_declaration.name + "ImplTest"
      cs_files.add(impl_test_name)
      file_system_access.generateFile(project_root_path + impl_test_name.cs,
         generateSourceFile(generateCsImplTest(impl_test_name, interface_declaration))
      )
      
      val server_registration_name = getServerRegistrationName(interface_declaration)
      cs_files.add(server_registration_name)
      file_system_access.generateFile(project_root_path + server_registration_name.cs,
         generateSourceFile(generateCsServerRegistration(server_registration_name, interface_declaration))
      )
      
      val zmq_integration_test_name = interface_declaration.name + "ZeroMQIntegrationTest"
      cs_files.add(zmq_integration_test_name)
      file_system_access.generateFile(project_root_path + zmq_integration_test_name.cs,
         generateSourceFile(generateCsZeroMQIntegrationTest(zmq_integration_test_name, interface_declaration))
      )
   }
   
   def private String generateCsTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val aggregate_exception = resolve("System.AggregateException")
      val not_implemented_exception = resolve("System.NotSupportedException")

      '''
      public abstract class «class_name»
      {
         protected abstract «resolve(interface_declaration)» TestSubject { get; }

         «FOR function : interface_declaration.functions»
            «val is_sync = function.sync»
            «val is_void = function.returnedType.isVoid»
            [«resolve("NUnit.Framework.Test")»]
            public void «function.name»Test()
            {
               var e = Assert.Catch(() =>
               {
                  «FOR param : function.parameters»
                     var «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
                  «ENDFOR»
                  «IF !is_void»var result = «ENDIF»TestSubject.«function.name»(«function.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT) "out " else "") + paramName.asParameter].join(", ")»)«IF !is_sync».«IF is_void»Wait()«ELSE»Result«ENDIF»«ENDIF»;
               });
               
               var realException = (e is «aggregate_exception») ? (e as «aggregate_exception»).Flatten().InnerException : e;
               
               Assert.IsInstanceOf<«not_implemented_exception»>(realException);
               Assert.IsTrue(realException.Message.Equals("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»"));
            }
         «ENDFOR»
      }
      '''
   }
   
   def private String generateCsServerRegistration(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val basic_name = interface_declaration.name
      val const_class = resolve(interface_declaration).alias(getConstName(interface_declaration))
      
      '''
      internal class «class_name» : «resolve("System.IDisposable")»
      {
         private readonly «resolve("BTC.CAB.ServiceComm.NET.Util.ServerRegistration")» _serverRegistration;
         private «resolve("BTC.CAB.ServiceComm.NET.Util.ServerRegistration")».ServerServiceRegistration _serverServiceRegistration;

         public «class_name»(«resolve("BTC.CAB.ServiceComm.NET.API.IServer")» server)
         {
            _serverRegistration = new «resolve("BTC.CAB.ServiceComm.NET.Util.ServerRegistration")»(server);
         }

         public void RegisterService()
         {
            // create ServiceDescriptor for «basic_name»
            var serviceDescriptor = new «resolve("BTC.CAB.ServiceComm.NET.API.DTO.ServiceDescriptor")»()
            {
               ServiceTypeGuid = «const_class».«typeGuidProperty»,
               ServiceTypeName = «const_class».«typeNameProperty»,
               ServiceInstanceName = "«basic_name»TestService",
               ServiceInstanceDescription = "«resolve(interface_declaration)» instance for integration tests",
               ServiceInstanceGuid = «resolve("System.Guid")».NewGuid()
            };
      
            // create «basic_name» instance and dispatcher
            var protoBufServerHelper = new «resolve("BTC.CAB.ServiceComm.NET.ProtobufUtil.ProtoBufServerHelper")»();
            var dispatchee = new «resolve(interface_declaration, ProjectType.IMPL)»();
            var dispatcher = new «resolve(interface_declaration, ProjectType.DISPATCHER)»(dispatchee, protoBufServerHelper);
      
            // register dispatcher
            _serverServiceRegistration = _serverRegistration.RegisterService(serviceDescriptor, dispatcher);
         }

         public void Dispose()
         {
            _serverServiceRegistration.Dispose();
         }
      }
      '''
   }

   def private String generateCsZeroMQIntegrationTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val api_class_name = resolve(interface_declaration)
      val logger_factory = resolve("BTC.CAB.Logging.Log4NET.Log4NETLoggerFactory")
      val server_registration = getServerRegistrationName(interface_declaration)
      
      // explicit resolution of necessary assemblies
      resolve("BTC.CAB.Logging.API.NET.ILoggerFactory")
      resolve("BTC.CAB.ServiceComm.NET.Base.AServiceDispatcherBase")
      
      '''
      [«resolve("NUnit.Framework.TestFixture")»]
      public class «class_name» : «getTestClassName(interface_declaration)»
      {
         private «api_class_name» _testSubject;
         
         private «resolve("BTC.CAB.ServiceComm.NET.API.IClient")» _client;
         private «server_registration» _serverRegistration;
         private «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.API.IConnectionFactory")» _serverConnectionFactory;
         private «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.Server")» _server;
         
         public «class_name»()
         {}
      
         [«resolve("NUnit.Framework.SetUp")»]
         public void SetupEndpoints()
         {
            const «resolve("System.string")» connectionString = "tcp://127.0.0.1:«Constants.DEFAULT_PORT»";
            
            var loggerFactory = new «logger_factory»();
            
            // server
            StartServer(loggerFactory, connectionString);
            
            // client
            «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.API.IConnectionFactory")» connectionFactory = new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.ZeroMqClientConnectionFactory")»(loggerFactory);
            _client = new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.Client")»(connectionString, new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.AsyncRpcClientEndpoint")»(loggerFactory), connectionFactory);
            
            _testSubject = «resolve(interface_declaration, ProjectType.PROXY).alias(getProxyFactoryName(interface_declaration))».CreateProtobufProxy(_client.ClientEndpoint);
         }
      
         private void StartServer(«logger_factory» loggerFactory, string connectionString)
         {
            _serverConnectionFactory = new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.ZeroMqServerConnectionFactory")»(loggerFactory);
            _server = new Server(connectionString, new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.AsyncRpcServerEndpoint")»(loggerFactory), _serverConnectionFactory);
            _serverRegistration = new «server_registration»(_server);
            _serverRegistration.RegisterService();
            // ensure that the server runs when the client is created.
            System.Threading.Thread.Sleep(1000);
         }
      
         [«resolve("NUnit.Framework.TearDown")»]
         public void TearDownClientEndpoint()
         {
            _serverRegistration.Dispose();
            _server.Dispose();
            _testSubject = null;
            if (_client !== null)
               _client.Dispose();
         }
      
         protected override «api_class_name» TestSubject
         {
            get { return _testSubject; }
         }
      }
      '''
   }

   def private String generateCsImplTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val api_class_name = resolve(interface_declaration)
      
      '''
      [«resolve("NUnit.Framework.TestFixture")»]
      public class «class_name» : «getTestClassName(interface_declaration)»
      {
         private «api_class_name» _testSubject;
         
         [«resolve("NUnit.Framework.SetUp")»]
         public void Setup()
         {
            _testSubject = new «resolve(interface_declaration, ProjectType.IMPL)»();
         }
         
         protected override «api_class_name» TestSubject
         {
            get { return _testSubject; }
         }
      }
      '''
   }

   def private void generateProxy(String project_root_path, InterfaceDeclaration interface_declaration)
   {
      val proxy_factory_name = getProxyFactoryName(interface_declaration)
      cs_files.add(proxy_factory_name)
      file_system_access.generateFile(project_root_path + proxy_factory_name.cs,
         generateSourceFile(generateProxyFactory(proxy_factory_name, interface_declaration))
      )

      val proxy_protocol_name = interface_declaration.name + "Protocol"
      cs_files.add(proxy_protocol_name)
      file_system_access.generateFile(project_root_path + proxy_protocol_name.cs,
         generateSourceFile(generateProxyProtocol(proxy_protocol_name, interface_declaration))
      )

      val proxy_data_name = interface_declaration.name + "Data"
      cs_files.add(proxy_data_name)
      file_system_access.generateFile(project_root_path + proxy_data_name.cs,
         generateSourceFile(generateProxyData(proxy_data_name, interface_declaration))
      )

      val proxy_class_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
      cs_files.add(proxy_class_name)
      file_system_access.generateFile(
         project_root_path + proxy_class_name.cs,
         generateSourceFile(generateProxyImplementation(proxy_class_name, interface_declaration))
      )
      
      // generate named events
      for (event : interface_declaration.events.filter[name !== null])
      {
         val file_name = toText(event, interface_declaration) + "Impl"
         cs_files.add(file_name)
         file_system_access.generateFile(project_root_path + file_name.cs, generateSourceFile(generateProxyEvent(event, interface_declaration)))
      }
   }
   
   def private String generateProxyEvent(EventDeclaration event, InterfaceDeclaration interface_declaration)
   {
      val deserialazing_observer = getDeserializingObserverName(event)
      
      // TODO: Handling for keys.
      '''
      public class «toText(event, event)»Impl : «toText(event, event)»
      {
            private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IClientEndpoint")» _endpoint;
            
            public «toText(event, event)»Impl(«resolve("BTC.CAB.ServiceComm.NET.API.IClientEndpoint")» endpoint)
            {
                _endpoint = endpoint;
            }
            
            /// <see cref="IObservable{T}.Subscribe"/>
            public override «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«toText(event.data, event)»> subscriber)
            {
                _endpoint.EventRegistry.CreateEventRegistration(«toText(event.data, event)».«eventTypeGuidProperty», EventKind.EventKindPublishSubscribe, «toText(event.data, event)».«eventTypeGuidProperty».ToString());
                return _endpoint.EventRegistry.SubscriberManager.Subscribe(«toText(event.data, event)».«eventTypeGuidProperty», new «deserialazing_observer»(subscriber),
                    EventKind.EventKindPublishSubscribe);
            }
            
            class «deserialazing_observer» : «resolve("System.IObserver")»<«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")»>
            {
                private readonly «resolve("System.IObserver")»<«toText(event.data, event)»> _subscriber;

                public «deserialazing_observer»(«resolve("System.IObserver")»<«toText(event.data, event)»> subscriber)
                {
                    _subscriber = subscriber;
                }

                public void OnNext(«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")» value)
                {
                    var protobufEvent = «resolveProtobuf(event.data)».ParseFrom(value.PopFront());
                    _subscriber.OnNext((«toText(event.data, event)»)«resolveCodec(interface_declaration)».decode(protobufEvent));
                }

                public void OnError(Exception error)
                {
                    _subscriber.OnError(error);
                }

                public void OnCompleted()
                {
                    _subscriber.OnCompleted();
                }
            }
      }
      '''
      
   }
   
   def private String generateProxyFactory(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      '''
      public class «class_name»
      {
         public static «resolve(interface_declaration).shortName» CreateProtobufProxy(«resolve("BTC.CAB.ServiceComm.NET.API.IClientEndpoint")» endpoint)
         {
            return new «GeneratorUtil.getClassName(param_bundle.build, ProjectType.PROXY, interface_declaration.name)»(endpoint);
         }
      }
      '''
   }
   
   def private String generateProxyImplementation(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val api_fully_qualified_name = resolve(interface_declaration)
      val protocol_name = interface_declaration.name + "Protocol"
      val feature_profile = new FeatureProfile(interface_declaration)
      if (feature_profile.uses_futures)
         resolve("BTC.CAB.ServiceComm.NET.Util.ClientEndpointExtensions")
      if (feature_profile.uses_events)
         resolve("BTC.CAB.ServiceComm.NET.Util.EventRegistryExtensions")
      
      '''
      public class «class_name» : «api_fully_qualified_name.shortName»
      {
         private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IClientEndpoint")» _endpoint;
         private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IClientServiceReference")» _serviceReference;
         
         public «class_name»(IClientEndpoint endpoint)
         {
            _endpoint = endpoint;

            _serviceReference = _endpoint.ConnectService(«interface_declaration.name»Const.«typeGuidProperty»);
            «protocol_name».RegisterServiceFaults(_serviceReference.ServiceFaultHandlerManager);
         }
         
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
            «val return_type = toText(function.returnedType, function)»
            «val api_request_name = getProtobufRequestClassName(interface_declaration)»
            «val api_response_name = getProtobufResponseClassName(interface_declaration)»
            «val out_params = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
            «val is_void = function.returnedType.isVoid»
            «val is_sync = function.isSync»
            /// <see cref="«api_fully_qualified_name».«function.name»"/>
            public «makeReturnType(function)» «function.name»(
               «FOR param : function.parameters SEPARATOR ","»
                  «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function)»
               «ENDFOR»
            )
            {
               var methodRequestBuilder = «api_request_name».Types.«com.btc.serviceidl.util.Util.asRequest(function.name)».CreateBuilder();
               «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                  «val use_codec = GeneratorUtil.useCodec(param, param_bundle.artifactNature)»
                  «val encodeMethod = getEncodeMethod(param.paramType)»
                  «val codec = resolveCodec(param.paramType)»
                  methodRequestBuilder.«IF (com.btc.serviceidl.util.Util.isSequenceType(param.paramType))»AddRange«ELSE»Set«ENDIF»«param.paramName.toLowerCase.toFirstUpper»(«IF use_codec»(«resolveEncode(param.paramType)») «codec».«encodeMethod»(«ENDIF»«toText(param, function)»«IF use_codec»)«ENDIF»);
               «ENDFOR»
               var requestBuilder = «api_request_name».CreateBuilder();
               requestBuilder.Set«function.name.toLowerCase.toFirstUpper»Request(methodRequestBuilder.BuildPartial());
               var protobufRequest = requestBuilder.BuildPartial();
               
               «IF !out_params.empty»
                  // prepare placeholders for [out] parameters
                  «FOR param : out_params»
                     var «param.paramName.asParameter»Placeholder = «makeDefaultValue(param.paramType)»;
                  «ENDFOR»
                  
               «ENDIF»
               var result =_serviceReference.RequestAsync(new «resolve("BTC.CAB.ServiceComm.NET.Common.MessageBuffer")»(protobufRequest.ToByteArray())).ContinueWith(task =>
               {
                  «api_response_name» response = «api_response_name».ParseFrom(task.Result.PopFront());
                  «val use_codec = GeneratorUtil.useCodec(function.returnedType, param_bundle.artifactNature)»
                  «val decodeMethod = getDecodeMethod(function.returnedType)»
                  «val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)»
                  «val codec = resolveCodec(function.returnedType)»
                  «IF !out_params.empty»
                     // handle [out] parameters
                  «ENDIF»
                  «FOR param : out_params»
                     «val basic_name = param.paramName.asParameter»
                     «val is_sequence_param = com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                     «val use_codec_param = GeneratorUtil.useCodec(param.paramType, param_bundle.artifactNature)»
                     «val decode_method_param = getDecodeMethod(param.paramType)»
                     «val codec_param = resolveCodec(param.paramType)»
                     «basic_name»Placeholder = «IF use_codec_param»(«toText(param.paramType, param)») «codec_param».«decode_method_param»(«ENDIF»response.«function.name.toLowerCase.toFirstUpper»Response.«basic_name.toLowerCase.toFirstUpper»«IF is_sequence_param»List«ENDIF»«IF use_codec_param»)«ENDIF»;
                  «ENDFOR»
                  «IF !is_void»return «IF use_codec»(«return_type») «codec».«decodeMethod»(«ENDIF»response.«function.name.toLowerCase.toFirstUpper»Response.«function.name.toLowerCase.toFirstUpper»«IF is_sequence»List«ENDIF»«IF use_codec»)«ELSEIF is_sequence» as «toText(function.returnedType, function)»«ENDIF»;«ENDIF»
               });
               «IF out_params.empty»
                  «IF is_sync»«IF is_void»result.Wait();«ELSE»return result.Result;«ENDIF»«ELSE»return result;«ENDIF»
               «ELSE»
                  
                  result.Wait();
                  // assign [out] parameters
                  «FOR param : out_params»
                     «val basic_name = param.paramName.asParameter»
                     «basic_name» = «basic_name»Placeholder;
                  «ENDFOR»
                  «IF is_sync»«IF !is_void»return result.Result;«ENDIF»«ELSE»return result;«ENDIF»
               «ENDIF»
            }
         «ENDFOR»
         
         «FOR event : interface_declaration.events.filter[name !== null]»
            «val event_name = toText(event, interface_declaration)»
            /// <see cref="«api_fully_qualified_name».Get«event_name»"/>
            public «event_name» Get«event_name»()
            {
               return new «event_name»Impl(_endpoint);
            }
         «ENDFOR»
         «val anonymous_event = com.btc.serviceidl.util.Util.getAnonymousEvent(interface_declaration)»
         «IF anonymous_event !== null»
            «val event_type_name = toText(anonymous_event.data, anonymous_event)»
            «val deserializing_observer = getDeserializingObserverName(anonymous_event)»
            
            /// <see cref="System.IObservable.Subscribe"/>
            public «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«event_type_name»> observer)
            {
               _endpoint.EventRegistry.CreateEventRegistration(«event_type_name».«eventTypeGuidProperty», «resolve("BTC.CAB.ServiceComm.NET.API.EventKind")».EventKindPublishSubscribe, «event_type_name».«eventTypeGuidProperty».ToString());
               return _endpoint.EventRegistry.SubscriberManager.Subscribe(«resolve(anonymous_event.data)».«eventTypeGuidProperty», new «deserializing_observer»(observer),
                    EventKind.EventKindPublishSubscribe);
            }
            
            class «deserializing_observer» : «resolve("System.IObserver")»<«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")»>
            {
                private readonly «resolve("System.IObserver")»<«toText(anonymous_event.data, anonymous_event)»> _subscriber;

                public «deserializing_observer»(«resolve("System.IObserver")»<«toText(anonymous_event.data, anonymous_event)»> subscriber)
                {
                    _subscriber = subscriber;
                }

                public void OnNext(«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")» value)
                {
                    var protobufEvent = «resolveProtobuf(anonymous_event.data)».ParseFrom(value.PopFront());
                    _subscriber.OnNext((«toText(anonymous_event.data, anonymous_event)»)«resolveCodec(interface_declaration)».decode(protobufEvent));
                }

                public void OnError(Exception error)
                {
                    _subscriber.OnError(error);
                }

                public void OnCompleted()
                {
                    _subscriber.OnCompleted();
                }
            }
         «ENDIF»
      }
      '''
   }
   
   def private String generateProxyData(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile

      '''
      «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
         [«resolve("System.Runtime.Serialization.DataContract")»]
         internal class «getDataContractName(interface_declaration, function, ProtobufType.REQUEST)»
         {
            «FOR param : function.parameters»
               public «toText(param.paramType, function)» «param.paramName.asProperty» { get; set; }
            «ENDFOR»
         }
         
         «IF !function.returnedType.isVoid»
            [DataContract]
            internal class «getDataContractName(interface_declaration, function, ProtobufType.RESPONSE)»
            {
               public «toText(function.returnedType, function)» «returnValueProperty» { get; set; }
            }
         «ENDIF»
      «ENDFOR»
      '''
   }
   
   def private String generateProxyProtocol(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val protobuf_request = getProtobufRequestClassName(interface_declaration)
      val protobuf_response = getProtobufResponseClassName(interface_declaration)
      val service_fault_handler = "serviceFaultHandler"
      
      '''
      internal static class «class_name»
      {
         public static void RegisterServiceFaults(«resolve("BTC.CAB.ServiceComm.NET.API.IServiceFaultHandlerManager")» serviceFaultHandlerManager)
         {
            var «service_fault_handler» = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.ProtobufServiceFaultHandler")»();

            «makeExceptionRegistration(service_fault_handler, com.btc.serviceidl.util.Util.getRaisedExceptions(interface_declaration))»
            
            serviceFaultHandlerManager.RegisterHandler(«service_fault_handler»);
         }
         
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
            «val request_name = com.btc.serviceidl.util.Util.asRequest(function.name)»
            «val data_contract_name = getDataContractName(interface_declaration, function, ProtobufType.REQUEST)»
            public static «protobuf_request» Encode_«request_name»(«data_contract_name» arg)
            {
               var resultBuilder = «protobuf_request».Types.«request_name»
                  .CreateBuilder()
                  «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                     «val codec = resolveCodec(param.paramType)»
                     «val use_codec = GeneratorUtil.useCodec(param, param_bundle.artifactNature)»
                     «val encodeMethod = getEncodeMethod(param.paramType)»
                     .«IF (com.btc.serviceidl.util.Util.isSequenceType(param.paramType))»AddRange«ELSE»Set«ENDIF»«param.paramName.toLowerCase.toFirstUpper»(«IF use_codec»(«resolveEncode(param.paramType)») «codec».«encodeMethod»(«ENDIF»arg.«param.paramName.asProperty»«IF use_codec»)«ENDIF»)
                  «ENDFOR»
                  ;
                  
               return new «protobuf_request»
                  .Builder { «function.name.toLowerCase.toFirstUpper»Request = resultBuilder.Build() }
                  .Build();
            }
         «ENDFOR»
         
         «FOR function : interface_declaration.functions.filter[!returnedType.isVoid] SEPARATOR System.lineSeparator»
            «val response_name = getDataContractName(interface_declaration, function, ProtobufType.RESPONSE)»
            «val protobuf_message = function.name.toLowerCase.toFirstUpper»
            «val use_codec = GeneratorUtil.useCodec(function.returnedType, param_bundle.artifactNature)»
            «val decodeMethod = getDecodeMethod(function.returnedType)»
            «val return_type = toText(function.returnedType, function)»
            «val codec = resolveCodec(function.returnedType)»
            public static «response_name» Decode_«response_name»(«protobuf_response» arg)
            {
               var response = new «response_name»();
               response.«returnValueProperty» = «IF use_codec»(«return_type») «codec».«decodeMethod»(«ENDIF»arg.«protobuf_message»Response.«protobuf_message»«IF com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)»List«ENDIF»«IF use_codec»)«ENDIF»;
               return response;
            }
         «ENDFOR»
      }
      '''
   }
   
   def private void generateServiceAPI(String project_root_path, InterfaceDeclaration interface_declaration)
   {
      val anonymous_event = com.btc.serviceidl.util.Util.getAnonymousEvent(interface_declaration)
      
      // record type aliases
      for (type_alias : interface_declaration.contains.filter(AliasDeclaration))
      {
         var type_name = typedef_table.get(type_alias.name)
         if (type_name === null)
         {
            type_name = toText(type_alias.type, type_alias)
            typedef_table.put(type_alias.name, type_name)
         }
      }
      
      // generate all contained types
      for (abstract_type : interface_declaration.contains.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)])
      {
         reinitializeFile
         val file_name = Names.plain(abstract_type)
         cs_files.add(file_name)
         file_system_access.generateFile(project_root_path + file_name.cs, generateSourceFile(toText(abstract_type, interface_declaration)))
      }
      
      // generate named events
      for (event : interface_declaration.events.filter[name !== null])
      {
         val file_name = toText(event, interface_declaration)
         cs_files.add(file_name)
         file_system_access.generateFile(project_root_path + file_name.cs, generateSourceFile(generateEvent(event)))
      }
      
      // generate static class for interface-related constants
      var file_name = getConstName(interface_declaration)
      cs_files.add(file_name)
      file_system_access.generateFile(project_root_path + file_name.cs,
      generateSourceFile(
         '''
         public static class «file_name»
         {
            public static readonly «resolve("System.Guid")» «typeGuidProperty» = new Guid("«GuidMapper.get(interface_declaration)»");
            
            public static readonly «resolve("System.string")» «typeNameProperty» = typeof(«resolve(interface_declaration)»).FullName;
         }
         '''
      ))
      
      reinitializeFile
      file_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
      cs_files.add(file_name)
      file_system_access.generateFile(project_root_path + file_name.cs,
      generateSourceFile(
      '''
      «IF !interface_declaration.docComments.empty»
         /// <summary>
         «FOR comment : interface_declaration.docComments»«toText(comment, comment)»«ENDFOR»
         /// </summary>
      «ENDIF»
      public interface «GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)»«IF anonymous_event !== null» : «resolve("System.IObservable")»<«toText(anonymous_event.data, anonymous_event)»>«ENDIF»
      {
         
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
            «val is_void = function.returnedType.isVoid»
            /// <summary>
            «FOR comment : function.docComments»«toText(comment, comment)»«ENDFOR»
            /// </summary>
            «FOR parameter : function.parameters»
            /// <param name="«parameter.paramName.asParameter»"></param>
            «ENDFOR»
            «FOR exception : function.raisedExceptions»
            /// <exception cref="«toText(exception, function)»"></exception>
            «ENDFOR»
            «IF !is_void»/// <returns></returns>«ENDIF»
            «makeReturnType(function)» «function.name»(
               «FOR param : function.parameters SEPARATOR ","»
                  «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function)»
               «ENDFOR»
            );
         «ENDFOR»
         
         «FOR event : interface_declaration.events.filter[name !== null]»
            «toText(event, interface_declaration)» Get«toText(event, interface_declaration)»();
         «ENDFOR»
      }
      '''))
   }
   
   def private String generateSourceFile(String main_content)
   {
      '''
      «FOR reference : namespace_references.sort AFTER System.lineSeparator»
         using «reference»;
      «ENDFOR»
      namespace «GeneratorUtil.transform(param_bundle.with(TransformType.PACKAGE).build)»
      {
         «main_content»
      }
      '''
   }
   
   def private generateCsproj(Collection<String> cs_files)
   {
      // Please do NOT edit line indents in the code below (even though they
      // may look misplaced) unless you are fully aware of what you are doing!!!
      // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
      
      val project_name = vsSolution.getCsprojName(param_bundle)
      
      val is_protobuf = param_bundle.projectType == ProjectType.PROTOBUF
      
      if (is_protobuf)
      {
         val protobuf_references = protobuf_project_references.get(project_name)
         if (protobuf_references !== null)
         {
            for (key : protobuf_references.keySet)
            {
               if (!project_references.containsKey(key))
                  project_references.put(key, protobuf_references.get(key))
            }
         }
      }

      CSProjGenerator.generateCSProj(project_name, vsSolution, param_bundle, referenced_assemblies, nuget_packages.resolvedPackages, project_references, cs_files, if (is_protobuf) protobuf_files else null
      )      
   }
   
   def private String generateEvent(EventDeclaration event)
   {
      reinitializeFile
      
      val keys = new ArrayList<Pair<String, String>>
      for (key : event.keys)
      {
         keys.add(Tuples.create(key.keyName.asProperty, toText(key.type, event)))
      }

      '''
      public abstract class «toText(event, event)» : «resolve("System.IObservable")»<«toText(event.data, event)»>
      {
            /// <see cref="IObservable{T}.Subscribe"/>
            public abstract «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«toText(event.data, event)»> subscriber);
         
         «IF !keys.empty»
            public class KeyType
            {
               
               public KeyType(«FOR key : keys SEPARATOR ", "»«key.second» «key.first.asParameter»«ENDFOR»)
               {
                  «FOR key : keys»
                     this.«key.first» = «key.first.asParameter»;
                  «ENDFOR»
               }
               
               «FOR key : keys SEPARATOR System.lineSeparator»
                  public «key.second» «key.first.asProperty» { get; set; }
               «ENDFOR»
            }
            
            public abstract «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«toText(event.data, event)»> subscriber, «resolve("System.Collections.Generic.IEnumerable")»<KeyType> keys);
         «ENDIF»
      }
      '''
   }
   
    def private ResolvedName resolveProtobuf(EObject element)
    {
        return resolve(element, ProjectType.PROTOBUF)
    }
   
   def private String makeImplementatonStub(FunctionDeclaration function)
   {
      val is_void = function.returnedType.isVoid
      
      '''
      «IF !function.sync»
         // TODO Auto-generated method stub
         «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
            «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
         «ENDFOR»
         return «resolve("System.Threading.Tasks.Task")»«IF !is_void»<«toText(function.returnedType, function)»>«ENDIF».Factory.StartNew(() => { throw new «resolve("System.NotSupportedException")»("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»"); });
      «ELSE»
         «makeDefaultMethodStub»
      «ENDIF»
      '''
   }
   
   def private String makeDefaultMethodStub()
   {
      '''
      // TODO Auto-generated method stub
      throw new «resolve("System.NotSupportedException")»("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»");
      '''
   }
   
   def private void addGoogleProtocolBuffersReferences()
   {
      nuget_packages.resolvePackage("Google.ProtocolBuffers")
      nuget_packages.resolvePackage("Google.ProtocolBuffers.Serialization")
   }
   
   def private String getProtobufRequestClassName(InterfaceDeclaration interface_declaration)
   {
      resolve(interface_declaration, ProjectType.PROTOBUF)
      return GeneratorUtil.transform(param_bundle.with(TransformType.PACKAGE).with(ProjectType.PROTOBUF).build) + Constants.SEPARATOR_PACKAGE + com.btc.serviceidl.util.Util.asRequest(interface_declaration.name)
   }
      
   def private String getProtobufResponseClassName(InterfaceDeclaration interface_declaration)
   {
      resolve(interface_declaration, ProjectType.PROTOBUF)
      return GeneratorUtil.transform(param_bundle.with(TransformType.PACKAGE).with(ProjectType.PROTOBUF).build) + Constants.SEPARATOR_PACKAGE + com.btc.serviceidl.util.Util.asResponse(interface_declaration.name)
   }
   
   def private String getProjectRootPath()
   {
      param_bundle.artifactNature.label
         + Constants.SEPARATOR_FILE
         + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build)
         + Constants.SEPARATOR_FILE
   }
   
   def private String resolveCodec(EObject object)
   {
      val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(object)
      
      val temp_param = new ParameterBundle.Builder
      temp_param.reset(param_bundle.artifactNature)
      temp_param.reset(com.btc.serviceidl.util.Util.getModuleStack(ultimate_type))
      temp_param.reset(ProjectType.PROTOBUF)
      
      val codec_name = GeneratorUtil.getCodecName(ultimate_type)
      
      resolveProjectFilePath(ultimate_type, ProjectType.PROTOBUF)
      
      GeneratorUtil.transform(temp_param.with(TransformType.PACKAGE).build) + TransformType.PACKAGE.separator + codec_name
   }
   
   def private String getLog4NetConfigFile()
   {
      param_bundle.log4NetConfigFile
   }
         
   def private String makeDefaultValue(EObject element)
   {
      basicCSharpSourceGenerator.makeDefaultValue(element)
   }

   def private String makeExceptionRegistration(String service_fault_handler_name, Iterable<AbstractException> exceptions)
   {
      '''
      «FOR exception : exceptions.sortBy[name] SEPARATOR System.lineSeparator»
         «service_fault_handler_name».RegisterException("«com.btc.serviceidl.util.Util.getCommonExceptionName(exception, qualified_name_provider)»", typeof («resolve(exception)»));
      «ENDFOR»
            
      // most commonly used exception types
      «service_fault_handler_name».RegisterException("«Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER»", typeof(«"System.ArgumentException"»));
      
      «service_fault_handler_name».RegisterException("«Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER»", typeof(«"System.NotSupportedException"»));
      '''
   }
      
   def private String makeReturnType(FunctionDeclaration function)
   {
      val is_void = function.returnedType.isVoid
      val is_sync = function.isSync
      val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)
      val effective_type = '''«IF is_sequence»«resolve("System.Collections.Generic.IEnumerable")»<«resolve(com.btc.serviceidl.util.Util.getUltimateType(function.returnedType))»>«ELSE»«resolve(function.returnedType)»«ENDIF»'''
      
      '''«IF is_void»«IF !is_sync»«resolve("System.Threading.Tasks.Task")»«ELSE»void«ENDIF»«ELSE»«IF !is_sync»«resolve("System.Threading.Tasks.Task")»<«ENDIF»«effective_type»«IF !is_sync»>«ENDIF»«ENDIF»'''
   }
}
