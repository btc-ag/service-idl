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
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
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
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.google.common.collect.Sets
import java.util.Arrays
import java.util.Calendar
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.Set
import java.util.UUID
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

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
      cs_files.add(dispatcher_class_name)
      file_system_access.generateFile(
         src_root_path + dispatcher_class_name.cs,
         generateSourceFile(new DispatcherGenerator(basicCSharpSourceGenerator).generate(dispatcher_class_name, interface_declaration).toString)
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
      
      new ProtobufCodecGenerator(basicCSharpSourceGenerator).generate(owner, class_name).toString
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
      new TestGenerator(basicCSharpSourceGenerator).generateCsTest(interface_declaration, class_name).toString
   }
   
   def private String generateCsServerRegistration(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile

      new ServerRegistrationGenerator(basicCSharpSourceGenerator).generate(interface_declaration, class_name).toString      
   }

   def private String generateCsZeroMQIntegrationTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      new TestGenerator(basicCSharpSourceGenerator).generateIntegrationTest(interface_declaration, class_name).toString      
   }

   def private String generateCsImplTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      new TestGenerator(basicCSharpSourceGenerator).generateImplTestStub(interface_declaration, class_name).toString      
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
         file_system_access.generateFile(project_root_path + file_name.cs, generateSourceFile(new ProxyEventGenerator(basicCSharpSourceGenerator).generateProxyEvent(event, interface_declaration)))
      }
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
      
      new ProxyGenerator(basicCSharpSourceGenerator).generate(class_name, interface_declaration).toString
   }
   
   def private String generateProxyData(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      new ProxyDataGenerator(basicCSharpSourceGenerator).generate(interface_declaration).toString
   }
   
   def private String generateProxyProtocol(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile

      new ProxyProtocolGenerator(basicCSharpSourceGenerator).generate(class_name, interface_declaration).toString      
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
         file_system_access.generateFile(project_root_path + file_name.cs, 
             generateSourceFile(new ServiceAPIGenerator(basicCSharpSourceGenerator).generate(interface_declaration, abstract_type).toString
         ))
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
          new ServiceAPIGenerator(basicCSharpSourceGenerator).generateConstants(interface_declaration, file_name).toString
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
      
      new ServiceAPIGenerator(basicCSharpSourceGenerator).generateEvent(event).toString
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
      
   def private String getProjectRootPath()
   {
      param_bundle.artifactNature.label
         + Constants.SEPARATOR_FILE
         + GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build)
         + Constants.SEPARATOR_FILE
   }
   
   def private String getLog4NetConfigFile()
   {
      param_bundle.log4NetConfigFile
   }
         
   def private String makeDefaultValue(EObject element)
   {
      basicCSharpSourceGenerator.makeDefaultValue(element)
   }

   def private String makeReturnType(FunctionDeclaration function)
   {
      typeResolver.makeReturnType(function)
   }
}
