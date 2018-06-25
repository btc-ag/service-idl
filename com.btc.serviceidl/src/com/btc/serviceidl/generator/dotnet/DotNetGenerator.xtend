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
import org.eclipse.core.runtime.IPath
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.common.GeneratorUtil.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

class DotNetGenerator
{
   // constants
   public static val DOTNET_FRAMEWORK_VERSION = DotNetFrameworkVersion.NET46
   
   // global variables
   val IFileSystemAccess fileSystemAccess
   val IQualifiedNameProvider qualifiedNameProvider
   val IGenerationSettingsProvider generationSettingsProvider
   val IDLSpecification idl
   
   var ParameterBundle paramBundle
   
   val typedefTable = new HashMap<String, String>
   val namespaceReferences = new HashSet<String>
   val failableAliases = new HashSet<FailableAlias>
   val referencedAssemblies = new HashSet<String>
   var nugetPackages = new NuGetPackageResolver
   val projectReferences = new HashMap<String, String>
   val vsSolution = new VSSolution
   val csFiles = new HashSet<String>
   val protobufFiles = new HashSet<String>
   var protobufProjectReferences = new HashMap<String, HashMap<String, String>>
   var extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
    
   val paketDependencies = new HashSet<Pair<String, String>>
   
   new(Resource resource, IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IGenerationSettingsProvider generationSettingsProvider, Set<ProjectType> projectTypes,
        HashMap<String, HashMap<String, String>> protobufProjectReferences)
    {
        this.fileSystemAccess = fileSystemAccess
        this.qualifiedNameProvider = qualifiedNameProvider
        this.generationSettingsProvider = generationSettingsProvider
        this.protobufProjectReferences = protobufProjectReferences

        idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
    }

    def void doGenerate()
    {

        // iterate module by module and generate included content
        for (module : idl.modules)
        {
            processModule(module, generationSettingsProvider.projectTypes)
        }

        new VSSolutionGenerator(fileSystemAccess, vsSolution, idl.eResource.URI.lastSegment.replace(".idl", "")).
            generateSolutionFile

        // TODO generate only either NuGet or Paket file
        fileSystemAccess.generateFile("paket.dependencies", ArtifactNature.DOTNET.label, generatePaketDependencies)

    }
   
   private def void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {
      paramBundle = ParameterBundle.createBuilder(module.moduleStack).build
      
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
      for (nestedModule : module.nestedModules)
         processModule(nestedModule, projectTypes)
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
   
   private def void generateProjectStructure(ProjectType projectType, ModuleDeclaration module)
   {
      reinitializeProject(projectType)
      val projectRootPath = getProjectRootPath()
      
      for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(projectType).build
         generateProject(projectType, interfaceDeclaration, projectRootPath)
      }
      
      generateVSProjectFiles(projectRootPath)
   }
   
   private def void generateProject(ProjectType projectType, InterfaceDeclaration interfaceDeclaration, IPath projectRootPath)
   {
      switch (projectType)
      {
      case SERVICE_API:
      {
         generateServiceAPI(projectRootPath, interfaceDeclaration)
      }
      case DISPATCHER:
      {
         addGoogleProtocolBuffersReferences()
         generateDispatcher(projectRootPath, interfaceDeclaration)
      }
      case IMPL:
      {
         generateImpl(projectRootPath, interfaceDeclaration)
      }
      case PROXY:
      {
         addGoogleProtocolBuffersReferences()
         generateProxy(projectRootPath, interfaceDeclaration)
      }
      case TEST:
      {
         generateTest(projectRootPath, interfaceDeclaration)
      }
      default:
         throw new IllegalArgumentException("Project type currently not supported: " + paramBundle.projectType)
      }
   }
   
   private def void generateCommon(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.COMMON)
            
      var fileContent = 
      '''
         «FOR element : module.moduleComponents.reject[it instanceof InterfaceDeclaration]»
             «toText(element, module)»

         «ENDFOR»
      '''

      val projectRootPath = getProjectRootPath()
      generateProjectSourceFile(projectRootPath, Constants.FILE_NAME_TYPES, fileContent)      
      generateVSProjectFiles(projectRootPath)
   }
   
   private def void generateVSProjectFiles(IPath projectRootPath)
   {
      val projectName = vsSolution.getCsprojName(paramBundle)
      
      // generate project file
      fileSystemAccess.generateFile(projectRootPath.append(projectName.csproj).toPortableString, ArtifactNature.DOTNET.label, generateCsproj(csFiles))
      
      // generate mandatory AssemblyInfo.cs file
      fileSystemAccess.generateFile(projectRootPath.append("Properties").append("AssemblyInfo".cs).toPortableString, ArtifactNature.DOTNET.label, generateAssemblyInfo(projectName))   
   
      // NuGet (optional)
      if (!nugetPackages.resolvedPackages.empty)
      {
        fileSystemAccess.generateFile(projectRootPath.append("packages.config").toPortableString, ArtifactNature.DOTNET.label, 
                generatePackagesConfig)
        // TODO generate only either NuGet or Paket file
        fileSystemAccess.generateFile(projectRootPath.append("paket.references").toPortableString, ArtifactNature.DOTNET.label, 
                generatePaketReferences)
        paketDependencies.addAll(flatPackages)
      }
   }
   
   private def getFlatPackages()
   {
      nugetPackages.resolvedPackages.map[it.packageVersions].flatten
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
   
   private def generatePaketReferences()
   {
      '''      
      «FOR packageEntry : flatPackages»
          «packageEntry.key»
      «ENDFOR»
      '''
   }
   
   private def generatePaketDependencies()
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
   
   private def generateAssemblyInfo(String projectName)
   {
       new AssemblyInfoGenerator(paramBundle).generate(projectName)
   }
   
   private def void reinitializeFile()
   {
      namespaceReferences.clear
      failableAliases.clear
   }
   
   private def void reinitializeProject(ProjectType projectType)
   {
      reinitializeFile
      paramBundle = ParameterBundle.createBuilder(paramBundle.moduleStack).with(projectType).build
      referencedAssemblies.clear
      projectReferences.clear
      protobufFiles.clear
      nugetPackages = new NuGetPackageResolver
      csFiles.clear
      
      val typeResolver = new TypeResolver(
            DOTNET_FRAMEWORK_VERSION,
            qualifiedNameProvider,
            namespaceReferences,
            failableAliases,
            referencedAssemblies,
            projectReferences,
            nugetPackages,
            vsSolution,
            paramBundle
        )
      basicCSharpSourceGenerator = new BasicCSharpSourceGenerator(typeResolver, generationSettingsProvider, typedefTable, idl)      
   }
   
   private def void generateImpl(IPath projectRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val implementationClassName = GeneratorUtil.getClassName(ArtifactNature.DOTNET, ProjectType.IMPL, interfaceDeclaration.name)
      generateProjectSourceFile(
        projectRootPath,
        implementationClassName,
        new ImplementationStubGenerator(basicCSharpSourceGenerator).generate(interfaceDeclaration, implementationClassName)
      )      
   }
   
   private def void generateDispatcher(IPath projectRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      reinitializeFile

      val dispatcherClassName = GeneratorUtil.getClassName(ArtifactNature.DOTNET, ProjectType.DISPATCHER, interfaceDeclaration.name)
      generateProjectSourceFile(
        projectRootPath,
        dispatcherClassName,
        new DispatcherGenerator(basicCSharpSourceGenerator).generate(dispatcherClassName, interfaceDeclaration)
      )
   }
   
   private def void generateProtobuf(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.PROTOBUF)
      
      val projectRootPath = getProjectRootPath()
      addGoogleProtocolBuffersReferences()
      
      if (module.containsTypes)
      {
         generateProtobufProjectContent(module, projectRootPath)
      }
      for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         generateProtobufProjectContent(interfaceDeclaration, projectRootPath)
      }
      
      generateVSProjectFiles(projectRootPath)
   }
   
   private def void generateProtobufProjectContent(EObject owner, IPath projectRootPath)
   {
      val faultHandlerFileName = Util.resolveServiceFaultHandling(typeResolver, owner).shortName
      generateProjectSourceFile(
         projectRootPath,
         faultHandlerFileName,
         new ServiceFaultHandlingGenerator(basicCSharpSourceGenerator).generate(faultHandlerFileName, owner)
      )
       
      val codecName = GeneratorUtil.getCodecName(owner)
      generateProjectSourceFile(projectRootPath, codecName, generateProtobufCodec(owner, codecName))
      if (owner instanceof ModuleDeclaration)
      {
         protobufFiles.add(Constants.FILE_NAME_TYPES)
      }
      else if (owner instanceof InterfaceDeclaration)
      {
         protobufFiles.add(owner.name)
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
      typeResolver.resolve(element, ProjectType.PROTOBUF)
      
      for (member : element.members)
      {
         resolveProtobufDependencies(member, owner)
      }
   }
   
   private def dispatch void resolveProtobufDependencies(EnumDeclaration element, EObject owner)
   {
      typeResolver.resolve(element, ProjectType.PROTOBUF)
   }
   
   private def dispatch void resolveProtobufDependencies(ExceptionDeclaration element, EObject owner)
   {
      typeResolver.resolve(element, ProjectType.PROTOBUF)
      
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
   
   private def generateProtobufCodec(EObject owner, String className)
   {
      reinitializeFile
      
      new ProtobufCodecGenerator(basicCSharpSourceGenerator).generate(owner, className)
   }

   private def void generateClientConsole(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.CLIENT_CONSOLE)
      
      val projectRootPath = getProjectRootPath()
      
      val programName = "Program"
      generateProjectSourceFile(
        projectRootPath,
        programName,
        generateCsClientConsoleProgram(programName, module)
      )
      
      fileSystemAccess.generateFile(projectRootPath.append("App".config).toPortableString, ArtifactNature.DOTNET.label, generateAppConfig(module))
      
      val log4netName = log4NetConfigFile
      fileSystemAccess.generateFile(projectRootPath.append(log4netName).toPortableString, ArtifactNature.DOTNET.label, generateLog4NetConfig(module))
      
      generateVSProjectFiles(projectRootPath)
   }

   private def generateCsClientConsoleProgram(String className, ModuleDeclaration module)
   {
      reinitializeFile

      new ClientConsoleProgramGenerator(basicCSharpSourceGenerator, nugetPackages).generate(className, module)      
   }

   private def void generateServerRunner(ModuleDeclaration module)
   {
      reinitializeProject(ProjectType.SERVER_RUNNER)
      
      val projectRootPath = getProjectRootPath()
      
      val programName = "Program"
      generateProjectSourceFile(projectRootPath, programName, generateCsServerRunnerProgram(programName, module))      
      
      fileSystemAccess.generateFile(projectRootPath.append("App".config).toPortableString, ArtifactNature.DOTNET.label, generateAppConfig(module))
      
      val log4netName = log4NetConfigFile
      fileSystemAccess.generateFile(projectRootPath.append(log4netName).toPortableString, ArtifactNature.DOTNET.label, generateLog4NetConfig(module))
      
      generateVSProjectFiles(projectRootPath)
   }
   
   private def generateLog4NetConfig(ModuleDeclaration module)
   {
       new Log4NetConfigGenerator(paramBundle).generate()
   }
   
   private def generateCsServerRunnerProgram(String className, ModuleDeclaration module)
   {
      reinitializeFile
      
      nugetPackages.resolvePackage("CommandLine")

      new ServerRunnerGenerator(basicCSharpSourceGenerator).generate(className)      
   }

   private def generateAppConfig(ModuleDeclaration module)
   {
      reinitializeFile
      new AppConfigGenerator(basicCSharpSourceGenerator).generateAppConfig(module)
   }
   
   private def void generateProjectSourceFile(IPath projectRootPath, String fileBaseName, CharSequence content)
    {
        csFiles.add(fileBaseName)
        fileSystemAccess.generateFile(
            projectRootPath.append(fileBaseName.cs).toPortableString,
            ArtifactNature.DOTNET.label,
            generateSourceFile(content)
        )
    }

   private def void generateTest(IPath projectRootPath, InterfaceDeclaration interfaceDeclaration)
    {
        val test_name = getTestClassName(interfaceDeclaration)
        generateProjectSourceFile(projectRootPath, test_name, generateCsTest(test_name, interfaceDeclaration))

        val impl_test_name = interfaceDeclaration.name + "ImplTest"
        generateProjectSourceFile(projectRootPath, impl_test_name,
            generateCsImplTest(impl_test_name, interfaceDeclaration))

        val server_registration_name = getServerRegistrationName(interfaceDeclaration)
        generateProjectSourceFile(
            projectRootPath,
            server_registration_name,
            generateCsServerRegistration(server_registration_name, interfaceDeclaration)
        )

        val zmq_integration_test_name = interfaceDeclaration.name + "ZeroMQIntegrationTest"
        generateProjectSourceFile(projectRootPath, zmq_integration_test_name,
            generateCsZeroMQIntegrationTest(zmq_integration_test_name, interfaceDeclaration))        
    }
   
   private def generateCsTest(String className, InterfaceDeclaration interfaceDeclaration)
   {
      reinitializeFile
      new TestGenerator(basicCSharpSourceGenerator).generateCsTest(interfaceDeclaration, className)
   }
   
   private def generateCsServerRegistration(String className, InterfaceDeclaration interfaceDeclaration)
   {
      reinitializeFile

      new ServerRegistrationGenerator(basicCSharpSourceGenerator).generate(interfaceDeclaration, className)
   }

   private def generateCsZeroMQIntegrationTest(String className, InterfaceDeclaration interfaceDeclaration)
   {
      reinitializeFile
      new TestGenerator(basicCSharpSourceGenerator).generateIntegrationTest(interfaceDeclaration, className)
   }

   private def generateCsImplTest(String className, InterfaceDeclaration interfaceDeclaration)
   {
      reinitializeFile
      
      new TestGenerator(basicCSharpSourceGenerator).generateImplTestStub(interfaceDeclaration, className)
   }

   private def void generateProxy(IPath projectRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val proxy_factory_name = getProxyFactoryName(interfaceDeclaration)
      generateProjectSourceFile(projectRootPath, proxy_factory_name,
         generateProxyFactory(proxy_factory_name, interfaceDeclaration))      

      
      val proxy_class_name = GeneratorUtil.getClassName(ArtifactNature.DOTNET, ProjectType.PROXY, interfaceDeclaration.name)
      generateProjectSourceFile(projectRootPath, proxy_class_name,
            generateProxyImplementation(proxy_class_name, interfaceDeclaration))
      
      // generate named events
      for (event : interfaceDeclaration.events.filter[name !== null])
      {
         val fileName = toText(event, interfaceDeclaration) + "Impl"
         generateProjectSourceFile(projectRootPath, fileName,
            new ProxyEventGenerator(basicCSharpSourceGenerator).generateProxyEvent(event, interfaceDeclaration))         
      }
   }
      
   private def generateProxyFactory(String className, InterfaceDeclaration interfaceDeclaration)
   {
      reinitializeFile
      new ProxyFactoryGenerator(basicCSharpSourceGenerator).generate(interfaceDeclaration, className)
   }
   
   private def generateProxyImplementation(String className, InterfaceDeclaration interfaceDeclaration)
   {
      reinitializeFile
      
      new ProxyGenerator(basicCSharpSourceGenerator).generate(className, interfaceDeclaration)
   }
   
   private def void generateServiceAPI(IPath projectRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      // TODO this appears familiar from the Java generator
      // record type aliases
      for (typeAlias : interfaceDeclaration.contains.filter(AliasDeclaration))
      {
         var typeName = typedefTable.get(typeAlias.name)
         if (typeName === null)
         {
            typeName = toText(typeAlias.type, typeAlias)
            typedefTable.put(typeAlias.name, typeName)
         }
      }
      
      // generate all contained types
      for (abstractType : interfaceDeclaration.contains.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)])
      {
         reinitializeFile
         val fileName = Names.plain(abstractType)
         csFiles.add(fileName)
         fileSystemAccess.generateFile(projectRootPath.append(fileName.cs).toPortableString, ArtifactNature.DOTNET.label,
             generateSourceFile(new ServiceAPIGenerator(basicCSharpSourceGenerator).generate(interfaceDeclaration, abstractType)
         ))
      }
      
      // generate named events
      for (event : interfaceDeclaration.events.filter[name !== null])
      {
         val fileName = toText(event, interfaceDeclaration)
         generateProjectSourceFile(projectRootPath, fileName,generateEvent(event))
      }
      
      // generate static class for interface-related constants
      var fileName = getConstName(interfaceDeclaration)
      generateProjectSourceFile(projectRootPath, fileName,
          new ServiceAPIGenerator(basicCSharpSourceGenerator).generateConstants(interfaceDeclaration, fileName))
      
      reinitializeFile
      fileName = GeneratorUtil.getClassName(ArtifactNature.DOTNET, ProjectType.SERVICE_API, interfaceDeclaration.name)
      generateProjectSourceFile(projectRootPath, fileName,
          new ServiceAPIGenerator(basicCSharpSourceGenerator).generateInterface(interfaceDeclaration, fileName))
   }
   
   private def generateSourceFile(CharSequence mainContent)
   {
      '''
      «FOR reference : namespaceReferences.sort AFTER System.lineSeparator»
         using «reference»;
      «ENDFOR»
      «FOR failableAlias : failableAliases»
         using «failableAlias.aliasName» = «FailableAlias.CONTAINER_TYPE»<«failableAlias.basicTypeName»>;
      «ENDFOR»
      namespace «GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.DOTNET, TransformType.PACKAGE)»
      {
         «mainContent»
      }
      '''
   }
   
   private def generateCsproj(Iterable<String> csFiles)
   {
      val projectName = vsSolution.getCsprojName(paramBundle)
      
      val isProtobuf = paramBundle.projectType == ProjectType.PROTOBUF
      
      if (isProtobuf)
      {
         val protobufReferences = protobufProjectReferences.get(projectName)
         if (protobufReferences !== null)
         {
            for (key : protobufReferences.keySet)
            {
               if (!projectReferences.containsKey(key))
                  projectReferences.put(key, protobufReferences.get(key))
            }
         }
      }

      CSProjGenerator.generateCSProj(projectName, vsSolution, paramBundle, referencedAssemblies, nugetPackages.resolvedPackages, projectReferences, csFiles, if (isProtobuf) protobufFiles else null
      )      
   }
   
   private def generateEvent(EventDeclaration event)
   {
      reinitializeFile
      
      new ServiceAPIGenerator(basicCSharpSourceGenerator).generateEvent(event)
   }
         
   private def void addGoogleProtocolBuffersReferences()
   {
      nugetPackages.resolvePackage("Google.ProtocolBuffers")
      nugetPackages.resolvePackage("Google.ProtocolBuffers.Serialization")
   }
      
   private def IPath getProjectRootPath()
   {
      paramBundle.asPath(ArtifactNature.DOTNET)
   }
   
   private def String getLog4NetConfigFile()
   {
      paramBundle.log4NetConfigFile
   }
         
}
