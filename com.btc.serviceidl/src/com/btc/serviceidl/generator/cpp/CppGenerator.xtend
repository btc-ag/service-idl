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
 * \file       CppGenerator.xtend
 * 
 * \brief      Xtend generator for C++ artifacts from an IDL
 */

package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.FeatureProfile
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static com.btc.serviceidl.generator.cpp.TypeResolverExtensions.*

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

class CppGenerator
{
   // global variables
   private var Resource resource
   private var IFileSystemAccess file_system_access
   private var IQualifiedNameProvider qualified_name_provider
   private var IScopeProvider scope_provider
   private var IDLSpecification idl

   private val extension VSSolution vsSolution = new VSSolution

   private var param_bundle = new ParameterBundle.Builder()
   private var protobuf_project_references = new HashMap<String, HashMap<String, String>>

   private val smart_pointer_map = new HashMap<EObject, Collection<EObject>>

   // per-project global variables
   private val cab_libs = new HashSet<String>
   private val cpp_files = new HashSet<String>
   private val header_files = new HashSet<String>
   private val dependency_files = new HashSet<String>
   private val protobuf_files = new HashSet<String>
   private val odb_files = new HashSet<String>
   private val project_references = new HashMap<String, String>
   
   // per-file variables
   private var extension TypeResolver typeResolver = null   
   private var extension BasicCppGenerator basicCppGenerator = null   
   
   def public void doGenerate(Resource res, IFileSystemAccess fsa, IQualifiedNameProvider qnp, IScopeProvider sp, Set<ProjectType> projectTypes, Map<String, HashMap<String, String>> pr)
   {
      resource = res
      file_system_access = fsa
      qualified_name_provider = qnp
      scope_provider = sp
      param_bundle.reset(ArtifactNature.CPP)
      protobuf_project_references = if (pr !== null) new HashMap<String, HashMap<String, String>>(pr) else null
      
      idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
      if (idl === null)
      { return }
      
      // iterate module by module and generate included content
      for (module : idl.modules)
      {
         processModule(module, projectTypes)
      }

   }
   
   def private void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {
      param_bundle = ParameterBundle.createBuilder(com.btc.serviceidl.util.Util.getModuleStack(module))
      param_bundle.reset(ArtifactNature.CPP)
      
      if (!module.virtual)
      {
         // generate common data types and exceptions, if available
         if (projectTypes.contains(ProjectType.COMMON) && module.containsTypes)
            generateCommon(module)
         
         // generate proxy/dispatcher projects for all contained interfaces
         if (module.containsInterfaces)
         {
            if (projectTypes.contains(ProjectType.SERVICE_API)) generateInterfaceProjects(module)
            if (projectTypes.contains(ProjectType.SERVER_RUNNER)) generateServerRunner(module)
         }
         
         // generate Protobuf project, if necessary
         // TODO what does this mean?
         if (projectTypes.contains(ProjectType.PROTOBUF) && (module.containsTypes || module.containsInterfaces))
            generateProtobuf(module)
         
         if (projectTypes.contains(ProjectType.EXTERNAL_DB_IMPL) && module.containsTypes && module.containsInterfaces)
         {
            generateODB(module)
         }
      }
      
      // process nested modules
      for (nested_module : module.nestedModules)
         processModule(nested_module, projectTypes)
   }
   
   def private void reinitializeFile()
   {
      typeResolver = new TypeResolver(qualified_name_provider, param_bundle, vsSolution, project_references, cab_libs, smart_pointer_map)
      basicCppGenerator = new BasicCppGenerator(typeResolver, param_bundle, idl)
   }
   
   def private void reinitializeProject(ProjectType pt)
   {
      param_bundle.reset(pt)
      protobuf_files.clear
      cpp_files.clear
      header_files.clear
      dependency_files.clear
      odb_files.clear
      cab_libs.clear
      project_references.clear
      reinitializeFile
   }
   
   def private void generateInterfaceProjects(ModuleDeclaration module)
   {
      generateProjectStructure(ProjectType.SERVICE_API, module)
      generateProjectStructure(ProjectType.PROXY, module)
      generateProjectStructure(ProjectType.IMPL, module)
      generateProjectStructure(ProjectType.DISPATCHER, module)
      generateProjectStructure(ProjectType.TEST, module)
   }
   
   def private void generateProjectStructure(ProjectType project_type, ModuleDeclaration module)
   {
      if (project_type != ProjectType.EXTERNAL_DB_IMPL) // for ExternalDBImpl, keep both C++ and ODB artifacts
         reinitializeProject(project_type)
      
      val project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build) + Constants.SEPARATOR_FILE
      
      val export_header_file_name = (GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build) + "_export".h).toLowerCase
      file_system_access.generateFile(project_path + "include" + Constants.SEPARATOR_FILE + export_header_file_name, generateExportHeader())
      header_files.add(export_header_file_name)
      
      for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         param_bundle.reset(com.btc.serviceidl.util.Util.getModuleStack(interface_declaration))
         generateProject(project_type, interface_declaration, project_path, export_header_file_name)
      }

      val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES.cpp
      file_system_access.generateFile(project_path + "source" + Constants.SEPARATOR_FILE + dependency_file_name, generateDependencies())
      dependency_files.add(dependency_file_name)
      
      if (project_type != ProjectType.EXTERNAL_DB_IMPL) // done separately for ExternalDBImpl to include ODB files also
         generateVSProjectFiles(project_type, project_path, getVcxprojName(param_bundle, Optional.empty))
   }

   def private void generateVSProjectFiles(ProjectType project_type, String project_path, String project_name)
   {
      // root folder of the project
      file_system_access.generateFile
      (
         project_path + Constants.SEPARATOR_FILE + project_name.vcxproj,
         generateVcxproj(project_name)
      )
      file_system_access.generateFile
      (
         project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.filters,
         generateVcxprojFilters()
      )
      // *.vcxproj.user file for executable projects
      if (project_type == ProjectType.TEST || project_type == ProjectType.SERVER_RUNNER)
      {
         file_system_access.generateFile
         (
            project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.user,
            generateVcxprojUser(project_type)
         )
      }
   }

   def private void generateProtobuf(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.PROTOBUF)
      
      val project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build) + Constants.SEPARATOR_FILE
      
      // paths
      val include_path = project_path + "include" + Constants.SEPARATOR_FILE
      val source_path = project_path + "source" + Constants.SEPARATOR_FILE
      
      // file names
      var export_header_file_name = (GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build) + "_export".h).toLowerCase
      val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES + ".cpp"
      
      // sub-folder "./include"
      file_system_access.generateFile(include_path + export_header_file_name, generateExportHeader())
      header_files.add(export_header_file_name)
      
      if (module.containsTypes)
      {
         val codec_header_name = GeneratorUtil.getCodecName(module).h
         file_system_access.generateFile(include_path + codec_header_name, generateHCodec(module))
         header_files.add(codec_header_name)
      }
      for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         val codec_header_name = GeneratorUtil.getCodecName(interface_declaration).h
         file_system_access.generateFile(include_path + codec_header_name, generateHCodec(interface_declaration))
         header_files.add(codec_header_name)
      }
      
      // sub-folder "./source"
      file_system_access.generateFile(source_path + dependency_file_name, generateDependencies)
      dependency_files.add(dependency_file_name)

      // sub-folder "./gen"
      if (module.containsTypes)
      {
         val file_name = Constants.FILE_NAME_TYPES
         protobuf_files.add(file_name)
      }
      for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         val file_name = interface_declaration.name
         protobuf_files.add(file_name)
      }

      generateVSProjectFiles(ProjectType.PROTOBUF, project_path, getVcxprojName(param_bundle, Optional.empty))
   }

   def private void generateCommon(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.COMMON)
      param_bundle.reset(com.btc.serviceidl.util.Util.getModuleStack(module))
      
      val project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build) + Constants.SEPARATOR_FILE
      
      // paths
      val include_path = project_path + "include" + Constants.SEPARATOR_FILE
      val source_path = project_path + "source" + Constants.SEPARATOR_FILE
      
      // file names
      val export_header_file_name = (GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build) + "_export".h).toLowerCase
      val header_file = Constants.FILE_NAME_TYPES.h
      val cpp_file = Constants.FILE_NAME_TYPES.cpp
      val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES.cpp
      
      // sub-folder "./include"
      file_system_access.generateFile(include_path + export_header_file_name, generateExportHeader())
      file_system_access.generateFile(include_path + header_file, generateHFileCommons(module, export_header_file_name))
      header_files.add(header_file)
      header_files.add(export_header_file_name)
      
      // sub-folder "./source"
      file_system_access.generateFile(source_path + cpp_file, generateCppCommons(module, export_header_file_name))
      cpp_files.add(cpp_file)
      
      file_system_access.generateFile(source_path + dependency_file_name, generateDependencies)
      dependency_files.add(dependency_file_name)
      
      generateVSProjectFiles(ProjectType.COMMON, project_path, getVcxprojName(param_bundle, Optional.empty))
   }

   def private void generateODB(ModuleDeclaration module)
   {
      val all_elements = module.moduleComponents
         .filter[e | com.btc.serviceidl.util.Util.isStruct(e)]
         .map(e | com.btc.serviceidl.util.Util.getUltimateType(e) as StructDeclaration)
         .filter[!members.empty]
         .filter[!members.filter[m | m.name.toUpperCase == "ID" && com.btc.serviceidl.util.Util.isUUIDType(m.type)].empty]
         .resolveAllDependencies
         .map[type]
         .filter(StructDeclaration)
      
      // all structs, for which ODB files will be generated; characteristic: 
      // they have a member called "ID" with type UUID
      val id_structs = all_elements.filter[!members.filter[m | m.name.toUpperCase == "ID" && com.btc.serviceidl.util.Util.isUUIDType(m.type)].empty ]
      
      // nothing to do...
      if (id_structs.empty)
      { return }
      
      reinitializeProject(ProjectType.EXTERNAL_DB_IMPL)
      param_bundle.reset(com.btc.serviceidl.util.Util.getModuleStack(module))
      
      val project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build) + Constants.SEPARATOR_FILE
      
      // paths
      val odb_path = project_path + "odb" + Constants.SEPARATOR_FILE
      
      // collect all commonly used types to include them in an centralized header
      val common_types = all_elements
         .filter[members.filter[m | m.name.toUpperCase == "ID" && com.btc.serviceidl.util.Util.isUUIDType(m.type)].empty]
      if (!common_types.empty)
      {
         val basic_file_name = Constants.FILE_NAME_ODB_COMMON
         file_system_access.generateFile(odb_path + basic_file_name.hxx, generateCommonHxx(common_types))
         odb_files.add(basic_file_name);
      }
      for ( struct : id_structs )
      {
         val basic_file_name = struct.name.toLowerCase
         file_system_access.generateFile(odb_path + basic_file_name.hxx, generateHxx(struct))
         odb_files.add(basic_file_name);
      }
      file_system_access.generateFile(odb_path + Constants.FILE_NAME_ODB_TRAITS.hxx, generateODBTraits)
      
      generateProjectStructure(ProjectType.EXTERNAL_DB_IMPL, module)
      
      for ( interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         val basic_file_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
         header_files.add(basic_file_name.h)
         cpp_files.add(basic_file_name.cpp)
      }
      
      generateVSProjectFiles(ProjectType.EXTERNAL_DB_IMPL, project_path, getVcxprojName(param_bundle, Optional.empty))
   }

   def private void generateServerRunner(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.SERVER_RUNNER)
      param_bundle.reset(com.btc.serviceidl.util.Util.getModuleStack(module))
      
      val project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build) + Constants.SEPARATOR_FILE
      
      // paths
      val include_path = project_path + "include" + Constants.SEPARATOR_FILE
      val source_path = project_path + "source" + Constants.SEPARATOR_FILE
      val etc_path = project_path + "etc" + Constants.SEPARATOR_FILE
      
      // sub-folder "./include"
      val export_header_file_name = (GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build) + "_export".h).toLowerCase
      file_system_access.generateFile(include_path + export_header_file_name, generateExportHeader())
      header_files.add(export_header_file_name)
      
      // sub-folder "./source"
      for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         val cpp_file = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name).cpp
         file_system_access.generateFile(source_path + cpp_file, generateCppServerRunner(interface_declaration))
         cpp_files.add(cpp_file)
      }
      
      val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES.cpp
      file_system_access.generateFile(source_path + dependency_file_name, generateDependencies)
      dependency_files.add(dependency_file_name)
      
      // individual project files for every interface
      for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         cpp_files.clear
         val project_name = GeneratorUtil.transform(param_bundle.with(TransformType.PACKAGE).build) + TransformType.PACKAGE.separator + interface_declaration.name
         val cpp_file = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name).cpp
         cpp_files.add(cpp_file)
         generateVSProjectFiles(ProjectType.SERVER_RUNNER, project_path, project_name)
      }
      
      // sub-folder "./etc"
      val ioc_file_name = "ServerFactory".xml
      file_system_access.generateFile(etc_path + ioc_file_name, generateIoCServerRunner())
   }

   def private String generateIoCServerRunner()
   {
      '''
      <?xml version="1.0" encoding="utf-8"?>
      <objects BTC.CAB.IoC.Version="1.2">
         <argument-default argument="loggerFactory" type="BTC.CAB.Logging.Default.AdvancedFileLoggerFactory"/>
         <argument-default argument="connectionString" value="tcp://127.0.0.1:«Constants.DEFAULT_PORT»"/>
         <argument-default argument="threadCount" value="4"/>
         
         <object id="connectionOptions" type="BTC.CAB.ServiceComm.SQ.ZeroMQ.ConnectionOptions">
            <constructor-arg name="remoteSocketType" value="Router"/>
            <!-- ENABLE THIS SECTION FOR ZEROMQ ENCRYPTION -->
            <!--
            <constructor-arg name="authenticationMode" value="Curve"/>
            <constructor-arg name="serverSecretKey" value="«Constants.ZMQ_SERVER_PRIVATE_KEY»" />
            <constructor-arg name="serverPublicKey" value="«Constants.ZMQ_SERVER_PUBLIC_KEY»" />
            <constructor-arg name="serverAcceptAnyClientKey" value="true"/>
            -->
         </object>
         
         <object id="taskProcessorParameters" type="BTC.CAB.ServiceComm.SQ.API.TaskProcessorParameters">
            <constructor-arg name="threadCount" arg-ref="threadCount"/>
         </object>
         
         <object id="connectionFactory" type="BTC.CAB.ServiceComm.SQ.ZeroMQ.CZeroMQConnectionFactory">
            <constructor-arg name="loggerFactory" arg-ref="loggerFactory"/>
            <constructor-arg name="connectionOptions" ref="connectionOptions"/>
         </object>
         
         <object id="serverEndpointFactory" type="BTC.CAB.ServiceComm.SQ.Default.CServerEndpointFactory">
            <constructor-arg name="loggerFactory" arg-ref="loggerFactory"/>
            <constructor-arg name="serverConnectionFactory" ref="connectionFactory"/>
            <constructor-arg name="connectionString" arg-ref="connectionString"/>
            <constructor-arg name="taskProcessorParameters" ref="taskProcessorParameters"/>
         </object>
         
      </objects>
      '''
   }

   def private void generateProject(ProjectType pt, InterfaceDeclaration interface_declaration, String project_path, String export_header_file_name)
   {
      // paths
      val include_path = project_path + "include" + Constants.SEPARATOR_FILE
      val source_path = project_path + "source" + Constants.SEPARATOR_FILE
      
      // file names
      val main_header_file_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name).h
      val main_cpp_file_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name).cpp
      
      // sub-folder "./include"
      if (pt != ProjectType.TEST)
      {
         file_system_access.generateFile(include_path + Constants.SEPARATOR_FILE + main_header_file_name, generateProjectHeader(export_header_file_name, interface_declaration))
         header_files.add(main_header_file_name)
      }
      
      // sub-folder "./source"
      file_system_access.generateFile(source_path + main_cpp_file_name, generateProjectSource(interface_declaration))
      cpp_files.add(main_cpp_file_name)
   }
   
   def private String generateCppReflection(InterfaceDeclaration interface_declaration)
   {
      val class_name = resolve(interface_declaration, param_bundle.projectType)
      
      '''
      extern "C" 
      {
         «makeExportMacro()» void Reflect_«class_name.shortName»( «resolveCAB("BTC::Commons::CoreExtras::ReflectedClass")» &ci )
         {  
            ci.Set< «class_name» >().AddConstructor
            (
                ci.CContextRef()
               ,ci.CArgRefNotNull< «resolveCAB("BTC::Logging::API::LoggerFactory")» >( "loggerFactory" )
               «IF param_bundle.projectType == ProjectType.PROXY»
                  ,ci.CArgRefNotNull< «resolveCAB("BTC::ServiceComm::API::IClientEndpoint")» >( "localEndpoint" )
                  ,ci.CArgRefOptional< «resolveCAB("BTC::Commons::CoreExtras::UUID")» >( "serverServiceInstanceGuid" )
               «ELSEIF param_bundle.projectType == ProjectType.DISPATCHER»
                  ,ci.CArgRefNotNull< «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» >( "serviceEndpoint" )
                  ,ci.CArgRef< «resolveCAB("BTC::Commons::Core::AutoPtr")»<«resolve(interface_declaration, ProjectType.SERVICE_API)»> >( "dispatchee" )
               «ENDIF»
            );
         }
      }
      '''
   }
   
   def private String generateDependencies()
   {
      // proxy and dispatcher include a *.impl.h file from the Protobuf project
      // for type-conversion routines; therefore some hidden dependencies
      // exist, which are explicitly resolved here
      if (param_bundle.projectType == ProjectType.PROXY || param_bundle.projectType == ProjectType.DISPATCHER)
      {
         resolveCAB("BTC::Commons::FutureUtil::InsertableTraits")
      }
      
      '''
      «FOR lib : cab_libs.sort
      BEFORE '''#include "modules/Commons/include/BeginCabInclude.h"  // CAB -->''' + System.lineSeparator
      AFTER '''#include "modules/Commons/include/EndCabInclude.h"    // CAB <--''' + System.lineSeparator
      »
         #pragma comment(lib, "«lib»")
      «ENDFOR»
      
      «IF param_bundle.projectType == ProjectType.PROTOBUF
         || param_bundle.projectType == ProjectType.DISPATCHER
         || param_bundle.projectType == ProjectType.PROXY
         || param_bundle.projectType == ProjectType.SERVER_RUNNER
         »
         #pragma comment(lib, "libprotobuf.lib")
      «ENDIF»
      '''
   }
   
   def private String generateExportHeader()
   {
      val prefix = GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build).toUpperCase
      
      '''
      #ifndef «prefix»_EXPORT_H
      #define «prefix»_EXPORT_H
      
      #ifndef CAB_NO_LEGACY_EXPORT_MACROS
      #define CAB_NO_LEGACY_EXPORT_MACROS
      #endif
      
      #include <modules/Commons/include/Export.h>
      
      #ifdef «prefix»_STATIC_DEFINE
      #  define «prefix»_EXPORT
      #  define «prefix»_EXTERN
      #  define «prefix»_NO_EXPORT
      #else
      #  ifndef «prefix»_EXPORT
      #    ifdef «prefix»_EXPORTS
              /* We are building this library */
      #      define «prefix»_EXPORT CAB_EXPORT
      #      define «prefix»_EXTERN 
      #    else
              /* We are using this library */
      #      define «prefix»_EXPORT CAB_IMPORT
      #      define «prefix»_EXTERN CAB_EXTERN
      #    endif
      #  endif
      
      #  ifndef «prefix»_NO_EXPORT
      #    define «prefix»_NO_EXPORT CAB_NO_EXPORT
      #  endif
      #endif
      
      #endif
      
      '''
   }
   
   def private String generateVcxprojUser(ProjectType project_type)
   {
      // Please do NOT edit line indents in the code below (even though they
      // may look misplaced) unless you are fully aware of what you are doing!!!
      // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
      
      val path = if (project_type == ProjectType.TEST) "$(UnitTestLibraryPaths)" else "$(CabBin)"
      val command = if (project_type == ProjectType.TEST) "$(UnitTestRunner)" else "$(TargetPath)"
      val args = if (project_type == ProjectType.TEST) "$(UnitTestDefaultArguments)" else '''--connection tcp://127.0.0.1:«Constants.DEFAULT_PORT» --ioc $(ProjectDir)etc\ServerFactory.xml'''
      
      '''
      <?xml version="1.0" encoding="utf-8"?>
      <Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
          <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
          <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
          <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
          <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
          <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
          <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
          <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
          <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
          <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
          <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
          <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
          <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
          <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
          <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
          <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
          <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
          <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
          <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
          <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
          <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
        </PropertyGroup>
      </Project>
      '''
   }
   
   def private String generateVcxprojFilters()
   {
      // Please do NOT edit line indents in the code below (even though they
      // may look misplaced) unless you are fully aware of what you are doing!!!
      // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
      
      '''
      <?xml version="1.0" encoding="utf-8"?>
      <Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        <ItemGroup>
           «IF !cpp_files.empty || !protobuf_files.empty»
              <Filter Include="Source Files">
                <UniqueIdentifier>{4FC737F1-C7A5-4376-A066-2A32D752A2FF}</UniqueIdentifier>
                <Extensions>cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx</Extensions>
              </Filter>
           «ENDIF»
           «IF !(header_files.empty && odb_files.empty)»
              <Filter Include="Header Files">
                <UniqueIdentifier>{93995380-89BD-4b04-88EB-625FBE52EBFB}</UniqueIdentifier>
                <Extensions>h;hpp;hxx;hm;inl;inc;xsd</Extensions>
              </Filter>
           «ENDIF»
           «IF !dependency_files.empty»
              <Filter Include="Dependencies">
                <UniqueIdentifier>{0e47593f-5119-4a3e-a4ac-b88dba5ffd81}</UniqueIdentifier>
              </Filter>
           «ENDIF»
           «IF !protobuf_files.empty»
             <Filter Include="Protobuf Files">
               <UniqueIdentifier>{6f3dd233-58fc-4467-a4cc-9ba5ef3b5517}</UniqueIdentifier>
             </Filter>
           «ENDIF»
           «IF !odb_files.empty»
             <Filter Include="ODB Files">
               <UniqueIdentifier>{31ddc234-0d60-4695-be06-2c69510365ac}</UniqueIdentifier>
             </Filter>
           «ENDIF»
        </ItemGroup>
        «IF !(header_files.empty && protobuf_files.empty)»
          <ItemGroup>
            «FOR pb_h_file : protobuf_files»
               <ClCompile Include="gen\«pb_h_file.pb.h»">
                 <Filter>Header Files</Filter>
               </ClCompile>
            «ENDFOR»
            «FOR header_file : header_files»
              <ClInclude Include="include\«header_file»">
                <Filter>Header Files</Filter>
              </ClInclude>
            «ENDFOR»
          </ItemGroup>
        «ENDIF»
        «IF !(cpp_files.empty && protobuf_files.empty)»
          <ItemGroup>
            «FOR pb_cc_file : protobuf_files»
              <ClCompile Include="gen\«pb_cc_file».pb.cc">
                <Filter>Source Files</Filter>
              </ClCompile>
            «ENDFOR»
            «FOR cpp_file : cpp_files»
              <ClCompile Include="source\«cpp_file»">
                <Filter>Source Files</Filter>
              </ClCompile>
            «ENDFOR»
          </ItemGroup>
        «ENDIF»
        «IF !dependency_files.empty»
          <ItemGroup>
            «FOR dependency_file : dependency_files»
              <ClCompile Include="source\«dependency_file»">
                <Filter>Dependencies</Filter>
              </ClCompile>
            «ENDFOR»
          </ItemGroup>
        «ENDIF»
        «IF !protobuf_files.empty»
        <ItemGroup>
          «FOR proto_file : protobuf_files»
             <Google_Protocol_Buffers Include="gen\«proto_file».proto">
               <Filter>Protobuf Files</Filter>
             </Google_Protocol_Buffers>
          «ENDFOR»
        </ItemGroup>
        «ENDIF»
        «IF !odb_files.empty»
        <ItemGroup>
          «FOR odb_file : odb_files»
             <ClInclude Include="odb\«odb_file.hxx»">
               <Filter>ODB Files</Filter>
             </ClInclude>
             <ClInclude Include="odb\«odb_file»-odb.hxx">
               <Filter>ODB Files</Filter>
             </ClInclude>
             <ClInclude Include="odb\«odb_file»-odb-oracle.hxx">
               <Filter>ODB Files</Filter>
             </ClInclude>
             <ClInclude Include="odb\«odb_file»-odb-mssql.hxx">
               <Filter>ODB Files</Filter>
             </ClInclude>
          «ENDFOR»
        </ItemGroup>
        <ItemGroup>
          «FOR odb_file : odb_files»
            <ClCompile Include="odb\«odb_file»-odb.cxx">
              <Filter>ODB Files</Filter>
            </ClCompile>
            <ClCompile Include="odb\«odb_file»-odb-oracle.cxx">
              <Filter>ODB Files</Filter>
            </ClCompile>
            <ClCompile Include="odb\«odb_file»-odb-mssql.cxx">
              <Filter>ODB Files</Filter>
            </ClCompile>
          «ENDFOR»
        </ItemGroup>
        <ItemGroup>
          «FOR odb_file : odb_files»
            <None Include="odb\«odb_file»-odb.ixx">
              <Filter>ODB Files</Filter>
            </None>
            <None Include="odb\«odb_file»-odb-oracle.ixx">
              <Filter>ODB Files</Filter>
            </None>
            <None Include="odb\«odb_file»-odb-mssql.ixx">
              <Filter>ODB Files</Filter>
            </None>
          «ENDFOR»
        </ItemGroup>
        <ItemGroup>
          «FOR odb_file : odb_files»
            <CustomBuild Include="odb\«odb_file.hxx»">
              <Filter>Header Files</Filter>
            </CustomBuild>
          «ENDFOR»
        </ItemGroup>
        «ENDIF»
      </Project>
      '''
   }
   
   def private String generateVcxproj(String project_name)
   {
      new VcxProjGenerator(param_bundle, vsSolution, protobuf_project_references, project_references, cpp_files, 
          header_files, dependency_files, protobuf_files, odb_files
      ).generate(project_name).toString
   }
   
   def private String generateCommonHxx(Iterable<StructDeclaration> common_types)
   {
      reinitializeFile
      
      val file_content = new OdbGenerator(typeResolver).generateCommonHxx(common_types).toString      
      makeHxx(file_content, false)
   }
   
   def private String generateHxx(StructDeclaration struct)
   {
      reinitializeFile
      
      val file_content = new OdbGenerator(typeResolver).generateHxx(struct).toString
      var underlying_types = getUnderlyingTypes(struct)
      makeHxx(file_content, !underlying_types.empty)
   }
   
   def private String generateODBTraits()
   {
      reinitializeFile
      
      val file_content = new OdbGenerator(typeResolver).generateODBTraitsBody()
      
      makeHxx(file_content.toString, false)
   }
   
   def private String makeHxx(String file_content, boolean use_common_types)
   {
      '''
      #pragma once
      
      #include "modules/Commons/include/BeginPrinsModulesInclude.h"
      
      «IF use_common_types»#include "«Constants.FILE_NAME_ODB_COMMON.hxx»"«ENDIF»
      «generateIncludes(true)»
      «file_content»
      
      #include "modules/Commons/include/EndPrinsModulesInclude.h"
      '''
   }
   
     def private String generateHCodec(EObject owner)
   {
      reinitializeFile
      
      // collect all contained distinct types which need conversion
      val nested_types = GeneratorUtil.getEncodableTypes(owner)
      
      val cab_uuid = resolveCAB("BTC::Commons::CoreExtras::UUID")
      val forward_const_iterator = resolveCAB("BTC::Commons::Core::ForwardConstIterator")
      val std_vector = resolveSTL("std::vector")
      val insertable_traits = resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")
      val std_string = resolveSTL("std::string")
      val std_function = resolveSTL("std::function")
      val failable_handle = resolveCAB("BTC::Commons::CoreExtras::FailableHandle")
      val cab_exception = resolveCAB("BTC::Commons::Core::Exception")
      val cab_auto_ptr = resolveCAB("BTC::Commons::Core::AutoPtr")
      val cab_string = resolveCAB("BTC::Commons::Core::String")
      
      val failable_types = GeneratorUtil.getFailableTypes(owner)
      
      val file_content =
      '''
      namespace «GeneratorUtil.getCodecName(owner)»
      {
         static «resolveSTL("std::once_flag")» register_fault_handlers;
         static «resolveSTL("std::map")»<«std_string», «std_function»< «cab_auto_ptr»<«cab_exception»>(«cab_string» const&)> > fault_handlers;
         
         // forward declarations
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input);
         
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input);
         
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input);

         template<typename PROTOBUF_TYPE, typename API_TYPE>
         «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input);
         
         void EnsureFailableHandlers();
         
         template<typename PROTOBUF_TYPE>
         «resolveCAB("BTC::Commons::Core::AutoPtr")»<«cab_exception»> MakeException
         (
            PROTOBUF_TYPE const& protobuf_entry
         );
         
         template<typename PROTOBUF_TYPE>
         void SerializeException
         (
            const «cab_exception» &exception,
            PROTOBUF_TYPE & protobuf_item
         );
         
         template<typename PROTOBUF_TYPE, typename API_TYPE >
         void DecodeFailable
         (
            google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input,
            typename «insertable_traits»< «failable_handle»< API_TYPE > >::Type &api_output
         );
         
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         «forward_const_iterator»< «failable_handle»<API_TYPE> >
         DecodeFailable
         (
            google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input
         );
         
         template<typename API_TYPE, typename PROTOBUF_TYPE>
         void EncodeFailable
         (
            «forward_const_iterator»< «failable_handle»<API_TYPE> > api_input,
            google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output
         );
         
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         «std_vector»< «failable_handle»< API_TYPE > > DecodeFailableToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input);
         
         template<typename API_TYPE, typename PROTOBUF_TYPE>
         void EncodeFailable(«std_vector»< «failable_handle»< API_TYPE > > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output);
         
         template<typename API_TYPE, typename PROTOBUF_TYPE>
         void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output);
         
         template<typename API_TYPE, typename PROTOBUF_TYPE>
         void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* const protobuf_output);
         
         template<typename API_TYPE, typename PROTOBUF_TYPE>
         void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output);
         
         template<typename API_TYPE, typename PROTOBUF_TYPE>
         void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* protobuf_output);
         
         template<typename IDENTICAL_TYPE>
         IDENTICAL_TYPE Decode(IDENTICAL_TYPE const& protobuf_input);
         
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         void Encode(API_TYPE const& api_input, PROTOBUF_TYPE * const protobuf_output);
         
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         void Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input, typename «insertable_traits»< API_TYPE >::Type &api_output);
         
         template<typename PROTOBUF_TYPE, typename API_TYPE>
         void Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input, typename «insertable_traits»< API_TYPE >::Type &api_output);
         
         template<typename PROTOBUF_ENUM_TYPE, typename API_ENUM_TYPE>
         «forward_const_iterator»< API_ENUM_TYPE > Decode(google::protobuf::RepeatedField< google::protobuf::int32 > const& protobuf_input);
         
         template<typename IDENTICAL_TYPE>
         void Encode(IDENTICAL_TYPE const& api_input, IDENTICAL_TYPE * const protobuf_output);
         
         «std_vector»< «cab_uuid» > DecodeUUIDToVector(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input);
         
         «forward_const_iterator»< «cab_uuid» > DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input);

         void DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input, «insertable_traits»< «cab_uuid» >::Type &api_output);
         
         «cab_uuid» DecodeUUID(«std_string» const& protobuf_input);
         
         void Encode(«cab_uuid» const& api_input, «std_string» * const protobuf_output);
         
         «FOR type : nested_types»
            «val api_type_name = resolve(type)»
            «val proto_type_name = resolve(type, ProjectType.PROTOBUF)»
            «api_type_name» Decode(«proto_type_name» const& protobuf_input);
            
            «IF type instanceof EnumDeclaration»
               «proto_type_name» Encode(«api_type_name» const& api_input);
            «ELSE»
               void Encode(«api_type_name» const& api_input, «proto_type_name» * const protobuf_output);
            «ENDIF»
         «ENDFOR»
         
         «FOR type : failable_types»
            «val api_type_name = resolve(type)»
            «val proto_type_name = typeResolver.resolveFailableProtobufType(type, owner)»
            «api_type_name» DecodeFailable(«proto_type_name» const& protobuf_input);
            
            void EncodeFailable(«api_type_name» const& api_input, «proto_type_name» * const protobuf_output);
         «ENDFOR»
         
         // inline implementations
         «generateHCodecInline(owner, nested_types)»
      }
      '''
      
      // always include corresponding *.pb.h file due to local failable types definitions
      val include_path = "modules"
         + Constants.SEPARATOR_FILE
         + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build)
         + Constants.SEPARATOR_FILE
         + "gen"
         + Constants.SEPARATOR_FILE
         + GeneratorUtil.getPbFileName(owner).pb.h
      modules_includes.add(include_path)
      
      generateHeader(file_content, Optional.empty)
   }
   
   def private generateHCodecInline(EObject owner, Iterable<EObject> nested_types)
   {
       new CodecGenerator(typeResolver, param_bundle, idl).generateHCodecInline(owner, nested_types)
   }       

   def private String generateProjectSource(InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      val project_type = param_bundle.projectType
      
      val file_content =
         switch (project_type)
         {
         case ProjectType.SERVICE_API:
            generateCppServiceAPI(interface_declaration)
         case DISPATCHER:
            generateCppDispatcher(interface_declaration)
         case IMPL, case EXTERNAL_DB_IMPL:
            generateCppImpl(interface_declaration)
         case PROXY:
            generateCppProxy(interface_declaration)
         case TEST:
            generateCppTest(interface_declaration)
         case SERVER_RUNNER:
            generateCppServerRunner(interface_declaration)
         default:
            /* nothing to do for other project types */
            throw new IllegalArgumentException("Inapplicable project type:" + project_type)
         }
         
      val file_tail =
      '''
      «IF project_type == ProjectType.PROXY || project_type == ProjectType.DISPATCHER || project_type == ProjectType.IMPL»
         «generateCppReflection(interface_declaration)»
      «ENDIF»
      '''
      
      generateSource(file_content.toString, if (file_tail.trim.empty) Optional.empty else Optional.of(file_tail) )
   }
      
   def private String generateSource(String file_content, Optional<String> file_tail)
   {
      '''
      «generateIncludes(false)»
      «param_bundle.build.openNamespaces»
         «file_content»
      «param_bundle.build.closeNamespaces»
      «IF file_tail.present»«file_tail.get»«ENDIF»
      '''
   }
   
   def private generateCppServiceAPI(InterfaceDeclaration interface_declaration)
   {
       new ServiceAPIGenerator(typeResolver, param_bundle, idl).generateImplFileBody(interface_declaration)
   }
   
   def private String generateCppProxy(InterfaceDeclaration interface_declaration)
   {
      new ProxyGenerator(typeResolver, param_bundle, idl).generateImplementationFileBody(interface_declaration).toString
   }
   
   def private String generateCppImpl(InterfaceDeclaration interface_declaration)
   {
      val class_name = resolve(interface_declaration, param_bundle.projectType).shortName
      
      '''
      «class_name»::«class_name»
      (
         «resolveCAB("BTC::Commons::Core::Context")»& context
         ,«resolveCAB("BTC::Logging::API::LoggerFactory")»& loggerFactory
      ) :
      m_context(context)
      , «resolveCAB("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
      «FOR event : interface_declaration.events»
         , «event.observableName»(context)
      «ENDFOR»
      {}
      
      «generateCppDestructor(interface_declaration)»
      
      «generateInheritedInterfaceMethods(interface_declaration)»

      «FOR event : interface_declaration.events»
         «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::Commons::Core::Disposable")»> «class_name»::Subscribe( «resolveCAB("BTC::Commons::CoreExtras::IObserver")»<«toText(event.data, event)»> &observer )
         {
            return «event.observableName».Subscribe(observer);
         }
      «ENDFOR»
      '''
   }
   
   def private generateCppTest(InterfaceDeclaration interface_declaration)
   {
        new TestGenerator(typeResolver, param_bundle, idl).generateCppTest(interface_declaration)       
   }
   def private generateCppDispatcher(InterfaceDeclaration interface_declaration)
   {
       new DispatcherGenerator(typeResolver, param_bundle, idl).generateImplementationFileBody(interface_declaration)
   }
   
   def private String generateProjectHeader(String export_header, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val file_content =
         switch (param_bundle.projectType)
         {
         case SERVICE_API:
            generateInterface(interface_declaration)
         case DISPATCHER:
            generateHFileDispatcher(interface_declaration)
         case IMPL, case EXTERNAL_DB_IMPL:
            generateInterface(interface_declaration)
         case PROXY:
            generateInterface(interface_declaration)
         default:
            /* nothing to do for other project types */
            throw new IllegalArgumentException("Inapplicable project type:" + param_bundle.projectType)
         }
      
      generateHeader(file_content.toString, Optional.of(export_header))
   }
   
   def private String generateHeader(String file_content, Optional<String> export_header)
   {
      '''
      #pragma once
      #include "modules/Commons/include/BeginPrinsModulesInclude.h"
      
      «IF export_header.present»#include "«export_header.get»"«ENDIF»
      «generateIncludes(true)»
      
      «param_bundle.build.openNamespaces»
         «file_content»
      «param_bundle.build.closeNamespaces»
      #include "modules/Commons/include/EndPrinsModulesInclude.h"
      '''
   }
   
   def private String generateHFileCommons(ModuleDeclaration module, String export_header)
   {
      val sorted_types = module.topologicallySortedTypes
      val forward_declarations = resolveForwardDeclarations(sorted_types)
      
      var file_content = 
      '''
         «FOR type : forward_declarations»
            struct «Names.plain(type)»;
         «ENDFOR»

         «FOR wrapper : sorted_types»
            «toText(wrapper.type, module)»

         «ENDFOR»
      '''

      generateHeader(file_content, Optional.of(export_header))
   }
   
   def private String generateCppCommons(ModuleDeclaration module, String export_header)
   {
      reinitializeFile
      
      // for optional element, include the impl file!
      if ( new FeatureProfile(module.moduleComponents).uses_optionals
         || !module.eAllContents.filter(SequenceDeclaration).filter[failable].empty
      )
      {
         resolveCABImpl("BTC::Commons::CoreExtras::Optional")
      }
      
      val file_content =
      '''
      «FOR exception : module.moduleComponents.filter(ExceptionDeclaration)»
         «makeExceptionImplementation(exception)»
      «ENDFOR»
      
      «makeEventGUIDImplementations(typeResolver, idl, module.moduleComponents.filter(StructDeclaration))»
      '''
      
      // resolve any type to include the header: important for *.lib file
      // to be built even if there is no actual content in the *.cpp file
      resolve(module.moduleComponents.filter[o | !(o instanceof ModuleDeclaration)
         && !(o instanceof InterfaceDeclaration)].head)
      
      generateSource(file_content, Optional.empty)
   }
   
   def private String generateCppServerRunner(InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val file_content = new ServerRunnerGenerator(typeResolver, param_bundle, idl).generateImplFileBody(interface_declaration)
      
      '''
      «generateIncludes(false)»
      «file_content»
      '''
   }
      
   def private generateHFileDispatcher(InterfaceDeclaration interface_declaration)
   {
      new DispatcherGenerator(typeResolver, param_bundle, idl).generateHeaderFileBody(interface_declaration)
   }
   
   def private generateInterface(InterfaceDeclaration interface_declaration)
   {
      new ServiceAPIGenerator(typeResolver, param_bundle, idl).generateHeaderFileBody(interface_declaration)       
   }
      
}
