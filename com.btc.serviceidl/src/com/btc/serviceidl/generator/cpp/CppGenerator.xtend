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
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
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
   
   def private String generateHCodecInline(EObject owner, Collection<EObject> nested_types)
   {
      val cab_uuid = resolveCAB("BTC::Commons::CoreExtras::UUID")
      val forward_const_iterator = resolveCAB("BTC::Commons::Core::ForwardConstIterator")
      val std_vector = resolveSTL("std::vector")
      val std_string = resolveSTL("std::string")
      val std_for_each = resolveSTL("std::for_each")
      val create_default_async_insertable = resolveCAB("BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable")
      val insertable_traits = resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")
      val failable_handle = resolveCAB("BTC::Commons::CoreExtras::FailableHandle")
      val cab_exception = resolveCAB("BTC::Commons::Core::Exception")
      val cab_vector = resolveCAB("BTC::Commons::Core::Vector")
      val cab_del_exception = resolveCAB("BTC::Commons::Core::DelException")
      val cab_string = resolveCAB("BTC::Commons::Core::String")
      val cab_create_unique = resolveCAB("BTC::Commons::Core::CreateUnique")
      val std_find_if = resolveSTL("std::find_if")
      
      val failable_types = GeneratorUtil.getFailableTypes(owner)
      
      '''
      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input)
      {
         typedef «insertable_traits»< API_TYPE > APITypeTraits;
         APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< API_TYPE >() );
         APITypeTraits::FutureType future( entries->GetFuture() );
         
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
         {  entries->OnNext( Decode(protobuf_entry) ); } );
         
         entries->OnCompleted();
         return future.Get();
      }

      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input)
      {
         typedef «insertable_traits»< API_TYPE > APITypeTraits;
         APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< API_TYPE >() );
         APITypeTraits::FutureType future( entries->GetFuture() );
         
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
         {  entries->OnNext( Decode(protobuf_entry) ); } );
         
         entries->OnCompleted();
         return future.Get();
      }
      
      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input)
      {
         «std_vector»< API_TYPE > entries;
         
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
         {  entries.push_back( Decode(protobuf_entry) ); } );
         return entries;
      }
      
      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input)
      {
         «std_vector»< API_TYPE > entries;
         
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
         {  entries.push_back( Decode(protobuf_entry) ); } );
         return entries;
      }
      
      inline void EnsureFailableHandlers()
      {
         «resolveSTL("std::call_once")»(register_fault_handlers, [&]()
         {
            «FOR exception : com.btc.serviceidl.util.Util.getFailableExceptions(owner)»
               «val exception_type = resolve(exception)»
               «val exception_name = com.btc.serviceidl.util.Util.getCommonExceptionName(exception, qualified_name_provider)»
               fault_handlers["«exception_name»"] = [](«cab_string» const& msg) { return «cab_create_unique»<«exception_type»>(msg); };
            «ENDFOR»
            
            // most commonly used exception types
            «val default_exceptions = getDefaultExceptionRegistration»
            «FOR exception : default_exceptions.keySet.sort»
               fault_handlers["«exception»"] = [](«cab_string» const& msg) { return «cab_create_unique»<«default_exceptions.get(exception)»>(msg); };
            «ENDFOR»
         });
      }
      
      template<typename PROTOBUF_TYPE>
      inline «resolveCAB("BTC::Commons::Core::AutoPtr")»<«cab_exception»> MakeException
      (
         PROTOBUF_TYPE const& protobuf_entry
      )
      {
         EnsureFailableHandlers();
         
         const «cab_string» message( protobuf_entry.message().c_str() );
         const auto handler = fault_handlers.find( protobuf_entry.exception() );
         
         auto exception = ( handler != fault_handlers.end() ) ? handler->second( message ) : «cab_create_unique»<«cab_exception»>( message );
         exception->SetStackTrace( protobuf_entry.stacktrace().c_str() );
         
         return exception;
      }
      
      template<typename PROTOBUF_TYPE>
      inline void SerializeException
      (
         const «cab_exception» &exception,
         PROTOBUF_TYPE & protobuf_item
      )
      {
         EnsureFailableHandlers();

         auto match = «std_find_if»(fault_handlers.begin(), fault_handlers.end(), [&](const «resolveSTL("std::pair")»<const «std_string», «resolveSTL("std::function")»<«resolveCAB("BTC::Commons::Core::AutoPtr")»<«cab_exception»>(«cab_string» const&)>> &item) -> bool
         {
            auto sample_exception = item.second(""); // fetch sample exception to use it for type comparison!
            return ( typeid(*sample_exception) == typeid(exception) );
         });
         if (match != fault_handlers.end())
         {
            protobuf_item->set_exception( match->first );
         }
         else
         {
            protobuf_item->set_exception( «resolveCAB("CABTYPENAME")»(exception).GetChar() );
         }
         
         protobuf_item->set_message( exception.GetMessageWithType().GetChar() );
         protobuf_item->set_stacktrace( exception.GetStackTrace().GetChar() );
      }
      
      template<typename PROTOBUF_TYPE, typename API_TYPE >
      inline void DecodeFailable
      (
         google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input,
         typename «insertable_traits»< «failable_handle»< API_TYPE > >::Type &api_output
      )
      {
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( PROTOBUF_TYPE const& protobuf_entry )
         {
            if (protobuf_entry.has_exception())
            {
               api_output.OnError( MakeException(protobuf_entry) );
            }
            else
            {
               api_output.OnNext( DecodeFailable(protobuf_entry) );
            }
         } );

         api_output.OnCompleted();
      }

      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline «forward_const_iterator»< «failable_handle»<API_TYPE> >
      DecodeFailable
      (
         google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input
      )
      {
         typedef «failable_handle»<API_TYPE> ResultType;

         «resolveCAB("BTC::Commons::Core::AutoPtr")»< «cab_vector»< ResultType > > result( new «cab_vector»< ResultType >() );
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &result ]( PROTOBUF_TYPE const& protobuf_entry )
         {
            if (protobuf_entry.has_exception())
            {
               result->Add( ResultType( MakeException(protobuf_entry)) );
            }
            else
            {
               result->Add( ResultType( DecodeFailable(protobuf_entry) ) );
            }
         } );
         return «resolveCAB("BTC::Commons::CoreExtras::MakeOwningForwardConstIterator")»< ResultType >( result.Move() );
      }

      template<typename API_TYPE, typename PROTOBUF_TYPE>
      inline void EncodeFailable
      (
         «forward_const_iterator»< «failable_handle»<API_TYPE> > api_input,
         google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output
      )
      {
         for ( ; api_input; ++api_input )
         {
            «failable_handle»< API_TYPE > const& failable_item( *api_input );
            PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );

            if (failable_item.HasException())
            {
               try
               {
                  «failable_handle»< API_TYPE > item(failable_item);
                  item.Get();
               }
               catch («resolveCAB("BTC::Commons::Core::Exception")» const * e)
               {
                  «cab_del_exception» _(e);
                  SerializeException(*e, protobuf_item);
               }
            }
            else
            {
               EncodeFailable(*failable_item, protobuf_item);
            }
         }
      }

      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline «std_vector»< «failable_handle»< API_TYPE > > DecodeFailableToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input)
      {
         «std_vector»< «failable_handle»< API_TYPE > > entries;
         
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
         {
            if (protobuf_entry.has_exception())
            {
               entries.emplace_back( MakeException(protobuf_entry) );
            }
            else
            {
               entries.emplace_back( DecodeFailable(protobuf_entry) );
            }
         } );
         return entries;
      }
      
      template<typename API_TYPE, typename PROTOBUF_TYPE>
      inline void EncodeFailable(«std_vector»< «failable_handle»< API_TYPE > > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output)
      {
         for ( auto const& failable_item : api_input )
         {
            PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
            if (failable_item.HasException())
            {
               try
               {
                  «failable_handle»< API_TYPE > item(failable_item);
                  item.Get();
               }
               catch («cab_exception» const * e)
               {
                  «cab_del_exception» _(e);
                  SerializeException(*e, protobuf_item);
               }
            }
            else
            {
               EncodeFailable(*failable_item, protobuf_item);
            }
         }
      }

      template<typename API_TYPE, typename PROTOBUF_TYPE>
      inline void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output)
      {
         for ( ; api_input; ++api_input )
         {
            API_TYPE const& api_item( *api_input );
            PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
            
            Encode(api_item, protobuf_item);
         }
      }

      template<typename API_TYPE, typename PROTOBUF_TYPE>
      inline void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* const protobuf_output)
      {
         for ( ; api_input; ++api_input )
         {
            API_TYPE const& api_item( *api_input );
            PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
            
            Encode(api_item, protobuf_item);
         }
      }

      template<typename API_TYPE, typename PROTOBUF_TYPE>
      inline void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output)
      {
         for ( auto const& api_item : api_input )
         {
            PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
            Encode(api_item, protobuf_item);
         }
      }

      template<typename API_TYPE, typename PROTOBUF_TYPE>
      inline void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* protobuf_output)
      {
         for ( auto const& api_item : api_input )
         {
            PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
            Encode(api_item, protobuf_item);
         }
      }

      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline void Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input, typename «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< API_TYPE >::Type &api_output)
      {
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( PROTOBUF_TYPE const& protobuf_entry )
         {  api_output.OnNext( Decode(protobuf_entry) ); } );

         api_output.OnCompleted();
      }

      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline void Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input, typename «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< API_TYPE >::Type &api_output)
      {
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( PROTOBUF_TYPE const& protobuf_entry )
         {  api_output.OnNext( Decode(protobuf_entry) ); } );

         api_output.OnCompleted();
      }

      template<typename PROTOBUF_ENUM_TYPE, typename API_ENUM_TYPE>
      inline «forward_const_iterator»< API_ENUM_TYPE > Decode(google::protobuf::RepeatedField< google::protobuf::int32 > const& protobuf_input)
      {
         typedef «insertable_traits»< API_ENUM_TYPE > APITypeTraits;
         APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< API_ENUM_TYPE >() );
         APITypeTraits::FutureType future( entries->GetFuture() );
         
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( google::protobuf::int32 const& protobuf_entry )
         {  entries->OnNext( Decode(static_cast<PROTOBUF_ENUM_TYPE>(protobuf_entry)) ); } );
         
         entries->OnCompleted();
         return future.Get();      
      }

      template<typename IDENTICAL_TYPE>
      inline IDENTICAL_TYPE Decode(IDENTICAL_TYPE const& protobuf_input)
      {
         return protobuf_input;
      }
      
      template<typename IDENTICAL_TYPE>
      inline void Encode(IDENTICAL_TYPE const& api_input, IDENTICAL_TYPE * const protobuf_output)
      {
         *protobuf_output = api_input;
      }

      template<typename PROTOBUF_TYPE, typename API_TYPE>
      inline void Encode(API_TYPE const& api_input, PROTOBUF_TYPE * const protobuf_output)
      {
         *protobuf_output = static_cast<PROTOBUF_TYPE>( api_input );
      }

      inline «std_vector»< «cab_uuid» > DecodeUUIDToVector(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input)
      {
         «std_vector»< «cab_uuid» > entries;
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( «std_string» const& protobuf_entry )
         {  entries.push_back( DecodeUUID(protobuf_entry) ); } );
         return entries;
      }

      inline «forward_const_iterator»< «cab_uuid» > DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input)
      {
         typedef «insertable_traits»< «cab_uuid» > APITypeTraits;
         APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< «cab_uuid» >() );
         APITypeTraits::FutureType future( entries->GetFuture() );

         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( «std_string» const& protobuf_entry )
         {  entries->OnNext(DecodeUUID(protobuf_entry)); });

         entries->OnCompleted();
         return future.Get();
      }
      
      inline void DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input, «insertable_traits»< «cab_uuid» >::Type &api_output)
      {
         «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( «std_string» const& protobuf_entry )
         {  api_output.OnNext( DecodeUUID(protobuf_entry) ); } );

         api_output.OnCompleted();
      }

      inline void Encode(«cab_uuid» const& api_input, «std_string» * const protobuf_output)
      {
         «resolveCAB("BTC::Commons::Core::UInt32")» param1 = 0;
         «resolveCAB("BTC::Commons::Core::UInt16")» param2 = 0;
         BTC::Commons::Core::UInt16 param3 = 0;
         «resolveSTL("std::array")»<«resolveCAB("BTC::Commons::Core::UInt8")», 8> param4 = {0};

         api_input.ExtractComponents(&param1, &param2, &param3, param4.data());

         protobuf_output->resize(16); // UUID is exactly 16 bytes long

         «resolveSTL("std::copy")»(static_cast<const char*>(static_cast<const void*>(&param1)),
            static_cast<const char*>(static_cast<const void*>(&param1)) + 4,
            protobuf_output->begin());

         std::copy(static_cast<const char*>(static_cast<const void*>(&param2)),
            static_cast<const char*>(static_cast<const void*>(&param2)) + 2,
            protobuf_output->begin() + 4);

         std::copy(static_cast<const char*>(static_cast<const void*>(&param3)),
            static_cast<const char*>(static_cast<const void*>(&param3)) + 2,
            protobuf_output->begin() + 6);

         std::copy( param4.begin(), param4.end(), protobuf_output->begin() + 8);
      }

      inline «cab_uuid» DecodeUUID(«std_string» const& protobuf_input)
      {
         «resolveSTL("assert")»( protobuf_input.size() == 16 ); // lower half + upper half = 16 bytes!
         
         «resolveSTL("std::array")»<unsigned char, 16> raw_bytes = {0};
         «resolveSTL("std::copy")»( protobuf_input.begin(), protobuf_input.end(), raw_bytes.begin() );

         «resolveCAB("BTC::Commons::Core::UInt32")» param1 = (raw_bytes[0] << 0 | raw_bytes[1] << 8 | raw_bytes[2] << 16 | raw_bytes[3] << 24);
         «resolveCAB("BTC::Commons::Core::UInt16")» param2 = (raw_bytes[4] << 0 | raw_bytes[5] << 8);
         BTC::Commons::Core::UInt16 param3 = (raw_bytes[6] << 0 | raw_bytes[7] << 8);

         std::array<«resolveCAB("BTC::Commons::Core::UInt8")», 8> param4 = {0};
         std::copy(raw_bytes.begin() + 8, raw_bytes.end(), param4.begin());

         return «cab_uuid»::MakeFromComponents(param1, param2, param3, param4.data());
      }

      «FOR type : nested_types»
         «val api_type_name = resolve(type)»
         «val proto_type_name = resolve(type, ProjectType.PROTOBUF)»
         inline «api_type_name» Decode(«proto_type_name» const& protobuf_input)
         {
            «makeDecode(type, owner)»
         }
         
         «IF type instanceof EnumDeclaration»
            inline «proto_type_name» Encode(«api_type_name» const& api_input)
         «ELSE»
            inline void Encode(«api_type_name» const& api_input, «proto_type_name» * const protobuf_output)
         «ENDIF»
         {
            «makeEncode(type)»
         }
      «ENDFOR»
      
      «FOR type : failable_types»
         «val api_type_name = resolve(type)»
         «val proto_failable_type_name = typeResolver.resolveFailableProtobufType(type, owner)»
         «val proto_type_name = resolve(type, ProjectType.PROTOBUF)»
         inline «api_type_name» DecodeFailable(«proto_failable_type_name» const& protobuf_entry)
         {
            return «typeResolver.resolveDecode(type, owner)»(protobuf_entry.value());
         }
         
         inline void EncodeFailable(«api_type_name» const& api_input, «proto_failable_type_name» * const protobuf_output)
         {
            «val is_mutable = isMutableField(type)»
            «IF is_mutable»
               «resolveEncode(type)»(api_input, protobuf_output->mutable_value());
            «ELSE»
               «proto_type_name» value;
               «resolveEncode(type)»(api_input, &value);
               protobuf_output->set_value(value);
            «ENDIF»
         }
      «ENDFOR»
      '''
   }
   
   def private dispatch String makeDecode(StructDeclaration element, EObject container)
   {
      '''
      «resolve(element)» api_output;
      «FOR member : element.allMembers»
         «makeDecodeMember(member, container)»
      «ENDFOR»
      return api_output;
      '''
   }
   
   def private dispatch String makeDecode(ExceptionDeclaration element, EObject container)
   {
      '''
      «resolve(element)» api_output;
      «FOR member : element.allMembers»
         «makeDecodeMember(member, container)»
      «ENDFOR»
      return api_output;
      '''
   }
   
   def private dispatch String makeDecode(EnumDeclaration element, EObject container)
   {
      '''
      «FOR enum_value : element.containedIdentifiers»
         «IF enum_value != element.containedIdentifiers.head»else «ENDIF»if (protobuf_input == «typeResolver.resolveProtobuf(element, ProtobufType.REQUEST)»::«enum_value»)
            return «resolve(element)»::«enum_value»;
      «ENDFOR»
      
      «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::Commons::Core::InvalidArgumentException")»("Unknown enum value!"));
      '''
   }
   
   def private String makeDecodeMember(MemberElementWrapper element, EObject container)
   {
      val use_codec = GeneratorUtil.useCodec(element.type, param_bundle.artifactNature)
      val is_pointer = useSmartPointer(element.container, element.type)
      val is_optional = element.optional
      val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(element.type)
      val protobuf_name = element.name.toLowerCase
      val is_failable = com.btc.serviceidl.util.Util.isFailable(element.type)
      val codec_name = if (use_codec) typeResolver.resolveDecode(element.type, container, !is_failable)
      
      '''
      «IF is_optional && !is_sequence»if (protobuf_input.has_«protobuf_name»())«ENDIF»
      «IF is_optional && !is_sequence»   «ENDIF»api_output.«element.name.asMember» = «IF is_pointer»«resolveSTL("std::make_shared")»< «toText(element.type, null)» >( «ENDIF»«IF use_codec»«codec_name»( «ENDIF»protobuf_input.«protobuf_name»()«IF use_codec» )«ENDIF»«IF is_pointer» )«ENDIF»;
      '''
   }
   
   def private dispatch String makeDecode(AbstractType element, EObject container)
   {
      if (element.referenceType !== null)
         return makeDecode(element.referenceType, container)
   }
   
   def private dispatch String makeEncode(StructDeclaration element)
   {
      '''
      «FOR member : element.allMembers»
         «makeEncodeMember(member)»
      «ENDFOR»
      '''
   }
   
   def private dispatch String makeEncode(ExceptionDeclaration element)
   {
      '''
      «FOR member : element.allMembers»
         «makeEncodeMember(member)»
      «ENDFOR»
      '''
   }
   
   def private dispatch String makeEncode(EnumDeclaration element)
   {
      '''
      «FOR enum_value : element.containedIdentifiers»
         «IF enum_value != element.containedIdentifiers.head»else «ENDIF»if (api_input == «resolve(element)»::«enum_value»)
            return «typeResolver.resolveProtobuf(element, ProtobufType.RESPONSE)»::«enum_value»;
      «ENDFOR»
      
      «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::Commons::Core::InvalidArgumentException")»("Unknown enum value!"));
      '''
   }
   
   def private String makeEncodeMember(MemberElementWrapper element)
   {
      val use_codec = GeneratorUtil.useCodec(element.type, param_bundle.artifactNature)
      val optional = element.optional
      val is_enum = com.btc.serviceidl.util.Util.isEnumType(element.type)
      val is_pointer = useSmartPointer(element.container, element.type)
      '''
      «IF optional»if (api_input.«element.name.asMember»«IF is_pointer» !== nullptr«ELSE».GetIsPresent()«ENDIF»)«ENDIF»
      «IF use_codec && !(com.btc.serviceidl.util.Util.isByte(element.type) || com.btc.serviceidl.util.Util.isInt16(element.type) || com.btc.serviceidl.util.Util.isChar(element.type) || is_enum)»
         «IF optional»   «ENDIF»«resolveEncode(element.type)»( «IF optional»*( «ENDIF»api_input.«element.name.asMember»«IF optional && !is_pointer».GetValue()«ENDIF»«IF optional» )«ENDIF», protobuf_output->mutable_«element.name.toLowerCase»() );
      «ELSE»
         «IF optional»   «ENDIF»protobuf_output->set_«element.name.toLowerCase»(«IF is_enum»«resolveEncode(element.type)»( «ENDIF»«IF optional»*«ENDIF»api_input.«element.name.asMember»«IF optional && !is_pointer».GetValue()«ENDIF» «IF is_enum»)«ENDIF»);
      «ENDIF»
      '''
   }
   
   def private dispatch String makeEncode(AbstractType element)
   {
      if (element.referenceType !== null)
         return makeEncode(element.referenceType)
   }
   
   def private String resolveEncode(EObject element)
   {
      val is_failable = com.btc.serviceidl.util.Util.isFailable(element)
      if (is_failable)
         return '''EncodeFailable'''
      
      if (com.btc.serviceidl.util.Util.isUUIDType(element))
         return '''Encode'''
      
      return '''«typeResolver.resolveCodecNS(element)»::Encode'''
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
   
   def private String generateCppServiceAPI(InterfaceDeclaration interface_declaration)
   {
      val class_name = resolve(interface_declaration, param_bundle.projectType)
      
      // prepare for re-use
      val register_service_fault = resolveCAB("BTC::ServiceComm::Base::RegisterServiceFault")
      val cab_string = resolveCAB("BTC::Commons::Core::String")
      
      // collect exceptions thrown by interface methods
      val thrown_exceptions = new HashSet<AbstractException>
      interface_declaration
         .functions
         .filter[!raisedExceptions.empty]
         .map[raisedExceptions]
         .flatten
         .forEach[ thrown_exceptions.add(it) ]
      
      // for optional element, include the impl file!
      if
      (
         !interface_declaration.eAllContents.filter(MemberElement).filter[optional].empty
         || !interface_declaration.eAllContents.filter(SequenceDeclaration).filter[failable].empty
      )
      {
         resolveCABImpl("BTC::Commons::CoreExtras::Optional")
      }
      
      '''
      «FOR exception : interface_declaration.contains.filter(ExceptionDeclaration).sortBy[name]»
         «makeExceptionImplementation(exception)»
      «ENDFOR»
      
      // {«GuidMapper.get(interface_declaration)»}
      static const «resolveCAB("BTC::Commons::CoreExtras::UUID")» s«interface_declaration.name»TypeGuid = 
         «resolveCAB("BTC::Commons::CoreExtras::UUID")»::ParseString("«GuidMapper.get(interface_declaration)»");

      «resolveCAB("BTC::Commons::CoreExtras::UUID")» «class_name.shortName»::TYPE_GUID()
      {
         return s«interface_declaration.name»TypeGuid;
      }

      «makeEventGUIDImplementations(interface_declaration.contains.filter(StructDeclaration))»
      
      void «getRegisterServerFaults(interface_declaration, Optional.empty)»(«resolveCAB("BTC::ServiceComm::API::IServiceFaultHandlerManager")»& serviceFaultHandlerManager)
      {
         «IF !thrown_exceptions.empty»// register exceptions thrown by service methods«ENDIF»
         «FOR exception : thrown_exceptions.sortBy[name]»
            «val resolve_exc_name = resolve(exception)»
            «register_service_fault»<«resolve_exc_name»>(
               serviceFaultHandlerManager, «cab_string»("«com.btc.serviceidl.util.Util.getCommonExceptionName(exception, qualified_name_provider)»"));
         «ENDFOR»
         
         // most commonly used exception types
         «val default_exceptions = getDefaultExceptionRegistration»
         «FOR exception : default_exceptions.keySet.sort»
            «register_service_fault»<«default_exceptions.get(exception)»>(
               serviceFaultHandlerManager, «cab_string»("«exception»"));
         «ENDFOR»
      }
      '''
   }
   
   def private Map<String, String> getDefaultExceptionRegistration()
   {
      #{
          Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER         -> resolveCAB("BTC::Commons::Core::InvalidArgumentException")
         ,Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER    -> resolveCAB("BTC::Commons::Core::UnsupportedOperationException")
      }
   }
   
   def private String makeEventGUIDImplementations(Iterable<StructDeclaration> structs)
   {
      '''
      «FOR event_data : structs»
         «val related_event = com.btc.serviceidl.util.Util.getRelatedEvent(event_data, idl)»
         «IF related_event !== null»
            «val event_uuid = GuidMapper.get(event_data)»
            // {«event_uuid»}
            static const «resolveCAB("BTC::Commons::CoreExtras::UUID")» s«event_data.name»TypeGuid = 
               «resolveCAB("BTC::Commons::CoreExtras::UUID")»::ParseString("«event_uuid»");

            «resolveCAB("BTC::Commons::CoreExtras::UUID")» «resolve(event_data)»::EVENT_TYPE_GUID()
            {
               return s«event_data.name»TypeGuid;
            }
         «ENDIF»
      «ENDFOR»
      '''
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
   
   def private String generateCppTest(InterfaceDeclaration interface_declaration)
   {
      val api_type = resolve(interface_declaration, ProjectType.SERVICE_API)
      val subject_name = interface_declaration.name.toFirstLower
      val logger_factory = resolveCAB("BTC::Performance::CommonsTestSupport::GetTestLoggerFactory")
      val container_name = interface_declaration.name + "TestContainer"
      
      // explicitly resolve some necessary includes, because they are needed
      // for the linker due to some classes we use, but not directly referenced
      resolveCABImpl("BTC::Commons::CoreExtras::Optional")
      
      '''
      typedef «resolveCAB("BTC::ServiceComm::Util::DefaultCreateDispatcherWithContextAndEndpoint")»<
          «api_type»
         ,«resolve(interface_declaration, ProjectType.DISPATCHER)» > CreateDispatcherFunctorBaseType;

      struct CreateDispatcherFunctor : public CreateDispatcherFunctorBaseType
      {  CreateDispatcherFunctor( «resolveCAB("BTC::Commons::Core::Context")»& context ) : CreateDispatcherFunctorBaseType( context ) {} };
      
      typedef «resolveCAB("BTC::ServiceComm::Util::DispatcherAutoRegistration")»<
          «api_type»
         ,«resolve(interface_declaration, ProjectType.DISPATCHER)»
         ,CreateDispatcherFunctor > DispatcherAutoRegistrationType;
      
      // enable commented lines for ZeroMQ encryption!
      const auto serverConnectionOptionsBuilder =
         «resolveCAB("BTC::ServiceComm::SQ::ZeroMQ::ConnectionOptionsBuilder")»()
         //.WithAuthenticationMode(BTC::ServiceComm::SQ::ZeroMQ::AuthenticationMode::Curve)
         //.WithServerAcceptAnyClientKey(true)
         //.WithServerSecretKey("d{pnP/0xVmQY}DCV2BS)8Y9fw9kB/jq^id4Qp}la")
         //.WithServerPublicKey("Qr5^/{Rc{V%ji//usp(^m^{(qxC3*j.vsF+Q{XJt")
         ;
      
      // enable commented lines for ZeroMQ encryption!
      const auto clientConnectionOptionsBuilder =
         «resolveCAB("BTC::ServiceComm::SQ::ZeroMQ::ConnectionOptionsBuilder")»()
         //.WithAuthenticationMode(BTC::ServiceComm::SQ::ZeroMQ::AuthenticationMode::Curve)
         //.WithServerPublicKey("Qr5^/{Rc{V%ji//usp(^m^{(qxC3*j.vsF+Q{XJt")
         //.WithClientSecretKey("9L9K[bCFp7a]/:gJL2x{PoV}wnaAb.Zt}[qj)z/!")
         //.WithClientPublicKey("=ayKwMDx1YB]TK9hj4:II%8W2p4:Ue((iEkh30:@")
         ;
      
      struct «container_name»
      {
         «container_name»( «resolveCAB("BTC::Commons::Core::Context")»& context ) :
         m_connection( new «resolveCAB("BTC::ServiceComm::SQ::ZeroMQTestSupport::ZeroMQTestConnection")»(
             context
            ,«logger_factory»(), 1, true
            ,«resolveCAB("BTC::ServiceComm::SQ::ZeroMQTestSupport::ConnectionDirection")»::Regular
            ,clientConnectionOptionsBuilder
            ,serverConnectionOptionsBuilder
         ) )
         ,m_dispatcher( new DispatcherAutoRegistrationType(
             «api_type»::TYPE_GUID()
            ,"«api_type.shortName»"
            ,"«api_type.shortName»"
            ,«logger_factory»()
            ,m_connection->GetServerEndpoint()
            ,«resolveCAB("BTC::Commons::Core::MakeAuto")»( new «resolve(interface_declaration, ProjectType.IMPL)»(
                context
               ,«logger_factory»()
               ) )
            ,CreateDispatcherFunctor( context ) ) )
         ,m_proxy( new «resolve(interface_declaration, ProjectType.PROXY)»(
             context
            ,«logger_factory»()
            ,m_connection->GetClientEndpoint() ) )
         {}

         ~«container_name»()
         {
            m_connection->GetClientEndpoint().InitiateShutdown();
            m_connection->GetClientEndpoint().Wait();
         }

         «api_type»& GetSubject()
         {  return *m_proxy; }

      private:
         «resolveSTL("std::unique_ptr")»< «resolveCAB("BTC::ServiceComm::TestBase::ITestConnection")» > m_connection;
         «resolveSTL("std::unique_ptr")»< DispatcherAutoRegistrationType > m_dispatcher;
         «resolveSTL("std::unique_ptr")»< «api_type» > m_proxy;
      };
      
      «FOR func : interface_declaration.functions»
         «resolveCAB("TEST")»( «interface_declaration.name»_«func.name» )
         {
            «container_name» container( *GetContext() );
            «api_type»& «subject_name»( container.GetSubject() );
            
            «FOR param : func.parameters.filter[direction == ParameterDirection.PARAM_IN]»
               «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                  «val is_failable = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                  «resolveCAB("BTC::Commons::Core::Vector")»< «IF is_failable»«resolveCAB("BTC::Commons::CoreExtras::FailableHandle")»<«ENDIF»«toText(com.btc.serviceidl.util.Util.getUltimateType(param.paramType), param)»«IF is_failable»>«ENDIF» > «param.paramName.asParameter»;
               «ELSE»
                  «val type_name = toText(param.paramType, param)»
                  «type_name» «param.paramName.asParameter»«IF com.btc.serviceidl.util.Util.isEnumType(param.paramType)» = «type_name»::«(com.btc.serviceidl.util.Util.getUltimateType(param.paramType) as EnumDeclaration).containedIdentifiers.head»«ELSEIF com.btc.serviceidl.util.Util.isStruct(param.paramType)» = {}«ENDIF»;
               «ENDIF»
            «ENDFOR»
            «FOR param : func.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
               «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                  «val ulimate_type = toText(com.btc.serviceidl.util.Util.getUltimateType(param.paramType), param)»
                  «val is_failable = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                  «val inner_type = if (is_failable) '''«cab_includes.add("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h").alias(resolveCAB("BTC::Commons::CoreExtras::FailableHandle"))»< «ulimate_type» >''' else ulimate_type»
                  «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «inner_type» >::AutoPtrType «param.paramName.asParameter»( «resolveCAB("BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable")»< «inner_type» >() );
               «ELSE»
                  «val type_name = toText(param.paramType, param)»
                  «type_name» «param.paramName.asParameter»«IF com.btc.serviceidl.util.Util.isEnumType(param.paramType)» = «type_name»::«(com.btc.serviceidl.util.Util.getUltimateType(param.paramType) as EnumDeclaration).containedIdentifiers.head»«ENDIF»;
               «ENDIF»
            «ENDFOR»
            «FOR param : func.parameters»
               «val param_type = com.btc.serviceidl.util.Util.getUltimateType(param.paramType)»
               «IF param_type instanceof StructDeclaration»
                  «FOR member : param_type.allMembers.filter[!optional].filter[com.btc.serviceidl.util.Util.isEnumType(it.type)]»
                     «val enum_type = com.btc.serviceidl.util.Util.getUltimateType(member.type)»
                     «param.paramName.asParameter».«member.name.asMember» = «toText(enum_type, enum_type)»::«(enum_type as EnumDeclaration).containedIdentifiers.head»;
                  «ENDFOR»
               «ENDIF»
            «ENDFOR»
            «resolveCAB("UTTHROWS")»( «resolveCAB("BTC::Commons::Core::UnsupportedOperationException")», «subject_name».«func.name»(«func.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT && com.btc.serviceidl.util.Util.isSequenceType(paramType)) "*" else "") + paramName.asParameter + if (direction == ParameterDirection.PARAM_IN && com.btc.serviceidl.util.Util.isSequenceType(paramType)) ".GetBeginForward()" else ""].join(", ")»)«IF !func.isSync».Get()«ENDIF» );
         }
      «ENDFOR»
      
      '''
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
      
      «makeEventGUIDImplementations(module.moduleComponents.filter(StructDeclaration))»
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
   
   def private String makeExceptionImplementation(ExceptionDeclaration exception)
   {
      '''
      «IF exception.members.empty»
         «resolveCAB("CAB_SIMPLE_EXCEPTION_IMPLEMENTATION")»( «resolve(exception).shortName» )
      «ELSE»
         «val class_name = exception.name»
         // based on CAB macro CAB_SIMPLE_EXCEPTION_IMPLEMENTATION_DEFAULT_MSG from Exception.h
         «class_name»::«class_name»() : BASE("")
         {}
         
         «class_name»::«class_name»(«resolveCAB("BTC::Commons::Core::String")» const &msg) : BASE("")
         {}
         
         «class_name»::«class_name»(
            «FOR member : exception.members SEPARATOR ", "»«toText(member.type, exception)» const& «member.name.asMember»«ENDFOR»
         ) : BASE("")
            «FOR member : exception.members», «member.name.asMember»( «member.name.asMember» )«ENDFOR»
         {}
         
         «class_name»::~«class_name»()
         {}
         
         void «class_name»::Throw() const
         {
            throw this;
         }
         
         void «class_name»::Throw()
         {
            throw this;
         }
         
         «resolveCAB("BTC::Commons::Core::Exception")» *«class_name»::IntClone() const
         {
            return new «class_name»(GetSingleMsg());
         }
      «ENDIF»
      '''
   }
      
   def private boolean isMutableField(EObject type)
   {
      val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(type)
      // TODO isn't param_bundle.artifactNature always CPP here? Then the method could be made static
      val use_codec = GeneratorUtil.useCodec(ultimate_type, param_bundle.artifactNature)
      val is_enum = com.btc.serviceidl.util.Util.isEnumType(ultimate_type)

      return ( use_codec && !(com.btc.serviceidl.util.Util.isByte(ultimate_type) || com.btc.serviceidl.util.Util.isInt16(ultimate_type) || com.btc.serviceidl.util.Util.isChar(ultimate_type) || is_enum) )
   }
   
}
