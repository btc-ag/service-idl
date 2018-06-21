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

import com.btc.serviceidl.generator.IGenerationSettingsProvider
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
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.google.common.collect.Sets
import java.util.Arrays
import java.util.HashMap
import java.util.HashSet
import java.util.Set
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
   public static val DOTNET_FRAMEWORK_VERSION = DotNetFrameworkVersion.NET46
   
   // global variables
   private var Resource resource
   private var IFileSystemAccess file_system_access
   private var IQualifiedNameProvider qualified_name_provider
   private var IScopeProvider scope_provider
   var IGenerationSettingsProvider generationSettingsProvider
   private var IDLSpecification idl
   
   private var param_bundle = new ParameterBundle.Builder()
   
   val typedef_table = new HashMap<String, String>
   val namespace_references = new HashSet<String>
   val failableAliases = new HashSet<FailableAlias>
   val referenced_assemblies = new HashSet<String>
   private var nuget_packages = new NuGetPackageResolver
   val project_references = new HashMap<String, String>
   val vsSolution = new VSSolution
   val cs_files = new HashSet<String>
   val protobuf_files = new HashSet<String>
   private var protobuf_project_references = new HashMap<String, HashMap<String, String>>
   private var extension TypeResolver typeResolver
   private var extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
    
   val paketDependencies = new HashSet<Pair<String, String>>
    
   
   def public void doGenerate(Resource res, IFileSystemAccess fsa, IQualifiedNameProvider qnp, IScopeProvider sp, IGenerationSettingsProvider generationSettingsProvider, Set<ProjectType> projectTypes, HashMap<String, HashMap<String, String>> pr)
   {
      resource = res
      file_system_access = fsa
      qualified_name_provider = qnp
      scope_provider = sp
      this.generationSettingsProvider = generationSettingsProvider
      protobuf_project_references = pr
      
      idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
            
      // iterate module by module and generate included content
      for (module : idl.modules)
      {
         processModule(module, projectTypes)
      }
      
      new VSSolutionGenerator(fsa, vsSolution, resource.URI.lastSegment.replace(".idl", "")).generateSolutionFile
      
      // TODO generate only either NuGet or Paket file
      file_system_access.generateFile("paket.dependencies", ArtifactNature.DOTNET.label,
            generatePaketDependencies)       
      
   }
   
   private def void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {
      param_bundle = ParameterBundle.createBuilder(com.btc.serviceidl.util.Util.getModuleStack(module))
      
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
   
   private def void generateInterfaceProjects(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        Sets.intersection(projectTypes, new HashSet<ProjectType>(Arrays.asList(
            ProjectType.SERVICE_API,
            ProjectType.IMPL,
            ProjectType.PROXY,
            ProjectType.DISPATCHER,
            ProjectType.TEST
        ))).forEach[generateProjectStructure(it, module)]
   }
   
   private def void generateProjectStructure(ProjectType project_type, ModuleDeclaration module)
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
   
   private def void generateProject(ProjectType project_type, InterfaceDeclaration interface_declaration, String project_root_path)
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
   
   private def void generateCommon(ModuleDeclaration module)
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
      generateProjectSourceFile(project_root_path, common_file_name, file_content)
      
      generateVSProjectFiles(project_root_path)
   }
   
   private def void generateVSProjectFiles(String project_root_path)
   {
      val project_name = vsSolution.getCsprojName(param_bundle.build)
      
      // generate project file
      file_system_access.generateFile(project_root_path + Constants.SEPARATOR_FILE + project_name.csproj, ArtifactNature.DOTNET.label, generateCsproj(cs_files))
      
      // generate mandatory AssemblyInfo.cs file
      file_system_access.generateFile(project_root_path + Constants.SEPARATOR_FILE + "Properties" + Constants.SEPARATOR_FILE + "AssemblyInfo.cs", ArtifactNature.DOTNET.label, generateAssemblyInfo(project_name))   
   
      // NuGet (optional)
      if (!nuget_packages.resolvedPackages.empty)
      {
        file_system_access.generateFile(project_root_path + Constants.SEPARATOR_FILE + "packages.config", ArtifactNature.DOTNET.label, 
                generatePackagesConfig)
        // TODO generate only either NuGet or Paket file
        file_system_access.generateFile(project_root_path + Constants.SEPARATOR_FILE + "paket.references", ArtifactNature.DOTNET.label, 
                generatePaketReferences)
        paketDependencies.addAll(flatPackages)
      }
   }
   
   private def getFlatPackages()
   {
      nuget_packages.resolvedPackages.map[it.packageVersions].flatten
   } 
   
   private def String generatePackagesConfig()
   {
      '''
      <?xml version="1.0" encoding="utf-8"?>
      <packages>
        «FOR packageEntry : flatPackages»
          <package id="«packageEntry.key»" version="«packageEntry.value»" targetFramework="«DOTNET_FRAMEWORK_VERSION.toString.toLowerCase»" />
        «ENDFOR»
      </packages>
      '''
   }
   
   private def String generatePaketReferences()
   {
      '''      
      «FOR packageEntry : flatPackages»
          «packageEntry.key»
      «ENDFOR»
      '''
   }
   
   private def String generatePaketDependencies()
   {
      // TODO shouldn't the sources (at least extern) be configured somewhere else?
      if (!paketDependencies.empty) {
          '''
          source https://artifactory.bop-dev.de/artifactory/api/nuget/cab-nuget-extern
          source https://artifactory.bop-dev.de/artifactory/api/nuget/cab-nuget-stable
          
          «FOR packageEntry : paketDependencies»
              «/** TODO remove this workaround */»
              «IF packageEntry.key.equals("Common.Logging")»
                nuget «packageEntry.key» == «packageEntry.value» restriction: >= «DOTNET_FRAMEWORK_VERSION.toString.toLowerCase»
              «ELSE»
                nuget «packageEntry.key» >= «packageEntry.value» restriction: >= «DOTNET_FRAMEWORK_VERSION.toString.toLowerCase»
              «ENDIF»
          «ENDFOR»      
          '''
      }     
   }
   
   private def generateAssemblyInfo(String project_name)
   {
       new AssemblyInfoGenerator(param_bundle.build).generate(project_name)
   }
   
   private def void reinitializeFile()
   {
      namespace_references.clear
      failableAliases.clear
   }
   
   private def void reinitializeProject(ProjectType project_type)
   {
      reinitializeFile
      param_bundle.reset(project_type)
      referenced_assemblies.clear
      project_references.clear
      protobuf_files.clear
      nuget_packages = new NuGetPackageResolver
      cs_files.clear
      
      typeResolver = new TypeResolver(
            DOTNET_FRAMEWORK_VERSION,
            qualified_name_provider,
            namespace_references,
            failableAliases,
            referenced_assemblies,
            project_references,
            nuget_packages,
            vsSolution,
            param_bundle.build
        )
      basicCSharpSourceGenerator = new BasicCSharpSourceGenerator(typeResolver, generationSettingsProvider, typedef_table, idl)      
   }
   
   private def void generateImpl(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val impl_class_name = GeneratorUtil.getClassName(ArtifactNature.DOTNET, param_bundle.projectType, interface_declaration.name)
      generateProjectSourceFile(
        src_root_path,
        impl_class_name,
        new ImplementationStubGenerator(basicCSharpSourceGenerator).generate(interface_declaration, impl_class_name)
      )      
   }
   
   private def void generateDispatcher(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile

      val dispatcher_class_name = GeneratorUtil.getClassName(ArtifactNature.DOTNET, param_bundle.projectType, interface_declaration.name)
      generateProjectSourceFile(
        src_root_path,
        dispatcher_class_name,
        new DispatcherGenerator(basicCSharpSourceGenerator).generate(dispatcher_class_name, interface_declaration)
      )
   }
   
   private def void generateProtobuf(ModuleDeclaration module)
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
   
   private def void generateProtobufProjectContent(EObject owner, String project_root_path)
   {
      val faultHandlerFileName = Util.resolveServiceFaultHandling(typeResolver, owner).shortName
      generateProjectSourceFile(
         project_root_path,
         faultHandlerFileName,
         new ServiceFaultHandlingGenerator(basicCSharpSourceGenerator).generate(faultHandlerFileName, owner)
      )
       
      val codec_name = GeneratorUtil.getCodecName(owner)
      generateProjectSourceFile(project_root_path, codec_name, generateProtobufCodec(owner, codec_name))
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
   
   private def dispatch void resolveProtobufDependencies(EObject element, EObject owner)
   { /* no-operation dispatch method to match all non-handled cases */ }
   
   private def dispatch void resolveProtobufDependencies(StructDeclaration element, EObject owner)
   {
      resolve(element, ProjectType.PROTOBUF)
      
      for (member : element.members)
      {
         resolveProtobufDependencies(member, owner)
      }
   }
   
   private def dispatch void resolveProtobufDependencies(EnumDeclaration element, EObject owner)
   {
      resolve(element, ProjectType.PROTOBUF)
   }
   
   private def dispatch void resolveProtobufDependencies(ExceptionDeclaration element, EObject owner)
   {
      resolve(element, ProjectType.PROTOBUF)
      
      if (element.supertype !== null)
         resolveProtobufDependencies(element.supertype, owner)
   }
   
   private def dispatch void resolveProtobufDependencies(FunctionDeclaration element, EObject owner)
   {
      for (param : element.parameters)
      {
         resolveProtobufDependencies(param.paramType, owner)
      }
      
      if (!element.returnedType.isVoid)
         resolveProtobufDependencies(element.returnedType, owner)
   }
   
   private def dispatch void resolveProtobufDependencies(AbstractType element, EObject owner)
   {
      if (element.referenceType !== null)
         resolveProtobufDependencies(element.referenceType, owner)
   }
   
   private def generateProtobufCodec(EObject owner, String class_name)
   {
      reinitializeFile
      
      new ProtobufCodecGenerator(basicCSharpSourceGenerator).generate(owner, class_name)
   }

   private def void generateClientConsole(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.CLIENT_CONSOLE)
      
      val project_root_path = getProjectRootPath()
      
      val program_name = "Program"
      generateProjectSourceFile(
        project_root_path,
        program_name,
        generateCsClientConsoleProgram(program_name, module)
      )
      
      file_system_access.generateFile(project_root_path + "App".config, ArtifactNature.DOTNET.label, generateAppConfig(module))
      
      val log4net_name = log4NetConfigFile
      file_system_access.generateFile(project_root_path + log4net_name, ArtifactNature.DOTNET.label, generateLog4NetConfig(module))
      
      generateVSProjectFiles(project_root_path)
   }

   private def generateCsClientConsoleProgram(String class_name, ModuleDeclaration module)
   {
      reinitializeFile

      new ClientConsoleProgramGenerator(basicCSharpSourceGenerator, nuget_packages).generate(class_name, module)      
   }

   private def void generateServerRunner(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.SERVER_RUNNER)
      
      val project_root_path = getProjectRootPath()
      
      val program_name = "Program"
      generateProjectSourceFile(project_root_path, program_name, generateCsServerRunnerProgram(program_name, module))      
      
      file_system_access.generateFile(project_root_path + "App".config, ArtifactNature.DOTNET.label, generateAppConfig(module))
      
      val log4net_name = log4NetConfigFile
      file_system_access.generateFile(project_root_path + log4net_name, ArtifactNature.DOTNET.label, generateLog4NetConfig(module))
      
      generateVSProjectFiles(project_root_path)
   }
   
   private def generateLog4NetConfig(ModuleDeclaration module)
   {
       new Log4NetConfigGenerator(param_bundle.build).generate()
   }
   
   private def generateCsServerRunnerProgram(String class_name, ModuleDeclaration module)
   {
      reinitializeFile
      
      nuget_packages.resolvePackage("CommandLine")

      new ServerRunnerGenerator(basicCSharpSourceGenerator).generate(class_name)      
   }

   private def generateAppConfig(ModuleDeclaration module)
   {
      reinitializeFile
      new AppConfigGenerator(basicCSharpSourceGenerator).generateAppConfig(module)
   }
   
   private def void generateProjectSourceFile(String project_root_path, String fileBaseName, CharSequence content)
    {
        cs_files.add(fileBaseName)
        file_system_access.generateFile(
            project_root_path + fileBaseName.cs,
            ArtifactNature.DOTNET.label,
            generateSourceFile(content.toString)
        )
    }

   private def void generateTest(String project_root_path, InterfaceDeclaration interface_declaration)
    {
        val test_name = getTestClassName(interface_declaration)
        generateProjectSourceFile(project_root_path, test_name, generateCsTest(test_name, interface_declaration))

        val impl_test_name = interface_declaration.name + "ImplTest"
        generateProjectSourceFile(project_root_path, impl_test_name,
            generateCsImplTest(impl_test_name, interface_declaration))

        val server_registration_name = getServerRegistrationName(interface_declaration)
        generateProjectSourceFile(
            project_root_path,
            server_registration_name,
            generateCsServerRegistration(server_registration_name, interface_declaration)
        )

        val zmq_integration_test_name = interface_declaration.name + "ZeroMQIntegrationTest"
        generateProjectSourceFile(project_root_path, zmq_integration_test_name,
            generateCsZeroMQIntegrationTest(zmq_integration_test_name, interface_declaration))        
    }
   
   private def generateCsTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      new TestGenerator(basicCSharpSourceGenerator).generateCsTest(interface_declaration, class_name)
   }
   
   private def generateCsServerRegistration(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile

      new ServerRegistrationGenerator(basicCSharpSourceGenerator).generate(interface_declaration, class_name)
   }

   private def generateCsZeroMQIntegrationTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      new TestGenerator(basicCSharpSourceGenerator).generateIntegrationTest(interface_declaration, class_name)
   }

   private def generateCsImplTest(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      new TestGenerator(basicCSharpSourceGenerator).generateImplTestStub(interface_declaration, class_name)
   }

   private def void generateProxy(String project_root_path, InterfaceDeclaration interface_declaration)
   {
      val proxy_factory_name = getProxyFactoryName(interface_declaration)
      generateProjectSourceFile(project_root_path, proxy_factory_name,
         generateProxyFactory(proxy_factory_name, interface_declaration))      

      
      val proxy_class_name = GeneratorUtil.getClassName(ArtifactNature.DOTNET, param_bundle.projectType, interface_declaration.name)
      generateProjectSourceFile(project_root_path, proxy_class_name,
            generateProxyImplementation(proxy_class_name, interface_declaration))
      
      // generate named events
      for (event : interface_declaration.events.filter[name !== null])
      {
         val file_name = toText(event, interface_declaration) + "Impl"
         generateProjectSourceFile(project_root_path, file_name,
            new ProxyEventGenerator(basicCSharpSourceGenerator).generateProxyEvent(event, interface_declaration))         
      }
   }
      
   private def generateProxyFactory(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      new ProxyFactoryGenerator(basicCSharpSourceGenerator).generate(interface_declaration, class_name)
   }
   
   private def generateProxyImplementation(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      new ProxyGenerator(basicCSharpSourceGenerator).generate(class_name, interface_declaration)
   }
   
   private def void generateServiceAPI(String project_root_path, InterfaceDeclaration interface_declaration)
   {
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
         file_system_access.generateFile(project_root_path + file_name.cs, ArtifactNature.DOTNET.label,
             generateSourceFile(new ServiceAPIGenerator(basicCSharpSourceGenerator).generate(interface_declaration, abstract_type)
         ))
      }
      
      // generate named events
      for (event : interface_declaration.events.filter[name !== null])
      {
         val file_name = toText(event, interface_declaration)
         generateProjectSourceFile(project_root_path, file_name,generateEvent(event))
      }
      
      // generate static class for interface-related constants
      var file_name = getConstName(interface_declaration)
      generateProjectSourceFile(project_root_path, file_name,
          new ServiceAPIGenerator(basicCSharpSourceGenerator).generateConstants(interface_declaration, file_name))
      
      reinitializeFile
      file_name = GeneratorUtil.getClassName(ArtifactNature.DOTNET, param_bundle.projectType, interface_declaration.name)
      generateProjectSourceFile(project_root_path, file_name,
          new ServiceAPIGenerator(basicCSharpSourceGenerator).generateInterface(interface_declaration, file_name))
   }
   
   private def String generateSourceFile(String main_content)
   {
      '''
      «FOR reference : namespace_references.sort AFTER System.lineSeparator»
         using «reference»;
      «ENDFOR»
      «FOR failableAlias : failableAliases»
         using «failableAlias.aliasName» = «FailableAlias.CONTAINER_TYPE»<«failableAlias.basicTypeName»>;
      «ENDFOR»
      namespace «GeneratorUtil.getTransformedModuleName(param_bundle.build, ArtifactNature.DOTNET, TransformType.PACKAGE)»
      {
         «main_content»
      }
      '''
   }
   
   private def String generateCsproj(Iterable<String> cs_files)
   {
      val project_name = vsSolution.getCsprojName(param_bundle.build)
      
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

      CSProjGenerator.generateCSProj(project_name, vsSolution, param_bundle.build, referenced_assemblies, nuget_packages.resolvedPackages, project_references, cs_files, if (is_protobuf) protobuf_files else null
      )      
   }
   
   private def generateEvent(EventDeclaration event)
   {
      reinitializeFile
      
      new ServiceAPIGenerator(basicCSharpSourceGenerator).generateEvent(event)
   }
         
   private def void addGoogleProtocolBuffersReferences()
   {
      nuget_packages.resolvePackage("Google.ProtocolBuffers")
      nuget_packages.resolvePackage("Google.ProtocolBuffers.Serialization")
   }
      
   private def String getProjectRootPath()
   {
      GeneratorUtil.getTransformedModuleName(param_bundle.build, ArtifactNature.DOTNET, TransformType.FILE_SYSTEM)
         + Constants.SEPARATOR_FILE
   }
   
   private def String getLog4NetConfigFile()
   {
      param_bundle.build.log4NetConfigFile
   }
         
}
