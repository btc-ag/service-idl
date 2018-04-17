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

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ArtifactNature
import java.util.HashSet
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.ReturnTypeElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.ExceptionReferenceDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import org.eclipse.emf.ecore.EObject
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.DocCommentElement
import com.btc.serviceidl.generator.common.Names
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider
import com.btc.serviceidl.util.Util
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.ParameterBundle
import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.util.Extensions.*
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.ProtobufType
import java.util.HashMap
import java.util.Optional
import java.util.UUID
import com.btc.serviceidl.idl.ParameterElement
import java.util.Collection
import com.btc.serviceidl.generator.common.FeatureProfile
import java.util.concurrent.atomic.AtomicInteger
import com.btc.serviceidl.util.MemberElementWrapper
import com.btc.serviceidl.idl.MemberElement
import java.util.stream.Collectors
import java.util.LinkedHashSet
import java.util.List
import com.btc.serviceidl.generator.common.TypeWrapper
import java.util.Map
import com.btc.serviceidl.generator.common.GeneratorUtil
import java.util.Set

class CppGenerator
{
   // global variables
   private var Resource resource
   private var IFileSystemAccess file_system_access
   private var IQualifiedNameProvider qualified_name_provider
   private var IScopeProvider scope_provider
   private var IDLSpecification idl

   // it is important for this container to be static! if an *.IDL file contains
   // "import" references to external *.IDL files, each file will be generated separately
   // but we need consistent project GUIDs in order to create valid project references!
   private static val vs_projects = new HashMap<String, UUID>

   private var param_bundle = new ParameterBundle.Builder()
   private var protobuf_project_references = new HashMap<String, HashMap<String, String>>

   private val smart_pointer_map = new HashMap<EObject, Collection<EObject>>

   // per-project global variables
   private val modules_includes = new HashSet<String>
   private val cab_includes = new HashSet<String>
   private val boost_includes = new HashSet<String>
   private val stl_includes = new HashSet<String>
   private val odb_includes = new HashSet<String>
   private val cpp_files = new HashSet<String>
   private val header_files = new HashSet<String>
   private val dependency_files = new HashSet<String>
   private val protobuf_files = new HashSet<String>
   private val odb_files = new HashSet<String>
   private val cab_libs = new HashSet<String>
   private val project_references = new HashMap<String, String>
   
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
      param_bundle = ParameterBundle.createBuilder(Util.getModuleStack(module))
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
      modules_includes.clear
      cab_includes.clear
      stl_includes.clear
      boost_includes.clear
      odb_includes.clear
   }
   
   def private void reinitializeProject(ProjectType pt)
   {
      reinitializeFile
      param_bundle.reset(pt)
      protobuf_files.clear
      cpp_files.clear
      header_files.clear
      dependency_files.clear
      odb_files.clear
      cab_libs.clear
      project_references.clear
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
         param_bundle.reset(Util.getModuleStack(interface_declaration))
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
      param_bundle.reset(Util.getModuleStack(module))
      
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
         .filter[e | Util.isStruct(e)]
         .map(e | Util.getUltimateType(e) as StructDeclaration)
         .filter[!members.empty]
         .filter[!members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty]
         .resolveAllDependencies
         .map[type]
         .filter(StructDeclaration)
      
      // all structs, for which ODB files will be generated; characteristic: 
      // they have a member called "ID" with type UUID
      val id_structs = all_elements.filter[!members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty ]
      
      // nothing to do...
      if (id_structs.empty)
      { return }
      
      reinitializeProject(ProjectType.EXTERNAL_DB_IMPL)
      param_bundle.reset(Util.getModuleStack(module))
      
      val project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build) + Constants.SEPARATOR_FILE
      
      // paths
      val odb_path = project_path + "odb" + Constants.SEPARATOR_FILE
      
      // collect all commonly used types to include them in an centralized header
      val common_types = all_elements
         .filter[members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty]
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
      param_bundle.reset(Util.getModuleStack(module))
      
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
      val project_export_macro = GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build).toUpperCase
      val is_protobuf = (param_bundle.projectType == ProjectType.PROTOBUF)
      val is_server_runner = (param_bundle.projectType == ProjectType.SERVER_RUNNER)
      val is_test = (param_bundle.projectType == ProjectType.TEST)
      val is_proxy = (param_bundle.projectType == ProjectType.PROXY)
      val is_dispatcher = (param_bundle.projectType == ProjectType.DISPATCHER)
      val is_external_db_impl = (param_bundle.projectType == ProjectType.EXTERNAL_DB_IMPL)
      val project_guid = getVcxprojGUID(project_name)
      
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
      
      var prebuild_step =
      if (is_server_runner)
      {
         '''
         @ECHO @SET PATH=%%PATH%%;$(CabBin);>$(TargetDir)«project_name».bat
         @ECHO «project_name».exe --connection tcp://127.0.0.1:«Constants.DEFAULT_PORT» --ioc $(ProjectDir)etc\ServerFactory.xml >> $(TargetDir)«project_name».bat
         '''
      }
      
      // Please do NOT edit line indents in the code below (even though they
      // may look misplaced) unless you are fully aware of what you are doing!!!
      // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
      
      '''
      <?xml version="1.0" encoding="utf-8"?>
      <Project DefaultTargets="Build" ToolsVersion="14.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        <ItemGroup Label="ProjectConfigurations">
          <ProjectConfiguration Include="Debug|Win32">
            <Configuration>Debug</Configuration>
            <Platform>Win32</Platform>
          </ProjectConfiguration>
          <ProjectConfiguration Include="Debug|x64">
            <Configuration>Debug</Configuration>
            <Platform>x64</Platform>
          </ProjectConfiguration>
          <ProjectConfiguration Include="Release|Win32">
            <Configuration>Release</Configuration>
            <Platform>Win32</Platform>
          </ProjectConfiguration>
          <ProjectConfiguration Include="Release|x64">
            <Configuration>Release</Configuration>
            <Platform>x64</Platform>
          </ProjectConfiguration>
        </ItemGroup>
        <PropertyGroup Label="Globals">
          <ProjectGuid>{«project_guid»}</ProjectGuid>
          <Keyword>Win32Proj</Keyword>
        </PropertyGroup>
        <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
          <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
          <PlatformToolset>v140</PlatformToolset>
          <WholeProgramOptimization>true</WholeProgramOptimization>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
          <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
          <PlatformToolset>v140</PlatformToolset>
          <WholeProgramOptimization>true</WholeProgramOptimization>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
          <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
          <PlatformToolset>v140</PlatformToolset>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
          <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
          <PlatformToolset>v140</PlatformToolset>
        </PropertyGroup>
        <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
        <ImportGroup Label="ExtensionSettings">
        </ImportGroup>
        <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="PropertySheets">
          <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
          <Import Project="$(SolutionDir)\vsprops\modules.props" />
          «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
          «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
        </ImportGroup>
        <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="PropertySheets">
          <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
          <Import Project="$(SolutionDir)\vsprops\modules.props" />
          «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
          «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
        </ImportGroup>
        <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="PropertySheets">
          <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
          <Import Project="$(SolutionDir)\vsprops\modules.props" />
          «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
          «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
        </ImportGroup>
        <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="PropertySheets">
          <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
          <Import Project="$(SolutionDir)\vsprops\modules.props" />
          «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
          «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
        </ImportGroup>
        <PropertyGroup Label="UserMacros" />
        <PropertyGroup>
          <_ProjectFileVersion>11.0.61030.0</_ProjectFileVersion>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
          <LinkIncremental>true</LinkIncremental>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
          <LinkIncremental>true</LinkIncremental>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
          <LinkIncremental>false</LinkIncremental>
        </PropertyGroup>
        <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
          <LinkIncremental>false</LinkIncremental>
        </PropertyGroup>
        <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
          <ClCompile>
            <Optimization>Disabled</Optimization>
            «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
            <PreprocessorDefinitions>_DEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
            <MinimalRebuild>true</MinimalRebuild>
            <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
            <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
            <PrecompiledHeader />
            <WarningLevel>Level3</WarningLevel>
            <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
          </ClCompile>
          <Link>
            <GenerateDebugInformation>true</GenerateDebugInformation>
            <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
            <TargetMachine>MachineX86</TargetMachine>
            <LargeAddressAware>true</LargeAddressAware>
          </Link>
          «IF is_server_runner»
          <PreBuildEvent>
            <Command>«prebuild_step»</Command>
          </PreBuildEvent>
          «ENDIF»
        </ItemDefinitionGroup>
        <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
          <ClCompile>
            <Optimization>Disabled</Optimization>
            «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
            <PreprocessorDefinitions>_DEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
            <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
            <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
            <PrecompiledHeader>
            </PrecompiledHeader>
            <WarningLevel>Level3</WarningLevel>
            <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
          </ClCompile>
          <Link>
            <GenerateDebugInformation>true</GenerateDebugInformation>
            <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
          </Link>
          «IF is_server_runner»
          <PreBuildEvent>
            <Command>«prebuild_step»</Command>
          </PreBuildEvent>
          «ENDIF»
        </ItemDefinitionGroup>
        <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
          <ClCompile>
            <Optimization>MaxSpeed</Optimization>
            <IntrinsicFunctions>true</IntrinsicFunctions>
            «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
            <PreprocessorDefinitions>NDEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
            <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
            <FunctionLevelLinking>true</FunctionLevelLinking>
            <PrecompiledHeader />
            <WarningLevel>Level3</WarningLevel>
            <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
          </ClCompile>
          <Link>
            <GenerateDebugInformation>true</GenerateDebugInformation>
            <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
            <OptimizeReferences>true</OptimizeReferences>
            <EnableCOMDATFolding>true</EnableCOMDATFolding>
            <TargetMachine>MachineX86</TargetMachine>
            <LargeAddressAware>true</LargeAddressAware>
          </Link>
          «IF is_server_runner»
          <PreBuildEvent>
            <Command>«prebuild_step»</Command>
          </PreBuildEvent>
          «ENDIF»
        </ItemDefinitionGroup>
        <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
          <ClCompile>
            <Optimization>MaxSpeed</Optimization>
            <IntrinsicFunctions>true</IntrinsicFunctions>
            «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
            <PreprocessorDefinitions>NDEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
            <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
            <FunctionLevelLinking>true</FunctionLevelLinking>
            <PrecompiledHeader>
            </PrecompiledHeader>
            <WarningLevel>Level3</WarningLevel>
            <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
          </ClCompile>
          <Link>
            <GenerateDebugInformation>true</GenerateDebugInformation>
            <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
            <OptimizeReferences>true</OptimizeReferences>
            <EnableCOMDATFolding>true</EnableCOMDATFolding>
          </Link>
          «IF is_server_runner»
          <PreBuildEvent>
            <Command>«prebuild_step»</Command>
          </PreBuildEvent>
          «ENDIF»
        </ItemDefinitionGroup>
        «IF !protobuf_files.empty»
          <ItemGroup>
            «FOR proto_file : protobuf_files»
              <Google_Protocol_Buffers Include="gen\«proto_file».proto" />
            «ENDFOR»
          </ItemGroup>
        «ENDIF»
        «IF !(cpp_files.empty && dependency_files.empty && protobuf_files.empty && odb_files.empty)»
        <ItemGroup>
          «FOR cpp_file : cpp_files»
            <ClCompile Include="source\«cpp_file»" />
          «ENDFOR»
          «FOR dependency_file : dependency_files»
            <ClCompile Include="source\«dependency_file»" />
          «ENDFOR»
          «FOR pb_cc_file : protobuf_files»
            <ClCompile Include="gen\«pb_cc_file».pb.cc" />
          «ENDFOR»
          «FOR cxx_file : odb_files»
            <ClCompile Include="odb\«cxx_file»-odb.cxx" />
            <ClCompile Include="odb\«cxx_file»-odb-mssql.cxx" />
            <ClCompile Include="odb\«cxx_file»-odb-oracle.cxx" />
          «ENDFOR»
        </ItemGroup>
        «ENDIF»
        «IF !(header_files.empty && protobuf_files.empty && odb_files.empty)»
        <ItemGroup>
          «FOR header_file : header_files»
            <ClInclude Include="include\«header_file»" />
          «ENDFOR»
          «FOR pb_h_file : protobuf_files»
            <ClInclude Include="gen\«pb_h_file.pb.h»" />
          «ENDFOR»
          «FOR hxx_file : odb_files»
            <ClInclude Include="odb\«hxx_file.hxx»" />
            <ClInclude Include="odb\«hxx_file»-odb.hxx" />
            <ClInclude Include="odb\«hxx_file»-odb-mssql.hxx" />
            <ClInclude Include="odb\«hxx_file»-odb-oracle.hxx" />
          «ENDFOR»
          «FOR odb_file : odb_files»
            <CustomBuild Include="odb\«odb_file.hxx»">
              <Message>odb «odb_file.hxx»</Message>
              <Command>"$(ODBExe)" --std c++11 -I $(SolutionDir).. -I $(CabInc) -I $(BoostInc) --multi-database dynamic --database common --database mssql --database oracle --generate-query --generate-prepared --generate-schema --schema-format embedded «ignoreGCCWarnings» --hxx-prologue "#include \"«Constants.FILE_NAME_ODB_TRAITS.hxx»\"" --output-dir .\odb odb\«odb_file.hxx»</Command>
              <Outputs>odb\«odb_file»-odb.hxx;odb\«odb_file»-odb.ixx;odb\«odb_file»-odb.cxx;odb\«odb_file»-odb-mssql.hxx;odb\«odb_file»-odb-mssql.ixx;odb\«odb_file»-odb-mssql.cxx;odb\«odb_file»-odb-oracle.hxx;odb\«odb_file»-odb-oracle.ixx;odb\«odb_file»-odb-oracle.cxx;</Outputs>
            </CustomBuild>
          «ENDFOR»
        </ItemGroup>
        «ENDIF»
        «IF !odb_files.empty»
        <ItemGroup>
          «FOR odb_file : odb_files»
            <None Include="odb\«odb_file»-odb.ixx" />
            <None Include="odb\«odb_file»-odb-mssql.ixx" />
            <None Include="odb\«odb_file»-odb-oracle.ixx" />
          «ENDFOR»
        </ItemGroup>
        «ENDIF»
        «val effective_project_references = project_references.keySet.filter[it != project_name]»
        «IF !effective_project_references.empty»
          <ItemGroup>
            «FOR name : effective_project_references»
              <ProjectReference Include="«project_references.get(name)».vcxproj">
                <Project>{«getVcxprojGUID(name)»}</Project>
              </ProjectReference>
            «ENDFOR»
          </ItemGroup>
        «ENDIF»
        <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets" />
        <ImportGroup Label="ExtensionTargets">
          «IF is_protobuf»<Import Project="$(SolutionDir)vsprops\protobuf.targets" />«ENDIF»
        </ImportGroup>
      </Project>'''
   }
   
   def private String disableSpecfificWarnings()
   {
      '''<DisableSpecificWarnings>4068;4355;4800;4290;%(DisableSpecificWarnings)</DisableSpecificWarnings>'''
   }
   
   def private String ignoreGCCWarnings()
   {
      '''-x -Wno-unknown-pragmas -x -Wno-pragmas -x -Wno-literal-suffix -x -Wno-attributes'''
   }
   
   def private String generateCommonHxx(Iterable<StructDeclaration> common_types)
   {
      reinitializeFile
      
      val existing_column_names = new HashSet<String>
      
      val file_content =
      '''
      «FOR type : common_types»
         «IF !type.members.empty»
            #pragma db value
            struct «type.name»
            {
               «FOR member : type.allMembers»
                  «makeODBColumn(member, existing_column_names)»
               «ENDFOR»
            };
         «ENDIF»
      «ENDFOR»
      '''
      
      makeHxx(file_content, false)
   }
   
   def private String generateHxx(StructDeclaration struct)
   {
      reinitializeFile
      
      val table_name = struct.name.toUpperCase
      val class_name = struct.name.toLowerCase
      
      val existing_column_names = new HashSet<String>
      
      val file_content =
      '''
      #pragma db object table("«table_name»")
      class «class_name»
      {
      public:
         «class_name» () {}
         
         «FOR member : struct.allMembers»
            «makeODBColumn(member, existing_column_names)»
         «ENDFOR»
      };
      '''
      var underlying_types = new HashSet<StructDeclaration>
      getUnderlyingTypes(struct, underlying_types)
      makeHxx(file_content, !underlying_types.empty)
   }
   
   def private String generateODBTraits()
   {
      reinitializeFile
      
      val file_content =
      '''
      namespace odb
      {
         // ***** MSSQL *****
         namespace mssql
         {
            template<>
            struct default_type_traits<«resolveModules("BTC::PRINS::Commons::GUID")»>
            {
               static const database_type_id db_type_id = «resolveODB("id_uniqueidentifier")»;
            };
      
            template<>
            class value_traits<BTC::PRINS::Commons::GUID, id_uniqueidentifier>
            {
            public:
               typedef BTC::PRINS::Commons::GUID   value_type;
               typedef BTC::PRINS::Commons::GUID   query_type;
               typedef uniqueidentifier            image_type;
      
               static void set_value(value_type& val, const image_type& img, bool is_null)
               {
                  if (!is_null)
                  {
                     «resolveCAB("BTC::Commons::CoreExtras::UUID")» uuid;
                     «resolveSTL("std::array")»<char, 16> db_data;
                     «resolveSTL("std::memcpy")»(db_data.data(), &img, 16);
                     «resolveModules("BTC::PRINS::Commons::Utilities::GUIDHelper")»::guidEncode(db_data.data(), uuid);
                     val = BTC::PRINS::Commons::GUID::FromStringSafe("{" + uuid.ToString() + "}");
                  }
                  else
                     val = BTC::PRINS::Commons::GUID::nullGuid;
               }
      
               static void set_image(image_type& img, bool& is_null, const value_type& val)
               {
                  is_null = false;
                  auto uuid = BTC::Commons::CoreExtras::UUID::ParseString(val.ToString());
                  std::array<char, 16> db_data;
                  BTC::PRINS::Commons::Utilities::GUIDHelper::guidDecode(uuid, db_data.data());
                  std::memcpy(&img, db_data.data(), 16);
               }
            };
         }
         
         // ***** ORACLE *****
         namespace oracle
         {
            template<>
            struct default_type_traits<«resolveModules("BTC::PRINS::Commons::GUID")»>
            {
               static const database_type_id db_type_id = «resolveODB("id_raw")»;
            };
      
            template<>
            class value_traits<BTC::PRINS::Commons::GUID, id_raw>
            {
            public:
               typedef BTC::PRINS::Commons::GUID   value_type;
               typedef BTC::PRINS::Commons::GUID   query_type;
               typedef char                        image_type[16];
      
               static void set_value(value_type& val, const image_type img, std::size_t n, bool is_null)
               {
                  «resolveCAB("BTC::Commons::CoreExtras::UUID")» uuid;
                  «resolveSTL("std::vector")»<char> db_data;
                  db_data.reserve(n);
                  «resolveSTL("std::memcpy")»(db_data.data(), img, n);
                  «resolveModules("BTC::PRINS::Commons::Utilities::GUIDHelper")»::guidEncode(db_data.data(), uuid);
                  val = BTC::PRINS::Commons::GUID::FromStringSafe("{" + uuid.ToString() + "}");
               }
      
               static void set_image(image_type img, std::size_t c, std::size_t& n, bool& is_null, const value_type& val)
               {
                  is_null = false;
                  auto uuid = BTC::Commons::CoreExtras::UUID::ParseString(val.ToString());
                  std::vector<char> db_data;
                  db_data.resize(16);
                  BTC::PRINS::Commons::Utilities::GUIDHelper::guidDecode(uuid, db_data.data());
                  n = db_data.size();
                  std::memcpy (img, db_data.data(), n);
               }
            };
         }
      }
      '''
      
      makeHxx(file_content, false)
   }
   
   def private void getUnderlyingTypes(StructDeclaration struct, HashSet<StructDeclaration> all_types)
   {
      val contained_types = struct.members
         .filter[Util.getUltimateType(type) instanceof StructDeclaration]
         .map[Util.getUltimateType(type) as StructDeclaration]
      
      for ( type : contained_types )
      {
         if (!all_types.contains(type))
            getUnderlyingTypes( type, all_types )
      }
      
      all_types.addAll(contained_types)
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
   
   def private String makeODBColumn(MemberElementWrapper member, HashSet<String> existing_column_names)
   {
      val column_name = member.name.toUpperCase
      val is_uuid = Util.isUUIDType(Util.getUltimateType(member.type))
      val is_optional = member.optional
      
      val is_sequence = Util.isSequenceType(member.type)
      if (is_sequence)
         return ""
      
      val ultimate_type = Util.getUltimateType(member.type)
      if (ultimate_type instanceof StructDeclaration)
      {
         // no content for a DB column: leave
         // otherwise ODB error "No persistent data members in the class" 
         if (ultimate_type.members.empty)
            return ""
      }
      
      // Oracle does not support column names longer than 30 characters,
      // therefore we need to truncate names which exceeds this limit!
      var normalized_column_name = member.name.toUpperCase
      val size = calculateMaximalNameLength(member)
      if (size > 30)
      {
         normalized_column_name = member.name.replaceAll("[a-z]", "").toUpperCase
         var temp_name = normalized_column_name
         var index = new AtomicInteger(1);
         while (existing_column_names.contains(temp_name))
         {
            temp_name = normalized_column_name + ( index.addAndGet(1) ).toString
         }
         normalized_column_name = temp_name
      }
      
      existing_column_names.add(normalized_column_name)

      '''
      #pragma db «IF is_uuid && column_name == "ID"»id «ENDIF»column("«normalized_column_name»")«IF is_uuid» oracle:type("RAW(16)") mssql:type("UNIQUEIDENTIFIER")«ENDIF»
      «IF is_optional»«resolveODB("odb::nullable")»<«ENDIF»«resolveODBType(member.type)»«IF is_optional»>«ENDIF» «column_name»;
      '''
   }
   
   def private int calculateMaximalNameLength(MemberElementWrapper member)
   {
      val result = member.name.length
      var max = 0
      if (Util.isStruct(member.type))
      {
         val struct = Util.getUltimateType(member.type) as StructDeclaration
         for ( m : struct.allMembers)
         {
            max = Math.max(max, calculateMaximalNameLength(m))
         }
      }
      return result + max
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
            «val proto_type_name = resolveFailableProtobufType(type, owner)»
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
            «FOR exception : Util.getFailableExceptions(owner)»
               «val exception_type = resolve(exception)»
               «val exception_name = Util.getCommonExceptionName(exception, qualified_name_provider)»
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
         «val proto_failable_type_name = resolveFailableProtobufType(type, owner)»
         «val proto_type_name = resolve(type, ProjectType.PROTOBUF)»
         inline «api_type_name» DecodeFailable(«proto_failable_type_name» const& protobuf_entry)
         {
            return «resolveDecode(type, owner)»(protobuf_entry.value());
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
         «IF enum_value != element.containedIdentifiers.head»else «ENDIF»if (protobuf_input == «resolveProtobuf(element, ProtobufType.REQUEST)»::«enum_value»)
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
      val is_sequence = Util.isSequenceType(element.type)
      val protobuf_name = element.name.toLowerCase
      val is_failable = Util.isFailable(element.type)
      val codec_name = if (use_codec) resolveDecode(element.type, container, !is_failable)
      
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
            return «resolveProtobuf(element, ProtobufType.RESPONSE)»::«enum_value»;
      «ENDFOR»
      
      «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::Commons::Core::InvalidArgumentException")»("Unknown enum value!"));
      '''
   }
   
   def private String makeEncodeMember(MemberElementWrapper element)
   {
      val use_codec = GeneratorUtil.useCodec(element.type, param_bundle.artifactNature)
      val optional = element.optional
      val is_enum = Util.isEnumType(element.type)
      val is_pointer = useSmartPointer(element.container, element.type)
      '''
      «IF optional»if (api_input.«element.name.asMember»«IF is_pointer» !== nullptr«ELSE».GetIsPresent()«ENDIF»)«ENDIF»
      «IF use_codec && !(Util.isByte(element.type) || Util.isInt16(element.type) || Util.isChar(element.type) || is_enum)»
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
      val is_failable = Util.isFailable(element)
      if (is_failable)
         return '''EncodeFailable'''
      
      if (Util.isUUIDType(element))
         return '''Encode'''
      
      return '''«resolveCodecNS(element)»::Encode'''
   }
   
   def private String resolveFailableProtobufType(EObject element, EObject container)
   {
      // explicitly include some essential dependencies
      cab_libs.add("BTC.CAB.ServiceComm.Default.lib")

      var namespace = GeneratorUtil.transform
      (
         ParameterBundle
         .createBuilder(Util.getModuleStack(Util.getScopeDeterminant(container)))
         .with(ProjectType.PROTOBUF)
         .with(TransformType.NAMESPACE)
         .build
      )
      return namespace + Constants.SEPARATOR_NAMESPACE + GeneratorUtil.asFailable(element, container, qualified_name_provider)
   }
   
   def private String resolveDecode(EObject element, EObject container)
   {
      resolveDecode(element, container, true)
   }
   
   def private String resolveDecode(EObject element, EObject container, boolean use_codec_ns)
   {
      // handle sequence first, because it may include UUIDs and other types from below
      if (Util.isSequenceType(element))
      {
         val is_failable = Util.isFailable(element)
         val ultimate_type = Util.getUltimateType(element)
         
         var protobuf_type = resolve(ultimate_type, ProjectType.PROTOBUF).fullyQualifiedName
         if (is_failable)
            protobuf_type = resolveFailableProtobufType(element, container)
         else if (Util.isByte(ultimate_type) || Util.isInt16(ultimate_type) || Util.isChar(ultimate_type))
            protobuf_type = "google::protobuf::int32"
         
         var decodeMethodName = ""
         if (is_failable)
         {
            if (element.eContainer instanceof MemberElement)
               decodeMethodName = '''DecodeFailableToVector'''
            else
               decodeMethodName = '''DecodeFailable'''
         }
         else
         {
            if (element.eContainer instanceof MemberElement)
            {
               if (Util.isUUIDType(ultimate_type))
                  decodeMethodName = "DecodeUUIDToVector"
               else
                  decodeMethodName = "DecodeToVector"
            }
            else
            {
               if (Util.isUUIDType(ultimate_type))
                  decodeMethodName = "DecodeUUID"
               else
                  decodeMethodName = "Decode"
            }
         }
         
         return '''«IF use_codec_ns»«resolveCodecNS(ultimate_type, is_failable, Optional.of(container))»::«ENDIF»«decodeMethodName»«IF is_failable || !Util.isUUIDType(ultimate_type)»< «protobuf_type», «resolve(ultimate_type)» >«ENDIF»'''
      }
      
      if (Util.isUUIDType(element))
         return '''«resolveCodecNS(element)»::DecodeUUID'''
      
      if (Util.isByte(element))
         return '''static_cast<«resolveSTL("int8_t")»>'''
      
      if (Util.isInt16(element))
         return '''static_cast<«resolveSTL("int16_t")»>'''
      
      if (Util.isChar(element))
         return '''static_cast<char>'''
      
      return '''«resolveCodecNS(element)»::Decode'''
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
      
      generateSource(file_content, if (file_tail.trim.empty) Optional.empty else Optional.of(file_tail) )
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
               serviceFaultHandlerManager, «cab_string»("«Util.getCommonExceptionName(exception, qualified_name_provider)»"));
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
         «val related_event = Util.getRelatedEvent(event_data, idl)»
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
      val class_name = resolve(interface_declaration, param_bundle.projectType)
      val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
      
      // the class name is not used explicitly in the following code, but
      // we need to include this *.impl.h file to avoid linker errors
      resolveCABImpl("BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy")
      
      '''
      «class_name.shortName»::«class_name.shortName»
      (
         «resolveCAB("BTC::Commons::Core::Context")» &context
         ,«resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
         ,«resolveCAB("BTC::ServiceComm::API::IClientEndpoint")» &localEndpoint
         ,«resolveCABImpl("BTC::Commons::CoreExtras::Optional")»<«resolveCAB("BTC::Commons::CoreExtras::UUID")»> const &serverServiceInstanceGuid
      ) :
      m_context(context)
      , «resolveCAB("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
      , «interface_declaration.asBaseName»(context, localEndpoint, «api_class_name»::TYPE_GUID(), serverServiceInstanceGuid)
      «FOR event : interface_declaration.events»
      , «event.observableRegistrationName»(context, localEndpoint.GetEventRegistry(), «event.eventParamsName»())
      «ENDFOR»
      { «getRegisterServerFaults(interface_declaration, Optional.of(GeneratorUtil.transform(param_bundle.with(ProjectType.SERVICE_API).with(TransformType.NAMESPACE).build)))»( GetClientServiceReference().GetServiceFaultHandlerManager() ); }
      
      «generateCppDestructor(interface_declaration)»
      
      «generateInheritedInterfaceMethods(interface_declaration)»
      
      «FOR event : interface_declaration.events AFTER System.lineSeparator»
         «val event_type = resolve(event.data)»
         «val event_name = event_type.shortName»
         «val event_params_name = event.eventParamsName»
         
         namespace // anonymous namespace to avoid naming collisions
         {
            «event_type» const Unmarshal«event_name»( «resolveCAB("BTC::ServiceComm::API::IEventSubscriberManager")»::ObserverType::OnNextParamType event )
            {
               «resolve(event.data, ProjectType.PROTOBUF)» eventProtobuf;
               if (!(event->GetNumElements() == 1))
                  «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::ServiceComm::API::InvalidMessageReceivedException")»("Event message has not exactly one part"));
               «resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufSupport")»::ParseMessageOrThrow<«resolveCAB("BTC::ServiceComm::API::InvalidMessageReceivedException")»>(eventProtobuf, (*event)[0]);

               return «resolveCodecNS(event.data)»::Decode( eventProtobuf );
            }
         }
         
         «resolveCAB("BTC::Commons::CoreExtras::UUID")» «class_name.shortName»::«event_params_name»::GetEventTypeGuid()
         {
           /** this uses a global event type, i.e. if there are multiple instances of the service (dispatcher), these will all be subscribed;
           *  alternatively, an instance-specific type guid must be registered by the dispatcher and queried by the proxy */
           return «event_type»::EVENT_TYPE_GUID();
         }
         
         «resolveCAB("BTC::ServiceComm::API::EventKind")» «class_name.shortName»::«event_params_name»::GetEventKind()
         {
           return «resolveCAB("BTC::ServiceComm::API::EventKind")»::EventKind_PublishSubscribe;
         }
         
         «resolveCAB("BTC::Commons::Core::String")» «class_name.shortName»::«event_params_name»::GetEventTypeDescription()
         {
           return «resolveCAB("CABTYPENAME")»(«event_type»);
         }
         
         «resolveSTL("std::function")»<«class_name.shortName»::«event_params_name»::EventDataType const ( «resolveCAB("BTC::ServiceComm::Commons::ConstSharedMessageSharedPtr")» const & )> «class_name»::«event_params_name»::GetUnmarshalFunction( )
         {
           return &Unmarshal«event_name»;
         }
         
         «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::Commons::Core::Disposable")»> «class_name.shortName»::Subscribe( «resolveCAB("BTC::Commons::CoreExtras::IObserver")»<«event_type»> &observer )
         {
           return «event.observableRegistrationName».Subscribe(observer);
         }
      «ENDFOR»
      '''
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
               «IF Util.isSequenceType(param.paramType)»
                  «val is_failable = Util.isFailable(param.paramType)»
                  «resolveCAB("BTC::Commons::Core::Vector")»< «IF is_failable»«resolveCAB("BTC::Commons::CoreExtras::FailableHandle")»<«ENDIF»«toText(Util.getUltimateType(param.paramType), param)»«IF is_failable»>«ENDIF» > «param.paramName.asParameter»;
               «ELSE»
                  «val type_name = toText(param.paramType, param)»
                  «type_name» «param.paramName.asParameter»«IF Util.isEnumType(param.paramType)» = «type_name»::«(Util.getUltimateType(param.paramType) as EnumDeclaration).containedIdentifiers.head»«ELSEIF Util.isStruct(param.paramType)» = {}«ENDIF»;
               «ENDIF»
            «ENDFOR»
            «FOR param : func.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
               «IF Util.isSequenceType(param.paramType)»
                  «val ulimate_type = toText(Util.getUltimateType(param.paramType), param)»
                  «val is_failable = Util.isFailable(param.paramType)»
                  «val inner_type = if (is_failable) '''«cab_includes.add("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h").alias(resolveCAB("BTC::Commons::CoreExtras::FailableHandle"))»< «ulimate_type» >''' else ulimate_type»
                  «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «inner_type» >::AutoPtrType «param.paramName.asParameter»( «resolveCAB("BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable")»< «inner_type» >() );
               «ELSE»
                  «val type_name = toText(param.paramType, param)»
                  «type_name» «param.paramName.asParameter»«IF Util.isEnumType(param.paramType)» = «type_name»::«(Util.getUltimateType(param.paramType) as EnumDeclaration).containedIdentifiers.head»«ENDIF»;
               «ENDIF»
            «ENDFOR»
            «FOR param : func.parameters»
               «val param_type = Util.getUltimateType(param.paramType)»
               «IF param_type instanceof StructDeclaration»
                  «FOR member : param_type.allMembers.filter[!optional].filter[Util.isEnumType(it.type)]»
                     «val enum_type = Util.getUltimateType(member.type)»
                     «param.paramName.asParameter».«member.name.asMember» = «toText(enum_type, enum_type)»::«(enum_type as EnumDeclaration).containedIdentifiers.head»;
                  «ENDFOR»
               «ENDIF»
            «ENDFOR»
            «resolveCAB("UTTHROWS")»( «resolveCAB("BTC::Commons::Core::UnsupportedOperationException")», «subject_name».«func.name»(«func.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT && Util.isSequenceType(paramType)) "*" else "") + paramName.asParameter + if (direction == ParameterDirection.PARAM_IN && Util.isSequenceType(paramType)) ".GetBeginForward()" else ""].join(", ")»)«IF !func.isSync».Get()«ENDIF» );
         }
      «ENDFOR»
      
      '''
   }
   
   def private String generateHDestructor(InterfaceDeclaration interface_declaration)
   {
      val class_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
      
      '''
      /**
         \brief Object destructor
      */
      virtual ~«class_name»();
      '''
   }
   
   def private String generateCppDestructor(InterfaceDeclaration interface_declaration)
   {
      val class_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
      
      '''
      «class_name»::~«class_name»()
      {}
      '''
   }
   
   def private String generateInheritedInterfaceMethods(InterfaceDeclaration interface_declaration)
   {
      val class_name = resolve(interface_declaration, param_bundle.projectType)
      var ResolvedName protobuf_request_message
      var ResolvedName protobuf_response_message
      
      if (param_bundle.projectType == ProjectType.PROXY)
      {
         protobuf_request_message = resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
         protobuf_response_message = resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)
      }
      
      '''
      «FOR function : interface_declaration.functions»
         «IF !function.isSync»«resolveCAB("BTC::Commons::CoreExtras::Future")»<«ENDIF»«toText(function.returnedType, interface_declaration)»«IF !function.isSync»>«ENDIF» «class_name.shortName»::«function.name»(«generateParameters(function)»)«IF function.isQuery» const«ENDIF»
         {
            «IF param_bundle.projectType == ProjectType.IMPL || param_bundle.projectType == ProjectType.EXTERNAL_DB_IMPL»
               // \todo Auto-generated method stub! Implement actual business logic!
               «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::Commons::Core::UnsupportedOperationException")»( "«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»" ));
            «ENDIF»

            «IF param_bundle.projectType == ProjectType.PROXY»
               «resolveCAB("BTC::Commons::Core::UniquePtr")»< «protobuf_request_message» > request( BorrowRequestMessage() );

               // encode request -->
               auto * const concreteRequest( request->mutable_«Util.makeProtobufMethodName(function.name, Constants.PROTOBUF_REQUEST)»() );
               «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                  «IF GeneratorUtil.useCodec(param.paramType, param_bundle.artifactNature) && !(Util.isByte(param.paramType) || Util.isInt16(param.paramType) || Util.isChar(param.paramType))»
                     «IF Util.isSequenceType(param.paramType)»
                        «val ulimate_type = Util.getUltimateType(param.paramType)»
                        «val is_failable = Util.isFailable(param.paramType)»
                        «val protobuf_type = resolveProtobuf(ulimate_type, ProtobufType.RESPONSE).fullyQualifiedName»
                        «resolveCodecNS(ulimate_type, is_failable, Optional.of(interface_declaration))»::Encode«IF is_failable»Failable«ENDIF»< «resolve(ulimate_type)», «IF is_failable»«resolveFailableProtobufType(param.paramType, interface_declaration)»«ELSE»«protobuf_type»«ENDIF» >
                           ( «resolveSTL("std::move")»(«param.paramName»), concreteRequest->mutable_«param.paramName.toLowerCase»() );
                     «ELSEIF Util.isEnumType(param.paramType)»
                        concreteRequest->set_«param.paramName.toLowerCase»( «resolveCodecNS(param.paramType)»::Encode(«param.paramName») );
                     «ELSE»
                        «resolveCodecNS(param.paramType)»::Encode( «param.paramName», concreteRequest->mutable_«param.paramName.toLowerCase»() );
                     «ENDIF»
                  «ELSE»
                     concreteRequest->set_«param.paramName.toLowerCase»(«param.paramName»);
                  «ENDIF»
               «ENDFOR»
               // encode request <--
               
               «IF function.returnedType.isVoid»
                  return Request«IF function.isSync»Sync«ELSE»Async«ENDIF»UnmarshalVoid( *request );
               «ELSE»
                  return RequestAsyncUnmarshal< «toText(function.returnedType, interface_declaration)» >( *request, [&]( «resolveCAB("BTC::Commons::Core::UniquePtr")»< «protobuf_response_message» > response )
                  {
                     // decode response -->
                     auto const& concreteResponse( response->«Util.makeProtobufMethodName(function.name, Constants.PROTOBUF_RESPONSE)»() );
                     «val output_parameters = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                     «IF !output_parameters.empty»
                        // handle [out] parameters
                        «FOR param : output_parameters»
                           «IF Util.isSequenceType(param.paramType)»
                              «resolveDecode(param.paramType, interface_declaration)»( concreteResponse.«param.paramName.toLowerCase»(), «param.paramName» );
                           «ELSE»
                              «param.paramName» = «makeDecodeResponse(param.paramType, interface_declaration, param.paramName.toLowerCase)»
                           «ENDIF»
                        «ENDFOR»
                     «ENDIF»
                     return «makeDecodeResponse(function.returnedType, interface_declaration, function.name.toLowerCase)»
                     // decode response <--
                  } )«IF function.isSync».Get()«ENDIF»;
               «ENDIF»
            «ENDIF»
         }
         
      «ENDFOR»
      '''
   }
   
   def private String generateCppDispatcher(InterfaceDeclaration interface_declaration)
   {
      val class_name = resolve(interface_declaration, param_bundle.projectType)
      val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
      val protobuf_request_message = resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
      val protobuf_response_message = resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)
      
      val cab_message_ptr = resolveCAB("BTC::ServiceComm::Commons::MessagePtr")
      
      '''
      «class_name.shortName»::«class_name.shortName»
      (
         «resolveCAB("BTC::Commons::Core::Context")»& context
         ,«resolveCAB("BTC::Logging::API::LoggerFactory")»& loggerFactory
         ,«resolveCAB("BTC::ServiceComm::API::IServerEndpoint")»& serviceEndpoint
         ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «api_class_name» > dispatchee
      ) :
      «resolveCAB("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
      , «interface_declaration.asBaseName»( serviceEndpoint.GetServiceFaultHandlerManagerFactory(), «resolveSTL("std::move")»(dispatchee) )
      { «getRegisterServerFaults(interface_declaration, Optional.of(GeneratorUtil.transform(param_bundle.with(ProjectType.SERVICE_API).with(TransformType.NAMESPACE).build)))»( GetServiceFaultHandlerManager() ); }
      
      «class_name.shortName»::«class_name.shortName»
      (
         «resolveCAB("BTC::Logging::API::LoggerFactory")»& loggerFactory
         ,«resolveCAB("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
         ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «api_class_name» > dispatchee
      ) :
      «resolveCAB("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
      , «interface_declaration.asBaseName»( serviceFaultHandlerManagerFactory, «resolveSTL("std::move")»(dispatchee) )
      { «getRegisterServerFaults(interface_declaration, Optional.of(GeneratorUtil.transform(param_bundle.with(ProjectType.SERVICE_API).with(TransformType.NAMESPACE).build)))»( GetServiceFaultHandlerManager() ); }
      
      «generateCppDestructor(interface_declaration)»
      
      «cab_message_ptr» «class_name.shortName»::ProcessRequest
      (
         «cab_message_ptr» requestBuffer
         , «resolveCAB("BTC::ServiceComm::Commons::CMessage")» const& clientIdentity
      )
      {
         // check whether request has exactly one part (other dispatchers could use more than one part)
         if (requestBuffer->GetNumElements() != 1) 
         {
            «resolveCAB("CABLOG_ERROR")»("Received invalid request (wrong message part count): " << requestBuffer->ToString());
            «resolveCAB("CABTHROW_V2")»( «resolveCAB("BTC::ServiceComm::API::InvalidRequestReceivedException")»( «resolveCAB("BTC::Commons::CoreExtras::StringBuilder")»() 
               << "Expected exactly 1 message part, but received " << requestBuffer->GetNumElements() ) );
         }
         
         // parse raw message into Protocol Buffers message object
         «resolveCAB("BTC::Commons::Core::AutoPtr")»< «protobuf_request_message» > request( BorrowRequestMessage() );
         ParseRequestOrLogAndThrow( «class_name.shortName»::GetLogger(), *request, (*requestBuffer)[0] );
         
         «FOR function : interface_declaration.functions»
         «val protobuf_request_method = Util.makeProtobufMethodName(function.name, Constants.PROTOBUF_REQUEST)»
         «val is_sync = function.isSync»
         «val is_void = function.returnedType.isVoid»
         «val protobuf_response_method = Util.makeProtobufMethodName(function.name, Constants.PROTOBUF_RESPONSE)»
         «val output_parameters = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
         if ( request->has_«protobuf_request_method»() )
         {
            // decode request -->
            auto const& concreteRequest( request->«protobuf_request_method»() );
            «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
               «IF GeneratorUtil.useCodec(param.paramType, param_bundle.artifactNature)»
                  «IF Util.isSequenceType(param.paramType)»
                     «val ulimate_type = Util.getUltimateType(param.paramType)»
                     «val is_uuid = Util.isUUIDType(ulimate_type)»
                     «val is_failable = Util.isFailable(param.paramType)»
                     auto «param.paramName»( «resolveCodecNS(ulimate_type, is_failable, Optional.of(interface_declaration))»::Decode«IF is_failable»Failable«ELSEIF is_uuid»UUID«ENDIF»
                        «IF !is_uuid || is_failable»
                           «val protobuf_type = resolveProtobuf(ulimate_type, ProtobufType.REQUEST).fullyQualifiedName»
                           < «IF is_failable»«resolveFailableProtobufType(param.paramType, interface_declaration)»«ELSE»«protobuf_type»«ENDIF», «resolve(ulimate_type)» >
                        «ENDIF»
                        (concreteRequest.«param.paramName.toLowerCase»()) );
                  «ELSE»
                     auto «param.paramName»( «resolveCodecNS(param.paramType)»::Decode«IF Util.isUUIDType(param.paramType)»UUID«ENDIF»(concreteRequest.«param.paramName.toLowerCase»()) );
                  «ENDIF»
               «ELSE»
                  auto «param.paramName»( concreteRequest.«param.paramName.toLowerCase»() );
               «ENDIF»
            «ENDFOR»
            // decode request <--
            
            «IF !output_parameters.empty»
               // prepare [out] parameters
               «FOR param : output_parameters»
                  «IF Util.isSequenceType(param.paramType)»
                     «val type_name = resolve(Util.getUltimateType(param.paramType))»
                     «val is_failable = Util.isFailable(param.paramType)»
                     «if (is_failable) cab_includes.add("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h").alias("") /* necessary to use InsertableTraits with FailableHandle */»
                     «val effective_typename = if (is_failable) '''«resolveCAB("BTC::Commons::CoreExtras::FailableHandle")»< «type_name» >''' else type_name»
                     «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «effective_typename» >::AutoPtrType «param.paramName»(
                        «resolveCAB("BTC::Commons::FutureUtil::GetOrCreateDefaultInsertable")»(«resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «effective_typename» >::MakeEmptyInsertablePtr()) );
                     auto «param.paramName»Future = «param.paramName»->GetFuture();
                  «ELSE»
                     «toText(param.paramType, param)» «param.paramName»;
                  «ENDIF»
               «ENDFOR»
            «ENDIF»
            
            // call actual method
            «IF !is_void»auto result( «ENDIF»GetDispatchee().«function.name»(«FOR p : function.parameters SEPARATOR ", "»«IF p.direction == ParameterDirection.PARAM_OUT && Util.isSequenceType(p.paramType)»*«ENDIF»«IF p.direction == ParameterDirection.PARAM_IN && Util.isSequenceType(p.paramType)»«resolveSTL("std::move")»(«ENDIF»«p.paramName»«IF p.direction == ParameterDirection.PARAM_IN && Util.isSequenceType(p.paramType)»)«ENDIF»«ENDFOR»)«IF !is_sync».Get()«ENDIF»«IF !is_void» )«ENDIF»;
            
            // prepare response
            «resolveCAB("BTC::Commons::Core::AutoPtr")»< «protobuf_response_message» > response( BorrowReplyMessage() );
            
            «IF !is_void || !output_parameters.empty»
               // encode response -->
               auto * const concreteResponse( response->mutable_«protobuf_response_method»() );
               «IF !is_void»«makeEncodeResponse(function.returnedType, interface_declaration, function.name.toLowerCase, Optional.empty)»«ENDIF»
               «IF !output_parameters.empty»
                  // handle [out] parameters
                  «FOR param : output_parameters»
                     «makeEncodeResponse(param.paramType, interface_declaration, param.paramName.toLowerCase, Optional.of(param.paramName))»
                  «ENDFOR»
               «ENDIF»
               // encode response <--
            «ENDIF»
            
            // send return message
            return «resolveCAB("BTC::ServiceComm::CommonsUtil::MakeSinglePartMessage")»(
                GetMessagePool(), «resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufSupport")»::ProtobufToMessagePart(
                  GetMessagePartPool()
                 ,*response ) );
         }
         «ENDFOR»
         
         «resolveCAB("CABLOG_ERROR")»("Invalid request: " << request->DebugString().c_str());
         «resolveCAB("CABTHROW_V2")»( «resolveCAB("BTC::ServiceComm::API::InvalidRequestReceivedException")»(«resolveCAB("BTC::Commons::Core::String")»("«interface_declaration.name»_Request is invalid, unknown request type")));
      }
      
      void «class_name.shortName»::AttachEndpoint(BTC::ServiceComm::API::IServerEndpoint &endpoint)
      {
         «interface_declaration.asBaseName»::AttachEndpoint( endpoint );
         
         /** Publisher/Subscriber could be attached here to the endpoint
         */
      }

      void «class_name.shortName»::DetachEndpoint(BTC::ServiceComm::API::IServerEndpoint &endpoint)
      {
         /** Publisher/Subscriber could be detached here
         */

         «interface_declaration.asBaseName»::DetachEndpoint(endpoint);
      }

      void «class_name.shortName»::RegisterMessageTypes(«resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")» &decoder)
      {
         «resolveCAB("BTC::ServiceComm::Commons::CMessagePartPool")» pool;
         «resolveCAB("BTC::ServiceComm::Commons::CMessage")» buffer;
         «resolveCAB("BTC::ServiceComm::ProtobufUtil::ExportDescriptors")»< «protobuf_request_message» >(buffer, pool);
         decoder.RegisterMessageTypes( 
            «api_class_name»::TYPE_GUID()
           ,buffer
           ,"«GeneratorUtil.switchSeparator(protobuf_request_message.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»"
           ,"«GeneratorUtil.switchSeparator(protobuf_response_message.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»" );
      }

      «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory")»> «class_name.shortName»::CreateDispatcherAutoRegistrationFactory
      (
         «resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
         , «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &serverEndpoint
         , «resolveCAB("BTC::Commons::CoreExtras::UUID")» const &instanceGuid /*= Commons::CoreExtras::UUID()*/
         , «resolveCAB("BTC::Commons::Core::String")» const &instanceName /*= BTC::Commons::Core::String ()*/
      )
      {
         using «resolveCAB("BTC::ServiceComm::Util::CDispatcherAutoRegistrationFactory")»;
         using «resolveCAB("BTC::ServiceComm::Util::DefaultCreateDispatcherWithContext")»;

         return «resolveCAB("BTC::Commons::Core::CreateUnique")»<CDispatcherAutoRegistrationFactory<«api_class_name», «class_name.shortName»>>
         (
            loggerFactory
            , serverEndpoint
            , instanceGuid
            , «resolveCAB("CABTYPENAME")»(«api_class_name»)
            , instanceName.IsNotEmpty() ? instanceName : («resolveCAB("CABTYPENAME")»(«api_class_name») + " default instance")
         );
      }
      '''
   }
   
   def private String makeEncodeResponse(EObject type, EObject container, String protobuf_name, Optional<String> output_param)
   {
      val api_input = if (output_param.present) output_param.get else "result"
      '''
      «IF GeneratorUtil.useCodec(type, param_bundle.artifactNature) && !(Util.isByte(type) || Util.isInt16(type) || Util.isChar(type))»
         «IF Util.isSequenceType(type)»
            «val ulimate_type = Util.getUltimateType(type)»
            «val is_failable = Util.isFailable(type)»
            «val protobuf_type = resolveProtobuf(ulimate_type, ProtobufType.RESPONSE).fullyQualifiedName»
            «resolveCodecNS(ulimate_type, is_failable, Optional.of(container))»::Encode«IF is_failable»Failable«ENDIF»< «resolve(ulimate_type)», «IF is_failable»«resolveFailableProtobufType(type, container)»«ELSE»«protobuf_type»«ENDIF» >
               ( «resolveSTL("std::move")»(«api_input»«IF output_param.present»Future.Get()«ENDIF»), concreteResponse->mutable_«protobuf_name»() );
         «ELSEIF Util.isEnumType(type)»
            concreteResponse->set_«protobuf_name»( «resolveCodecNS(type)»::Encode(«api_input») );
         «ELSE»
            «resolveCodecNS(type)»::Encode( «api_input», concreteResponse->mutable_«protobuf_name»() );
         «ENDIF»
      «ELSE»
         concreteResponse->set_«protobuf_name»(«api_input»);
      «ENDIF»
      '''
   }
   
   def private String makeDecodeResponse(EObject type, EObject container, String protobuf_name)
   {
      val use_codec = GeneratorUtil.useCodec(type, param_bundle.artifactNature)
      '''«IF use_codec»«resolveDecode(type, container)»( «ENDIF»concreteResponse.«protobuf_name»()«IF use_codec» )«ENDIF»;'''
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
      
      generateHeader(file_content, Optional.of(export_header))
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
      
      // explicitly resolve some *.lib dependencies
      cab_libs.add("BTC.CAB.Commons.CoreExtras.lib") // due to BTC::Commons::CoreExtras::IObserverBase used in dispatcher
      val dispatcher = resolve(interface_declaration, ProjectType.DISPATCHER)
      
      val file_content =
      '''
      «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")»> RegisterMessageTypes()
      {
         auto decoder(«resolveCAB("BTC::Commons::Core::CreateUnique")»<«resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")»>());
         «resolveCAB("BTC::ServiceComm::Default::RegisterBaseMessageTypes")»(*decoder);
         «dispatcher»::RegisterMessageTypes(*decoder);
         return «resolveSTL("std::move")»(decoder);
      }
      
      BOOL WINAPI MyCtrlHandler(_In_  DWORD dwCtrlType)
      {
         ExitProcess(0);
      }
      
      int main(int argc, char *argv[])
      {
      
         SetConsoleCtrlHandler(&MyCtrlHandler, true);
      
         «resolveCAB("BTC::Commons::CoreYacl::Context")» context;
         «resolveCAB("BTC::Commons::Core::BlockStackTraceSettings")» settings(BTC::Commons::Core::BlockStackTraceSettings::BlockStackTraceSettings_OnDefault, BTC::Commons::Core::ConcurrencyScope_Process);
      
         try
         {
            «resolveCAB("BTC::Performance::CommonsTestSupport::GetTestLoggerFactory")»().GetLogger("")->SetLevel(«resolveCAB("BTC::Logging::API::Logger")»::LWarning);
            «resolveCAB("BTC::ServiceComm::PerformanceBase::PerformanceTestServer")» server(context,
               «resolveCAB("BTC::Commons::Core::CreateAuto")»<«resolve(interface_declaration, ProjectType.IMPL)»>(context, «resolveCAB("BTC::Performance::CommonsTestSupport::GetTestLoggerFactory")»()),
               &RegisterMessageTypes,
               «resolveSTL("std::bind")»(&«dispatcher»::CreateDispatcherAutoRegistrationFactory,
               std::placeholders::_1, std::placeholders::_2,
               «resolveCAB("BTC::ServiceComm::PerformanceBase::PerformanceTestServerBase")»::PERFORMANCE_INSTANCE_GUID(),
               «resolveCAB("BTC::Commons::Core::String")»()));
            return server.Run(argc, argv);
         }
         catch («resolveCAB("BTC::Commons::Core::Exception")» const *e)
         {
            «resolveCAB("BTC::Commons::Core::DelException")» _(e);
            context.GetStdOut() << e->ToString();
            return 1;
         }
      }
      '''
      
      '''
      «generateIncludes(false)»
      «file_content»
      '''
   }
   
   def private String generateIncludes(boolean is_header)
   {
      '''
      «FOR module_header : modules_includes.sort»
         #include "«module_header»"
      «ENDFOR»

      «IF is_header && param_bundle.projectType == ProjectType.PROXY»
         // resolve naming conflict between Windows' API function InitiateShutdown and CAB's AServiceProxyBase::InitiateShutdown
         #ifdef InitiateShutdown
         #undef InitiateShutdown
         #endif
         
      «ENDIF»
      «FOR cab_header : cab_includes.sort 
         BEFORE '''#include "modules/Commons/include/BeginCabInclude.h"     // CAB -->''' + System.lineSeparator
         AFTER '''#include "modules/Commons/include/EndCabInclude.h"       // <-- CAB

         '''»
         #include "«cab_header»"
      «ENDFOR»
      «FOR boost_header : boost_includes.sort
         BEFORE '''#include "modules/Commons/include/BeginBoostInclude.h"   // BOOST -->''' + System.lineSeparator
         AFTER '''#include "modules/Commons/include/EndBoostInclude.h"     // <-- BOOST

         '''»
         #include <«boost_header»>
      «ENDFOR»
      «FOR odb_header : odb_includes.sort BEFORE "// ODB" + System.lineSeparator
         AFTER '''

         '''»
         #include <«odb_header»>
      «ENDFOR»
      «FOR stl_header : stl_includes.sort
         BEFORE '''#include "modules/Commons/include/BeginStdInclude.h"     // STD -->''' + System.lineSeparator
         AFTER '''#include "modules/Commons/include/EndStdInclude.h"       // <-- STD

         '''»
         #include <«stl_header»>
      «ENDFOR»
      «IF !is_header && param_bundle.projectType == ProjectType.SERVER_RUNNER»
         
         #ifndef NOMINMAX
         #define NOMINMAX
         #endif
         #include <windows.h>
      «ENDIF»
      '''
   }
   
   def private String generateHFileDispatcher(InterfaceDeclaration interface_declaration)
   {
      val class_name = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)
      
      val cab_message_ptr = resolveCAB("BTC::ServiceComm::Commons::MessagePtr")
      
      '''
      // anonymous namespace for internally used typedef
      namespace
      {
         «makeDispatcherBaseTemplate(interface_declaration)»
      }
      
      class «makeExportMacro()» «class_name» :
      virtual private «resolveCAB("BTC::Logging::API::LoggerAware")»
      , public «interface_declaration.asBaseName»
      {
      public:
         «generateHConstructor(interface_declaration)»
         
         «class_name»
         (
            «resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
            ,«resolveCAB("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
            ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «resolve(interface_declaration)» > dispatchee
         );
         
         «generateHDestructor(interface_declaration)»
         
         /**
            \see BTC::ServiceComm::API::IRequestDispatcher::ProcessRequest
         */
         virtual «cab_message_ptr» ProcessRequest
         (
            «cab_message_ptr» request,
            «resolveCAB("BTC::ServiceComm::Commons::CMessage")» const& clientIdentity
         ) override;
         
         /**
            \see BTC::ServiceComm::API::IRequestDispatcher::AttachEndpoint
         */
         virtual void AttachEndpoint( «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &endpoint ) override;
         
         /**
            \see BTC::ServiceComm::API::IRequestDispatcher::DetachEndpoint
         */
         virtual void DetachEndpoint( «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &endpoint ) override;
         
         static void RegisterMessageTypes( «resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")» &decoder );
         
         // for server runner
         static «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory")»> CreateDispatcherAutoRegistrationFactory
         (
            «resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
            ,«resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &serverEndpoint
            ,«resolveCAB("BTC::Commons::CoreExtras::UUID")» const &instanceGuid = BTC::Commons::CoreExtras::UUID()
            ,«resolveCAB("BTC::Commons::Core::String")» const &instanceName = BTC::Commons::Core::String()
         );
      };
      '''
   }
   
   def private String generateInterface(InterfaceDeclaration interface_declaration)
   {
      // API requires some specific conditions (GUID, pure virtual functions, etc.)
      // non-API also (e.g. override keyword etc.)
      val is_api = param_bundle.projectType == ProjectType.SERVICE_API
      val is_proxy = param_bundle.projectType == ProjectType.PROXY
      val is_impl = param_bundle.projectType == ProjectType.IMPL
      val anonymous_event = Util.getAnonymousEvent(interface_declaration)
      val export_macro = makeExportMacro
      
      val sorted_types = interface_declaration.topologicallySortedTypes
      val forward_declarations = resolveForwardDeclarations(sorted_types)
      
      '''
      «IF is_api»
         «FOR type : forward_declarations»
            struct «Names.plain(type)»;
         «ENDFOR»

         «FOR wrapper : sorted_types»
            «toText(wrapper.type, interface_declaration)»
            
         «ENDFOR»
      «ENDIF»
      «IF is_proxy»
         // anonymous namespace for internally used typedef
         namespace
         {
            typedef «resolveCAB("BTC::ServiceComm::ProtobufBase::AProtobufServiceProxyBaseTemplate")»<
               «resolveProtobuf(interface_declaration, ProtobufType.REQUEST)»
               ,«resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)» > «interface_declaration.asBaseName»;
         }
      «ENDIF»
      «IF !interface_declaration.docComments.empty»
      /**
         «FOR comment : interface_declaration.docComments»«toText(comment, interface_declaration)»«ENDFOR»
      */
      «ENDIF»
      class «export_macro»
      «generateHClassSignature(interface_declaration)»
      {
      public:
         «IF is_api»
            /** \return {«GuidMapper.get(interface_declaration)»} */
            static «resolveCAB("BTC::Commons::CoreExtras::UUID")» TYPE_GUID();
         «ELSE»
            «generateHConstructor(interface_declaration)»
            
            «generateHDestructor(interface_declaration)»
         «ENDIF»
         «FOR function : interface_declaration.functions»
         
         /**
            «IF is_api»
               «FOR comment : function.docComments»«toText(comment, interface_declaration)»«ENDFOR»
               «Util.addNewLine(!function.docComments.empty)»
               «FOR parameter : function.parameters»
               \param[«parameter.direction»] «parameter.paramName» 
               «ENDFOR»
               «Util.addNewLine(!function.parameters.empty)»
               «FOR exception : function.raisedExceptions»
               \throw «toText(exception, function)»
               «ENDFOR»
               «Util.addNewLine(!function.raisedExceptions.empty)»
               «IF !(function.returnedType as ReturnTypeElement).isVoid»\return «ENDIF»
            «ELSE»
               \see «resolve(interface_declaration, ProjectType.SERVICE_API)»::«function.name»
            «ENDIF»
         */
         virtual «IF !function.isSync»«resolveCAB("BTC::Commons::CoreExtras::Future")»<«ENDIF»«toText(function.returnedType, interface_declaration)»«IF !function.isSync»>«ENDIF» «function.name»(«generateParameters(function)»)«IF function.isQuery» const«ENDIF»«IF is_api» = 0«ELSE» override«ENDIF»;
         «ENDFOR»
         «IF is_proxy»
            
            using «interface_declaration.asBaseName»::InitiateShutdown;
            
            using «interface_declaration.asBaseName»::Wait;
            
         «ENDIF»
         «FOR event : interface_declaration.events.filter[name !== null]»
            «val event_type = toText(event.data, event)»
            /**
               \brief Subscribe for event of type «event_type»
            */
            virtual «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::Commons::Core::Disposable")»> Subscribe( «resolveCAB("BTC::Commons::CoreExtras::IObserver")»<«event_type»> &observer )«IF is_api» = 0«ENDIF»;
         «ENDFOR»
         
         «IF !is_api»
            «IF anonymous_event !== null»
               /**
                  \see BTC::Commons::CoreExtras::IObservableRegistration::Subscribe
               */
               virtual «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::Commons::Core::Disposable")»> Subscribe( «resolveCAB("BTC::Commons::CoreExtras::IObserver")»<«toText(anonymous_event.data, anonymous_event)»> &observer ) override;
            «ENDIF»
            private:
               «resolveCAB("BTC::Commons::Core::Context")» &m_context;
            «IF is_proxy»
               «FOR event : interface_declaration.events»
                  «var event_params_name = event.eventParamsName»
                  struct «event_params_name»
                  {
                     typedef «resolve(event.data)» EventDataType;
                     
                     static «resolveCAB("BTC::Commons::CoreExtras::UUID")» GetEventTypeGuid();
                     static «resolveCAB("BTC::ServiceComm::API::EventKind")» GetEventKind();
                     static «resolveCAB("BTC::Commons::Core::String")» GetEventTypeDescription();
                     static «resolveSTL("std::function")»<EventDataType const ( «resolveCAB("BTC::ServiceComm::Commons::ConstSharedMessageSharedPtr")» const & )> GetUnmarshalFunction();
                  };
                  «resolveCAB("BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy")»<«event_params_name»> «event.observableRegistrationName»;
               «ENDFOR»
            «ENDIF»
            «IF is_impl»
               «FOR event : interface_declaration.events»
                  «resolveCAB("BTC::Commons::CoreExtras::CDefaultObservable")»<«resolve(event.data)»> «event.observableName»;
               «ENDFOR»
            «ENDIF»
         «ENDIF»
      };
      «IF is_api»
         void «export_macro»
         «getRegisterServerFaults(interface_declaration, Optional.empty)»(«resolveCAB("BTC::ServiceComm::API::IServiceFaultHandlerManager")»& serviceFaultHandlerManager);
      «ENDIF»
      '''
   }
   
   def private String generateHClassSignature(InterfaceDeclaration interface_declaration)
   {
      val is_api = param_bundle.projectType == ProjectType.SERVICE_API
      val is_proxy = param_bundle.projectType == ProjectType.PROXY
      val anonymous_event = Util.getAnonymousEvent(interface_declaration)
      
      '''«GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)» : 
      «IF is_api»
         virtual public «resolveCAB("BTC::Commons::Core::Object")»
         «IF anonymous_event !== null», public «resolveCAB("BTC::Commons::CoreExtras::IObservableRegistration")»<«resolve(anonymous_event.data)»>«ENDIF»
      «ELSE»
         virtual public «resolve(interface_declaration, ProjectType.SERVICE_API)»
         , private «resolveCAB("BTC::Logging::API::LoggerAware")»
      «ENDIF»
      «IF is_proxy»
         , private «interface_declaration.asBaseName»
      «ENDIF»
      '''
   }
   
   def private String generateHConstructor(InterfaceDeclaration interface_declaration)
   {
      val class_name = resolve(interface_declaration, param_bundle.projectType)
      
      '''
      /**
         \brief Object constructor
      */
      «class_name.shortName»
      (
         «resolveCAB("BTC::Commons::Core::Context")» &context
         ,«resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
         «IF param_bundle.projectType == ProjectType.PROXY»
            ,«resolveCAB("BTC::ServiceComm::API::IClientEndpoint")» &localEndpoint
            ,«resolveCAB("BTC::Commons::CoreExtras::Optional")»<«resolveCAB("BTC::Commons::CoreExtras::UUID")»> const &serverServiceInstanceGuid 
               = «resolveCAB("BTC::Commons::CoreExtras::Optional")»<«resolveCAB("BTC::Commons::CoreExtras::UUID")»>()
         «ELSEIF param_bundle.projectType == ProjectType.DISPATCHER»
            ,«resolveCAB("BTC::ServiceComm::API::IServerEndpoint")»& serviceEndpoint
            ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «resolve(interface_declaration, ProjectType.SERVICE_API)» > dispatchee
         «ENDIF»
      );
      '''
   }
   
   def private String generateParameters(FunctionDeclaration function)
   {
      '''«FOR parameter : function.parameters SEPARATOR ", "»«toText(parameter, function)»«ENDFOR»'''
   }
   
   def private dispatch String toText(ParameterElement item, EObject context)
   {
      val is_sequence = Util.isSequenceType(item.paramType)
      if (is_sequence)
         '''«toText(item.paramType, context.eContainer)» «IF item.direction == ParameterDirection.PARAM_OUT»&«ENDIF»«item.paramName»'''
      else
         '''«toText(item.paramType, context.eContainer)»«IF item.direction == ParameterDirection.PARAM_IN» const«ENDIF» &«item.paramName»'''
   }
   
   def private dispatch String toText(ReturnTypeElement return_type, EObject context)
   {
      if (return_type.isVoid)
         return "void"

      throw new IllegalArgumentException("Unknown ReturnTypeElement: " + return_type.class.toString)
   }
   
   def private dispatch String toText(AbstractType item, EObject context)
   {
      if (item.primitiveType !== null)
         return toText(item.primitiveType, item)
      else if (item.referenceType !== null)
         return toText(item.referenceType, item)
      else if (item.collectionType !== null)
         return toText(item.collectionType, item)
      
      throw new IllegalArgumentException("Unknown AbstractType: " + item.class.toString)
   }
   
   def private dispatch String toText(AliasDeclaration item, EObject context)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
         '''typedef «toText(item.type, context)» «item.name»;'''
      else
         '''«resolve(item)»'''
   }
   
   def private dispatch String toText(EnumDeclaration item, EObject context)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
      '''
      enum class «item.name»
      {
         «FOR enum_value : item.containedIdentifiers»
            «enum_value»«IF enum_value != item.containedIdentifiers.last»,«ENDIF»
         «ENDFOR»
      }«IF item.declarator !== null» «item.declarator»«ENDIF»;
      '''
      else
         '''«resolve(item)»'''
   }
   
   def private dispatch String toText(StructDeclaration item, EObject context)
   {
      
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
      {
         val related_event =  Util.getRelatedEvent(item, idl)
         var makeCompareOperator = false
         for (member :item.members)
         {
            if (member.name == "Id" && member.type.primitiveType !== null && member.type.primitiveType.uuidType !== null)
               makeCompareOperator = true
         }
         
         '''
         struct «makeExportMacro()» «item.name»«IF item.supertype !== null» : «resolve(item.supertype)»«ENDIF»
         {
            «FOR type_declaration : item.typeDecls»
               «toText(type_declaration, item)»
            «ENDFOR»
            «FOR member : item.members»
               «val is_pointer = useSmartPointer(item, member.type)»
               «val is_optional = member.isOptional»
               «IF is_optional && !is_pointer»«resolveCAB("BTC::Commons::CoreExtras::Optional")»< «ENDIF»«IF is_pointer»«resolveSTL("std::shared_ptr")»< «ENDIF»«toText(member.type, item)»«IF is_pointer» >«ENDIF»«IF is_optional && !is_pointer» >«ENDIF» «member.name.asMember»;
            «ENDFOR»
            
            «IF related_event !== null»
               /** \return {«GuidMapper.get(related_event)»} */
               static «resolveCAB("BTC::Commons::CoreExtras::UUID")» EVENT_TYPE_GUID();
               
            «ENDIF»
            
            «IF makeCompareOperator»
               bool operator==( «item.name» const &other ) const
                  {   return id == other.id; }
            «ENDIF»
         }«IF item.declarator !== null» «item.declarator»«ENDIF»;
         '''
      }
      else
         '''«resolve(item)»'''
   }
   
   def private dispatch String toText(ExceptionReferenceDeclaration item, EObject context)
   {
      if (context instanceof FunctionDeclaration) '''«Names.plain(item)»'''
   }
   
   def private dispatch String toText(ExceptionDeclaration item, EObject context)
   {
      '''
      «IF (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)»
         «IF item.members.empty»
            «resolveCAB("CAB_SIMPLE_EXCEPTION_DEFINITION")»( «item.name», «IF item.supertype !== null»«resolve(item.supertype)»«ELSE»«resolveCAB("BTC::Commons::Core::Exception")»«ENDIF», «makeExportMacro()» )
         «ELSE»
            «val class_name = item.name»
            «val base_class_name = makeBaseExceptionType(item)»
            // based on CAB macro CAB_SIMPLE_EXCEPTION_DEFINITION_EX from Exception.h
            struct «makeExportMacro» «class_name» : public virtual «base_class_name»
            {
               typedef «base_class_name» BASE;
               
               «class_name»();
               explicit «class_name»(«resolveCAB("BTC::Commons::Core::String")» const &msg);
               «class_name»( «FOR member : item.members SEPARATOR ", "»«toText(member.type, item)» const& «member.name.asMember»«ENDFOR» );
               
               virtual ~«class_name»();
               virtual void Throw() const;
               virtual void Throw();
               
               «FOR member : item.members»
                  «toText(member.type, item)» «member.name.asMember»;
               «ENDFOR»
               
               protected:
                  virtual «resolveCAB("BTC::Commons::Core::Exception")» *IntClone() const;
            };
         «ENDIF»
      «ELSE»«resolve(item)»«ENDIF»
      '''
   }
   
   def private dispatch String toText(PrimitiveType item, EObject context)
   {
      if (item.integerType !== null)
      {
         switch item.integerType
         {
         case "int64":
            return resolveSTL("int64_t")
         case "int32":
            return resolveSTL("int32_t")
         case "int16":
            return resolveSTL("int16_t")
         case "byte":
            return resolveSTL("int8_t")
         default:
            return item.integerType
         }
      }
      else if (item.stringType !== null)
         return resolveSTL("std::string")
      else if (item.floatingPointType !== null)
         return item.floatingPointType
      else if (item.uuidType !== null)
         return resolveCAB("BTC::Commons::CoreExtras::UUID")
      else if (item.booleanType !== null)
         return "bool"
      else if (item.charType !== null)
         return "char"

      throw new IllegalArgumentException("Unknown PrimitiveType: " + item.class.toString)
   }
   
   def private dispatch String toText(SequenceDeclaration item, EObject context)
   {
      val inner_type = '''«IF item.failable»«resolveCAB("BTC::Commons::CoreExtras::FailableHandle")»< «ENDIF»«toText(item.type, item)»«IF item.failable» >«ENDIF»'''
      
      if (item.isOutputParameter)
         '''«resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «inner_type» >::Type'''
      else if (context.eContainer instanceof MemberElement)
         '''«resolveSTL("std::vector")»< «inner_type» >'''
      else
         '''«resolveCAB("BTC::Commons::Core::ForwardConstIterator")»< «inner_type» >'''
   }
   
   def private dispatch String toText(TupleDeclaration item, EObject context)
   {
      '''«resolveSTL("std::tuple")»<«FOR type : item.types»«toText(type, item)»«IF type != item.types.last», «ENDIF»«ENDFOR»>'''
   }
   
   def private dispatch String toText(EventDeclaration item, EObject context)
   {
      '''«toText(item.data, item)»'''
   }
   
   def private dispatch String toText(DocCommentElement item, EObject context)
   {
      return Util.getPlainText(item)
   }
   
   def private dispatch String toText(ModuleDeclaration item, EObject context)
   {
      return Names.plain(item)
   }

   def private dispatch String toText(InterfaceDeclaration item, EObject context)
   {
      return Names.plain(item)
   }
   
   def private String makeExportMacro()
   {
      return GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build).toUpperCase
                         + Constants.SEPARATOR_CPP_HEADER + "EXPORT"
   }
 
   def private String resolveCAB(String class_name)
   {
      val header = HeaderResolver.getCABHeader(class_name)
      cab_includes.add(header)
      cab_libs.addAll(LibResolver.getCABLibs(header))
      return class_name
   }

   def private String resolveCABImpl(String class_name)
   {
      val header = HeaderResolver.getCABImpl(class_name)
      cab_includes.add(header)
      cab_libs.addAll(LibResolver.getCABLibs(header))
      return class_name
   }

   def private String resolveSTL(String class_name)
   {
      stl_includes.add(HeaderResolver.getSTLHeader(class_name))
      return class_name
   }

   def private String resolveBoost(String class_name)
   {
      boost_includes.add(HeaderResolver.getBoostHeader(class_name))
      return class_name
   }

   def private String resolveODB(String class_name)
   {
      odb_includes.add(HeaderResolver.getODBHeader(class_name))
      return class_name
   }

   def private String resolveModules(String class_name)
   {
      modules_includes.add(HeaderResolver.getModulesHeader(class_name))
      val project_reference = ReferenceResolver.getProjectReference(class_name)
      vs_projects.put(project_reference.project_name, UUID.fromString(project_reference.project_guid))
      project_references.put(project_reference.project_name, project_reference.project_path)
      return class_name
   }

   def private ResolvedName resolve(EObject object)
   {
      return resolve(object, object.mainProjectType)
   }

   def private ResolvedName resolve(EObject object, ProjectType project_type)
   {
      if (Util.isUUIDType(object))
      {
         if (project_type == ProjectType.PROTOBUF)
            return new ResolvedName(resolveSTL("std::string"), TransformType.NAMESPACE)
         else
            return new ResolvedName("BTC::Commons::CoreExtras::UUID", TransformType.NAMESPACE)
      }
      else if (object instanceof PrimitiveType)
         return new ResolvedName(toText(object, object), TransformType.NAMESPACE)
      else if (object instanceof AbstractType && (object as AbstractType).primitiveType !== null)
         return resolve((object as AbstractType).primitiveType, project_type)

      val qualified_name = qualified_name_provider.getFullyQualifiedName(object)
      if (qualified_name === null)
         return new ResolvedName(Names.plain(object), TransformType.NAMESPACE)
      
      val resolved_name = qualified_name.toString
      if (HeaderResolver.isCAB(resolved_name))
         resolveCAB(GeneratorUtil.switchPackageSeperator(resolved_name, TransformType.NAMESPACE))
      else if (HeaderResolver.isBoost(resolved_name))
         resolveBoost(GeneratorUtil.switchPackageSeperator(resolved_name, TransformType.NAMESPACE))
      else
      {
         var result = GeneratorUtil.transform(ParameterBundle.createBuilder(Util.getModuleStack(Util.getScopeDeterminant(object))).with(project_type).with(TransformType.NAMESPACE).build)
         result += Constants.SEPARATOR_NAMESPACE + if (object instanceof InterfaceDeclaration) project_type.getClassName(param_bundle.artifactNature, qualified_name.lastSegment) else qualified_name.lastSegment
         modules_includes.add(object.getIncludeFilePath(project_type))
         object.resolveProjectFilePath(project_type)
         return new ResolvedName(result, TransformType.NAMESPACE)
      }

      return new ResolvedName(qualified_name, TransformType.NAMESPACE)
   }
   
   def private ResolvedName resolveProtobuf(EObject object, ProtobufType protobuf_type)
   {
      if (Util.isUUIDType(object))
         return new ResolvedName(resolveSTL("std::string"), TransformType.NAMESPACE)
      else if (Util.isInt16(object) || Util.isByte(object) || Util.isChar(object))
         return new ResolvedName("::google::protobuf::int32", TransformType.NAMESPACE)
      else if (object instanceof PrimitiveType)
         return new ResolvedName(toText(object, object), TransformType.NAMESPACE)
      else if (object instanceof AbstractType && (object as AbstractType).primitiveType !== null)
         return resolveProtobuf((object as AbstractType).primitiveType, protobuf_type)

      val is_function = (object instanceof FunctionDeclaration)
      val is_interface = (object instanceof InterfaceDeclaration)
      val scope_determinant = Util.getScopeDeterminant(object)

      val builder = ParameterBundle.createBuilder(Util.getModuleStack(scope_determinant))
      builder.reset(ProjectType.PROTOBUF)

      var result = GeneratorUtil.transform(builder.with(TransformType.NAMESPACE).build)
      result += Constants.SEPARATOR_NAMESPACE
      if (is_interface)
         result += Names.plain(object) + "_" + protobuf_type.getName
      else if (is_function)
         result += Names.plain(scope_determinant) + "_" + protobuf_type.getName + "_" + Names.plain(object) + "_" + protobuf_type.getName
      else
         result += Names.plain(object)
      
      var header_path = GeneratorUtil.transform(builder.with(TransformType.FILE_SYSTEM).build)
      var header_file = GeneratorUtil.getPbFileName(object)
      modules_includes.add("modules/" + header_path + "/gen/" + header_file.pb.h)
      object.resolveProjectFilePath(ProjectType.PROTOBUF)
      return new ResolvedName(result, TransformType.NAMESPACE)
   }
   
   def private void resolveProjectFilePath(EObject referenced_object, ProjectType project_type)
   {
      val module_stack = Util.getModuleStack(referenced_object)
      
      val temp_param = new ParameterBundle.Builder()
      temp_param.reset(param_bundle.artifactNature)
      temp_param.reset(module_stack)
      temp_param.reset(project_type)
      
      val project_name = getVcxprojName(temp_param, Optional.empty)
      val project_path = '''$(SolutionDir)\«GeneratorUtil.transform(temp_param.with(TransformType.FILE_SYSTEM).build).replace(Constants.SEPARATOR_FILE, Constants.SEPARATOR_BACKSLASH)»\«project_name»'''
      project_references.put(project_name, project_path)
   }
   
   def private String resolveCodecNS(EObject object)
   {
      resolveCodecNS(object, false, Optional.empty)
   }
   
   def private String resolveCodecNS(EObject object, boolean is_failable, Optional<EObject> container)
   {
      val ultimate_type = Util.getUltimateType(object)
      
      val temp_param = new ParameterBundle.Builder
      temp_param.reset(param_bundle.artifactNature)
      temp_param.reset( if (is_failable) param_bundle.moduleStack else Util.getModuleStack(ultimate_type) ) // failable wrappers always local!
      temp_param.reset(ProjectType.PROTOBUF)
      
      val codec_name = if (is_failable) GeneratorUtil.getCodecName(container.get) else GeneratorUtil.getCodecName(ultimate_type)
      
      var header_path = GeneratorUtil.transform(temp_param.with(TransformType.FILE_SYSTEM).build)
      modules_includes.add("modules/" + header_path + "/include/" + codec_name.h)
      resolveProjectFilePath(ultimate_type, ProjectType.PROTOBUF)
      
      GeneratorUtil.transform(temp_param.with(TransformType.NAMESPACE).build) + TransformType.NAMESPACE.separator + codec_name
   }
   
   def private String getVcxprojName(ParameterBundle.Builder builder, Optional<String> extra_name)
   {
      var project_name = GeneratorUtil.transform(builder.with(TransformType.PACKAGE).build)
      getVcxprojGUID(project_name)
      return project_name
   }
   
   def private String getVcxprojGUID(String project_name)
   {
      var UUID guid
      if (vs_projects.containsKey(project_name))
         guid = vs_projects.get(project_name)
      else
      {
         guid = UUID.nameUUIDFromBytes(project_name.bytes)
         vs_projects.put(project_name, guid)
      }
      return guid.toString.toUpperCase
   }

   def private String makeDispatcherBaseTemplate(InterfaceDeclaration interface_declaration)
   {
      val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
      val protobuf_request = resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
      val protobuf_response = resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)
      
      '''
      typedef «resolveCAB("BTC::ServiceComm::ProtobufBase::AProtobufServiceDispatcherBaseTemplate")»<
         «api_class_name»
         , «protobuf_request»
         , «protobuf_response» > «interface_declaration.asBaseName»;
      '''
   }
   
   def private static String getRegisterServerFaults(InterfaceDeclaration interface_declaration, Optional<String> namespace)
   {
      '''«IF namespace.present»«namespace.get»::«ENDIF»Register«interface_declaration.name»ServiceFaults'''
   }
   
   def private static String getObservableName(EventDeclaration event)
   {
      var basic_name = event.name ?: ""
      basic_name += "Observable"
      '''m_«basic_name.asMember»'''
   }
   
   def private static String getObservableRegistrationName(EventDeclaration event)
   {
      event.observableName + "Registration"
   }
   
   def private static String getEventParamsName(EventDeclaration event)
   {
      (event.name ?: "") + "EventParams"
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
   
   def private String makeBaseExceptionType(ExceptionDeclaration exception)
   {
      '''«IF exception.supertype === null»«resolveCAB("BTC::Commons::Core::Exception")»«ELSE»«resolve(exception.supertype)»«ENDIF»'''
   }
   
   def private dispatch String resolveODBType(AbstractType element)
   {
      if (element.primitiveType !== null)
         return resolveODBType(element.primitiveType)
      else if (element.referenceType !== null)
         return resolveODBType(element.referenceType)
      else if (element.collectionType !== null)
         return resolveODBType(element.collectionType)
      
      throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
   }
   
   def private dispatch String resolveODBType(PrimitiveType element)
   {
      if (element.integerType !== null)
      {
         switch element.integerType
         {
         case "int64":
            return "long"
         case "int32":
            return "int"
         case "int16":
            return "short"
         case "byte":
            return "signed char"
         default:
            return element.integerType
         }
      }
      else if (element.stringType !== null)
         return resolveSTL("std::string")
      else if (element.floatingPointType !== null)
         return element.floatingPointType
      else if (element.uuidType !== null)
         return resolveModules("BTC::PRINS::Commons::GUID")
      else if (element.booleanType !== null)
         return "bool"
      else if (element.charType !== null)
         return "char"

      throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
   }
   
   def private dispatch String resolveODBType(StructDeclaration element)
   {
      element.name
   }
   
   def private dispatch String resolveODBType(AliasDeclaration element)
   {
      resolveODBType(element.type)
   }
   
   def private dispatch String resolveODBType(SequenceDeclaration element)
   {
      '''«resolveSTL("std::vector")»<«resolveODBType(Util.getUltimateType(element))»>'''
   }
   
   def private dispatch String resolveODBType(EnumDeclaration element)
   {
      return "int"
   }
   
   /**
    * For a given element, check if another type (as member of this element)
    * must be represented as smart pointer + forward declaration, or as-is.
    */
   def private boolean useSmartPointer(EObject element, EObject other_type)
   {
      // sequences use forward-declared types as template parameters
      // and do not need the smart pointer wrapping
      if (Util.isSequenceType(other_type))
         return false;
       
      val dependencies = smart_pointer_map.get(element)
      if (dependencies !== null)
         return dependencies.contains(Util.getUltimateType(other_type))
      else
         return false
   }
   
   /**
    * Make a C++ member variable name according to BTC naming conventions
    * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
    */
   def private static String asMember(String name)
   {
      if (name.allUpperCase)
         name.toLowerCase     // it looks better, if ID --> id and not ID --> iD
      else
         name.toFirstLower
   }
   
   /**
    * Make a C++ parameter name according to BTC naming conventions
    * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
    */
   def private static String asParameter(String name)
   {
      asMember(name) // currently the same convention
   }
   
   def private List<EObject> resolveForwardDeclarations(Collection<TypeWrapper> sorted_types)
   {
      val forward_declarations = sorted_types
         .filter[!forwardDeclarations.empty]
         .map[forwardDeclarations]
         .flatten
         .toList
         .stream
         .distinct
         .collect(Collectors.toList)
      
      for (wrapper : sorted_types)
      {
         var dependencies = smart_pointer_map.get(wrapper.type)
         if (dependencies === null)
         {
            dependencies = new LinkedHashSet<EObject>
            smart_pointer_map.put(wrapper.type, dependencies)
         }
         dependencies.addAll(wrapper.forwardDeclarations)
      }
      
      return forward_declarations
   }
   
   def private boolean isMutableField(EObject type)
   {
      val ultimate_type = Util.getUltimateType(type)
      // TODO isn't param_bundle.artifactNature always CPP here? Then the method could be made static
      val use_codec = GeneratorUtil.useCodec(ultimate_type, param_bundle.artifactNature)
      val is_enum = Util.isEnumType(ultimate_type)

      return ( use_codec && !(Util.isByte(ultimate_type) || Util.isInt16(ultimate_type) || Util.isChar(ultimate_type) || is_enum) )
   }
   
   def private static String asBaseName(InterfaceDeclaration interface_declaration)
   {
      '''«interface_declaration.name»Base'''
   }
}
