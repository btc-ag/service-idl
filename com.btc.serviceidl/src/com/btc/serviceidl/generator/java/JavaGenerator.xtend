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
 * \file       JavaGenerator.xtend
 * 
 * \brief      Xtend generator for Java artifacts from an IDL
 */

package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import com.google.common.collect.Sets
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.Path
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

class JavaGenerator
{
   enum PathType
   {
      ROOT,
      FULL
   }
   
   // parameters
   val Resource resource
   val IFileSystemAccess fileSystemAccess
   val IQualifiedNameProvider qualifiedNameProvider
   val IScopeProvider scopeProvider
   val Map<EObject, String> protobufArtifacts
   val IGenerationSettingsProvider generationSettingsProvider
   val IDLSpecification idl

   val typedefTable = new HashMap<String, ResolvedName>
   val dependencies = new HashSet<MavenDependency>
      
   new(Resource resource, IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IScopeProvider scopeProvider, IGenerationSettingsProvider generationSettingsProvider,
        Map<EObject, String> protobufArtifacts)
    {
      this.resource = resource
      this.fileSystemAccess = fileSystemAccess
      this.qualifiedNameProvider = qualifiedNameProvider
      this.scopeProvider = scopeProvider
      this.protobufArtifacts = protobufArtifacts
      this.generationSettingsProvider = generationSettingsProvider
      
      this.idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
    }  
      
    def void doGenerate()
    {      
      // iterate module by module and generate included content
      for (module : idl.modules)
      {
         processModule(module, generationSettingsProvider.projectTypes)
      }
   }

   private def void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {      
      if (!module.virtual)
      {
         // generate common data types and exceptions, if available
         if (module.containsTypes )
            generateModuleContents(module, projectTypes)

         // generate proxy/dispatcher projects for all contained interfaces
         if (module.containsInterfaces)
            generateInterfaceProjects(module, projectTypes)
      }
      
      // process nested modules
      for (nested_module : module.nestedModules)
         processModule(nested_module, projectTypes)
   }

   private def void generateModuleContents(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {
      reinitializeAll
      
      if (projectTypes.contains(ProjectType.COMMON))
        generateCommon(makeProjectSourcePath(module, ProjectType.COMMON, MavenArtifactType.MAIN_JAVA, PathType.FULL), module)
        
      if (projectTypes.contains(ProjectType.PROTOBUF))
        generateProtobuf(makeProjectSourcePath(module, ProjectType.PROTOBUF, MavenArtifactType.MAIN_JAVA, PathType.FULL), module)
      
      generatePOM(module)
   }

   private def void generateInterfaceProjects(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            reinitializeAll
            
            val activeProjectTypes = Sets.intersection(projectTypes, #{
                ProjectType.SERVICE_API,
                ProjectType.IMPL,
                ProjectType.PROTOBUF,
                ProjectType.PROXY,
                ProjectType.DISPATCHER,
                ProjectType.TEST,
                ProjectType.SERVER_RUNNER,
                ProjectType.CLIENT_CONSOLE
            })

            if (!activeProjectTypes.empty)
            {
                val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).build
    
                // record type aliases
                val typeResolver = createTypeResolver(paramBundle)
                for (typeAlias : interfaceDeclaration.contains.filter(AliasDeclaration).filter[!typedefTable.containsKey(it.name)])
                { 
                    typedefTable.put(typeAlias.name, typeResolver.resolve(typeAlias.type))
                }
                  
                activeProjectTypes.forEach[generateProject(paramBundle, it, interfaceDeclaration)]
                generatePOM(interfaceDeclaration)
            }
        }
    }

   private def void generatePOM(EObject container)
   {
      val pom_path = makeProjectRootPath(container).append("pom".xml)
        fileSystemAccess.generateFile(pom_path.toPortableString, ArtifactNature.JAVA.label,
            new POMGenerator(generationSettingsProvider).generatePOMContents(container, dependencies,
                protobufArtifacts?.get(container)))
   }

   private def IPath makeProjectRootPath(EObject container)
   {      
      Path.fromPortableString(MavenResolver.getArtifactId(container))
   }
   
   private def IPath makeProjectSourcePath(EObject container, ProjectType projectType, MavenArtifactType mavenType, PathType pathType)
   {      
      var result = makeProjectRootPath(container).append(mavenType.directoryLayout)
      
      if (pathType == PathType.FULL)
      {
         val tempParameterBundleBuilder = new ParameterBundle.Builder()
         tempParameterBundleBuilder.reset(Util.getModuleStack(container))
         
         result = result.append(GeneratorUtil.getTransformedModuleName(tempParameterBundleBuilder.build, ArtifactNature.JAVA, TransformType.FILE_SYSTEM))
         if (container instanceof InterfaceDeclaration) result = result.append(container.name.toLowerCase)
         result = result.append(projectType.getName.toLowerCase)
      }

      result
   }
   
   private def void generateProject(ParameterBundle containerParamBundle, ProjectType projectType, InterfaceDeclaration interfaceDeclaration)
   {
      val mavenType =
         if (projectType == ProjectType.TEST
            || projectType == ProjectType.SERVER_RUNNER
            || projectType == ProjectType.CLIENT_CONSOLE
         )
            MavenArtifactType.TEST_JAVA
         else
            MavenArtifactType.MAIN_JAVA
            
      val projectSourceRootPath = makeProjectSourcePath(interfaceDeclaration, projectType, mavenType, PathType.FULL)

      // first, generate content to resolve all dependencies
      switch (projectType)
      {
      case SERVICE_API:
         generateServiceAPI(projectSourceRootPath, interfaceDeclaration)
      case DISPATCHER:
         generateDispatcher(projectSourceRootPath, interfaceDeclaration)
      case IMPL:
         generateImplementationStub(projectSourceRootPath, interfaceDeclaration)
      case PROXY:
         generateProxy(projectSourceRootPath, interfaceDeclaration)
      case PROTOBUF:
         generateProtobuf(projectSourceRootPath, interfaceDeclaration)
      case TEST:
         generateTest(projectSourceRootPath, interfaceDeclaration)
      case SERVER_RUNNER:
         generateServerRunner(projectSourceRootPath, interfaceDeclaration)
      case CLIENT_CONSOLE:
         generateClientConsole(projectSourceRootPath, interfaceDeclaration)
      default: { /* no operation */ }
      }
   }
   
   private def generateSourceFile(EObject container, ProjectType projectType, TypeResolver typeResolver, CharSequence mainContents)
   {
      '''
      package «MavenResolver.resolvePackage(container, Optional.of(projectType))»;
      
      «FOR reference : typeResolver.referenced_types.sort AFTER System.lineSeparator»
         import «reference»;
      «ENDFOR»
      «mainContents»
      '''
   }
   
   private def void generateCommon(IPath projectSourceRootPath, ModuleDeclaration module)
   {
      val paramBundle = ParameterBundle.createBuilder(module.moduleStack).with(ProjectType.COMMON).build
      
      for ( element : module.moduleComponents.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)] )
      {
         generateJavaFile(projectSourceRootPath.append(Names.plain(element).java), paramBundle, module, 
             [basicJavaSourceGenerator|basicJavaSourceGenerator.toDeclaration(element)]
         )
      }
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      // TODO the "common" service fault handler factory is also generated as part of the ServiceAPI!?      
      val serviceFaultHandlerFactoryName = module.asServiceFaultHandlerFactory
      generateJavaFile(projectSourceRootPath.append(ProjectType.COMMON.getClassName(ArtifactNature.JAVA, serviceFaultHandlerFactoryName).java), paramBundle, 
          module, [basicJavaSourceGenerator|new ServiceFaultHandlerFactoryGenerator(basicJavaSourceGenerator).generateServiceFaultHandlerFactory(serviceFaultHandlerFactoryName, module )]
      )
   }
   
   private def void generateServiceAPI(IPath projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {      
      val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(ProjectType.SERVICE_API).build

      // generate all contained types
      // TODO change to Class-based reject with Xtext 2.15
      interfaceDeclaration.contains.filter(AbstractTypeDeclaration).reject[it instanceof AliasDeclaration].forEach[
         generateJavaFile(projectSourceRootPath.append(Names.plain(it).java), paramBundle, interfaceDeclaration, 
             [basicJavaSourceGenerator|new ServiceAPIGenerator(basicJavaSourceGenerator).generateContainedType(it)]
         )
      ]
      
      // generate named events
      for (event : interfaceDeclaration.namedEvents)
      {
          // TODO do not use basicJavaSourceGenerator/typeResolver to generate the file name!
            generateJavaFile(
                projectSourceRootPath.append(createBasicJavaSourceGenerator(paramBundle).toText(event).java),
                paramBundle,
                interfaceDeclaration,
                [basicJavaSourceGenerator|new ServiceAPIGenerator(basicJavaSourceGenerator).generateEvent(event)]
            )
      }
      
      generateJavaFile(projectSourceRootPath.append(ProjectType.SERVICE_API.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name).java),
          paramBundle, 
          interfaceDeclaration,
          [basicJavaSourceGenerator|          
          new ServiceAPIGenerator(basicJavaSourceGenerator).generateMain(interfaceDeclaration)])
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      val serviceFaultHandlerFactoryName = interfaceDeclaration.asServiceFaultHandlerFactory
      generateJavaFile(projectSourceRootPath.append(serviceFaultHandlerFactoryName.java),
          paramBundle, 
          interfaceDeclaration, 
          [basicJavaSourceGenerator|new ServiceFaultHandlerFactoryGenerator(basicJavaSourceGenerator).generateServiceFaultHandlerFactory(serviceFaultHandlerFactoryName, interfaceDeclaration )]
      )
   }   
   
   private def void generateTest(IPath projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(ProjectType.TEST).build

      val log4jName = "log4j.Test".properties
      
      val testName = ProjectType.TEST.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      generateJavaFile(projectSourceRootPath.append(testName.java), paramBundle, interfaceDeclaration, 
          [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateTestStub(testName, projectSourceRootPath, interfaceDeclaration)])
      
      val impl_test_name = interfaceDeclaration.name + "ImplTest"
      generateJavaFile(projectSourceRootPath.append(impl_test_name.java),
          paramBundle, 
         interfaceDeclaration, 
          [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileImplTest(impl_test_name, testName, interfaceDeclaration)]
      )
      
      val zmqTestName = interfaceDeclaration.name + "ZeroMQIntegrationTest"
      generateJavaFile(projectSourceRootPath.append(zmqTestName.java),
          paramBundle, 
         interfaceDeclaration, 
            [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileZeroMQItegrationTest(zmqTestName, testName, log4jName, projectSourceRootPath, interfaceDeclaration)]         
      )
      
      fileSystemAccess.generateFile(
         makeProjectSourcePath(interfaceDeclaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT).append(log4jName).toPortableString,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   private def void generateProtobuf(IPath projectSourceRootPath, EObject container)
   {
      val paramBundle = ParameterBundle.createBuilder(container.moduleStack).with(ProjectType.PROTOBUF).build
       
      val codecName = ProjectType.PROTOBUF.getClassName(ArtifactNature.JAVA, if (container instanceof InterfaceDeclaration) container.name else Constants.FILE_NAME_TYPES) + "Codec"
      // TODO most of the generated file is reusable, and should be moved to com.btc.cab.commons (UUID utilities) or something similar
      
      generateJavaFile(projectSourceRootPath.append(codecName.java), paramBundle, container,
          [basicJavaSourceGenerator|new ProtobufCodecGenerator(basicJavaSourceGenerator).generateProtobufCodecBody(container, codecName)]          
      )  
   }
   
   private def void generateClientConsole(IPath projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(ProjectType.CLIENT_CONSOLE).build
      val programName = "Program"
      val log4jName = "log4j.ClientConsole".properties
      
      generateJavaFile(projectSourceRootPath.append(programName.java),
          paramBundle,
         interfaceDeclaration,
            [basicJavaSourceGenerator|new ClientConsoleGenerator(basicJavaSourceGenerator).generateClientConsoleProgram(programName, log4jName, interfaceDeclaration)]         
      )
      
      fileSystemAccess.generateFile(
         makeProjectSourcePath(interfaceDeclaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT).append(log4jName).toPortableString,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   private def void generateServerRunner(IPath projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(ProjectType.SERVER_RUNNER).build
      val programName = "Program"
      val serverRunnerName = ProjectType.SERVER_RUNNER.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      val beansName = "ServerRunnerBeans".xml
      val log4jName = "log4j.ServerRunner".properties
      
      generateJavaFile(projectSourceRootPath.append(programName.java),
          paramBundle,
         interfaceDeclaration,
         [basicJavaSourceGenerator|new ServerRunnerGenerator(basicJavaSourceGenerator).generateServerRunnerProgram(programName, serverRunnerName, beansName, log4jName, interfaceDeclaration)]
      )

      generateJavaFile(projectSourceRootPath.append(serverRunnerName.java),
          paramBundle,
         interfaceDeclaration, [basicJavaSourceGenerator|new ServerRunnerGenerator(basicJavaSourceGenerator).generateServerRunnerImplementation(serverRunnerName, interfaceDeclaration)]
      )
      
      val packageName = MavenResolver.resolvePackage(interfaceDeclaration, Optional.of(ProjectType.SERVER_RUNNER))
      val testResourcesPath = makeProjectSourcePath(interfaceDeclaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT)
      fileSystemAccess.generateFile(
         testResourcesPath.append(beansName).toPortableString,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateSpringBeans(packageName, programName)
      )
      
      fileSystemAccess.generateFile(
         testResourcesPath.append(log4jName).toPortableString,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   private def void generateProxy(IPath projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(ProjectType.PROXY).build
      val proxyFactoryName = ProjectType.PROXY.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name) + "Factory"
      generateJavaFile(projectSourceRootPath.append(proxyFactoryName.java),
          paramBundle,
         interfaceDeclaration, [basicJavaSourceGenerator|new ProxyFactoryGenerator(basicJavaSourceGenerator).generateProxyFactory(proxyFactoryName, interfaceDeclaration)]
      )

      val proxyClassName = ProjectType.PROXY.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      generateJavaFile(
         projectSourceRootPath.append(proxyClassName.java),
          paramBundle,
         interfaceDeclaration, 
         [basicJavaSourceGenerator|new ProxyGenerator(basicJavaSourceGenerator).generateProxyImplementation(proxyClassName, interfaceDeclaration)]
      )
   }
      
   private def void generateDispatcher(IPath projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(ProjectType.DISPATCHER).build
      val dispatcherClassName = ProjectType.DISPATCHER.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      
      generateJavaFile(projectSourceRootPath.append(dispatcherClassName.java), paramBundle, interfaceDeclaration, [basicJavaSourceGenerator|new DispatcherGenerator(basicJavaSourceGenerator).generateDispatcherBody(dispatcherClassName, interfaceDeclaration)])
   }
   
   private def void generateImplementationStub(IPath projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val paramBundle = ParameterBundle.createBuilder(interfaceDeclaration.moduleStack).with(ProjectType.IMPL).build
      val implementationName = ProjectType.IMPL.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)

      generateJavaFile(projectSourceRootPath.append(implementationName.java), paramBundle, interfaceDeclaration, [basicJavaSourceGenerator|new ImplementationStubGenerator(basicJavaSourceGenerator).generateImplementationStubBody(implementationName, interfaceDeclaration)])   
   }
   
   private def <T extends EObject> void generateJavaFile(IPath fileName, ParameterBundle paramBundle, T declarator, (BasicJavaSourceGenerator)=>CharSequence generateBody)
   {
       // TODO T can be InterfaceDeclaration or ModuleDeclaration, the metamodel should be changed to introduce a common base type of these
      val basicJavaSourceGenerator = createBasicJavaSourceGenerator(paramBundle)
      fileSystemAccess.generateFile(fileName.toPortableString, ArtifactNature.JAVA.label, 
         generateSourceFile(
                declarator,
                paramBundle.projectType,
                basicJavaSourceGenerator.typeResolver,
                generateBody.apply(basicJavaSourceGenerator)
         )
      )
   }
   
   private def createBasicJavaSourceGenerator(ParameterBundle paramBundle)
   {
      new BasicJavaSourceGenerator(qualifiedNameProvider, generationSettingsProvider,
            createTypeResolver(paramBundle), idl, typedefTable)
   }
    
    def createTypeResolver(ParameterBundle paramBundle) {
        new TypeResolver(qualifiedNameProvider, paramBundle, dependencies)
    }
   
   private def void reinitializeAll()
   {
      dependencies.clear
      typedefTable.clear
   }
      
}
