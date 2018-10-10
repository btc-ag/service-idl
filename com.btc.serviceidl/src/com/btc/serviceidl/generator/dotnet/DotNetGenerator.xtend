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

import com.btc.serviceidl.generator.IGenerationSettings
import com.btc.serviceidl.generator.Maturity
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
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
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import com.google.common.base.Strings
import com.google.common.collect.Sets
import java.util.Arrays
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.emf.ecore.EObject
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
   val IGenerationSettings generationSettings
   val IDLSpecification idl
   
   var NuGetPackageResolver nugetPackages
   var ParameterBundle paramBundle
   
   val typedefTable = new HashMap<String, String>
   val namespaceReferences = new HashSet<String>
   val failableAliases = new HashSet<FailableAlias>
   val vsSolution = new VSSolution
   val csFiles = new HashSet<String>
   val protobufFiles = new HashSet<String>
   val Map<ParameterBundle, Set<ParameterBundle>> protobufProjectReferences
   var extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
    
   val paketDependencies = new HashSet<Pair<String, String>>
   
   new(IDLSpecification idl, IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IGenerationSettings generationSettings, Set<ProjectType> projectTypes,
        Map<ParameterBundle, Set<ParameterBundle>> protobufProjectReferences)
    {
        this.idl = idl
        this.fileSystemAccess = fileSystemAccess
        this.qualifiedNameProvider = qualifiedNameProvider
        this.generationSettings = generationSettings
        this.protobufProjectReferences = protobufProjectReferences
    }

    def void doGenerate()
    {

        // iterate module by module and generate included content
        for (module : idl.modules)
        {
            processModule(module, generationSettings.projectTypes)
        }

        new VSSolutionGenerator(fileSystemAccess, vsSolution, idl.eResource.URI.lastSegment.replace(".idl", "")).
            generateSolutionFile

        val paketDependenciesContent = generatePaketDependencies
        if (paketDependenciesContent !== null)
            fileSystemAccess.generateFile("paket.dependencies", ArtifactNature.DOTNET.label, paketDependenciesContent)

        val paketTemplateContent = generatePaketTemplate
        fileSystemAccess.generateFile("paket.template", ArtifactNature.DOTNET.label, paketTemplateContent)
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
        fileSystemAccess.generateFile(projectRootPath.append("paket.references").toPortableString, ArtifactNature.DOTNET.label, 
                generatePaketReferences)
        paketDependencies.addAll(flatPackages)
      }
   }

   private def getFlatPackages()
   {
       nugetPackages.resolvedPackages.flatPackages
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
      val dependencyChannel = if (generationSettings.maturity == Maturity.SNAPSHOT) "testing" else "stable"

      // TODO shouldn't the sources (at least extern) be configured somewhere else?
      if (!paketDependencies.empty) {
          '''
          frameworks: «DOTNET_FRAMEWORK_VERSION.toString.toLowerCase»
          
          source https://artifactory.bop-dev.de/artifactory/api/nuget/cab-nuget-extern
          source https://artifactory.bop-dev.de/artifactory/api/nuget/cab-nuget-«dependencyChannel»
          
          «generatePaketDependenciesSection(false)»
          '''
      }     
   }
   
   private def replaceMicroVersionByZero(String versionString)
   {
       val parts = versionString.split("[.]")
       parts.set(2, "0")
       return parts.join(".")
   }
   
   private def generatePaketDependenciesSection(boolean forTemplate)
   {
       val prefix = if (forTemplate) "" else "nuget "  
       '''
      «FOR packageEntry : paketDependencies»
          «IF packageEntry.key.startsWith("BTC.")»
            «prefix»«packageEntry.key» ~> «packageEntry.value.replaceMicroVersionByZero» «IF generationSettings.maturity == Maturity.SNAPSHOT»testing«ENDIF»
          «ELSE»
            «prefix»«packageEntry.key» ~> «packageEntry.value»
          «ENDIF»
      «ENDFOR»   
       '''
   }
   
   private def generatePaketTemplate()
   {
      val version = idl.resolveVersion // for Paket, there is no difference between "snapshot" and "release" version numbers
      val releaseUnitName = idl.getReleaseUnitName(ArtifactNature.DOTNET)
      val commonPrefix = vsSolution.allProjects.map[key].reduce[a,b|Strings.commonPrefix(a,b)]
      
      '''
      type file
      id «releaseUnitName»
      version «version»
      authors TODO
      description
        TODO
      
      ''' +
      (if (!paketDependencies.empty) {
          '''
          dependencies
              «generatePaketDependenciesSection(true)»
                    
          '''
      } else '') +  
      '''
      files
        bin/Release/«commonPrefix»* ==> lib
      '''
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
      protobufFiles.clear
      nugetPackages = new NuGetPackageResolver(ServiceCommVersion.get(generationSettings.getTargetVersion(
            DotNetConstants.SERVICECOMM_VERSION_KIND)))
      csFiles.clear
      
      val typeResolver = new TypeResolver(
            DOTNET_FRAMEWORK_VERSION,
            qualifiedNameProvider,
            namespaceReferences,
            failableAliases,
            nugetPackages,
            vsSolution,
            paramBundle
        )
      basicCSharpSourceGenerator = new BasicCSharpSourceGenerator(typeResolver, generationSettings, typedefTable, idl)      
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
   
   private def void generateProtobufProjectContent(AbstractContainerDeclaration owner, IPath projectRootPath)
   {
      val faultHandlerFileName = Util.resolveServiceFaultHandling(typeResolver, owner).shortName
      generateProjectSourceFile(
         projectRootPath,
         faultHandlerFileName,
         new ServiceFaultHandlingGenerator(basicCSharpSourceGenerator).generate(faultHandlerFileName, owner)
      )
       
      val codecName = GeneratorUtil.getCodecName(owner)
      generateProjectSourceFile(projectRootPath, codecName, generateProtobufCodec(owner, codecName))
      
      protobufFiles.add(if (owner instanceof ModuleDeclaration) Constants.FILE_NAME_TYPES else owner.name)
      
      // resolve dependencies across interfaces
      for (element : owner.eAllContents.toIterable)
      {
         resolveProtobufDependencies(element, owner)
      }
   }
   
   private def dispatch void resolveProtobufDependencies(EObject element, AbstractContainerDeclaration owner)
   { /* no-operation dispatch method to match all non-handled cases */ }
   
   private def dispatch void resolveProtobufDependencies(StructDeclaration element, AbstractContainerDeclaration owner)
   {
      typeResolver.resolve(element, ProjectType.PROTOBUF)
      
      for (member : element.members)
      {
         resolveProtobufDependencies(member, owner)
      }
   }
   
   private def dispatch void resolveProtobufDependencies(EnumDeclaration element, AbstractContainerDeclaration owner)
   {
      typeResolver.resolve(element, ProjectType.PROTOBUF)
   }
   
   private def dispatch void resolveProtobufDependencies(ExceptionDeclaration element, AbstractContainerDeclaration owner)
   {
      typeResolver.resolve(element, ProjectType.PROTOBUF)
      
      if (element.supertype !== null)
         resolveProtobufDependencies(element.supertype, owner)
   }
   
   private def dispatch void resolveProtobufDependencies(FunctionDeclaration element, AbstractContainerDeclaration owner)
   {
      for (param : element.parameters)
      {
         resolveProtobufDependencies(param.paramType, owner)
      }
      
      if (!(element.returnedType instanceof VoidType))
         resolveProtobufDependencies(element.returnedType, owner)
   }
   
   private def dispatch void resolveProtobufDependencies(AbstractType element, AbstractContainerDeclaration owner)
   {
      if (element.referenceType !== null)
         resolveProtobufDependencies(element.referenceType, owner)
   }
   
   private def generateProtobufCodec(AbstractContainerDeclaration owner, String className)
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

   // TODO for some reason, the return type must be specified here, otherwise we get compile errors
   // on Jenkins (but not on travis-ci)
   private def CharSequence generateAppConfig(ModuleDeclaration module)
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
        val testName = getTestClassName(interfaceDeclaration)
        generateProjectSourceFile(projectRootPath, testName, generateCsTest(testName, interfaceDeclaration))

        val implTestName = interfaceDeclaration.name + "ImplTest"
        generateProjectSourceFile(projectRootPath, implTestName,
            generateCsImplTest(implTestName, interfaceDeclaration))

        val serverRegistrationName = getServerRegistrationName(interfaceDeclaration)
        generateProjectSourceFile(
            projectRootPath,
            serverRegistrationName,
            generateCsServerRegistration(serverRegistrationName, interfaceDeclaration)
        )

        val zmqIntegrationTestName = interfaceDeclaration.name + "ZeroMQIntegrationTest"
        generateProjectSourceFile(projectRootPath, zmqIntegrationTestName,
            generateCsZeroMQIntegrationTest(zmqIntegrationTestName, interfaceDeclaration))        
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
      val proxyFactoryName = getProxyFactoryName(interfaceDeclaration)
      generateProjectSourceFile(projectRootPath, proxyFactoryName,
         generateProxyFactory(proxyFactoryName, interfaceDeclaration))      

      
      val proxyClassName = GeneratorUtil.getClassName(ArtifactNature.DOTNET, ProjectType.PROXY, interfaceDeclaration.name)
      generateProjectSourceFile(projectRootPath, proxyClassName,
            generateProxyImplementation(proxyClassName, interfaceDeclaration))
      
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
         typedefTable.computeIfAbsent(typeAlias.name, [toText(typeAlias.type, typeAlias)]) 
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
      
      if (paramBundle.projectType == ProjectType.PROTOBUF)
      {
         val protobufReferences = protobufProjectReferences.get(projectName)
         if (protobufReferences !== null)
         {
             typeResolver.projectReferences.addAll(protobufReferences)
         }
      }
      
      CSProjGenerator.generateCSProj(
            projectName,
            vsSolution,
            paramBundle,
            typeResolver.referencedAssemblies,
            typeResolver.projectReferences,
            csFiles,
            protobufFiles
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
