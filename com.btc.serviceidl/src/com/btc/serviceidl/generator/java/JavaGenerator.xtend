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
import java.util.Arrays
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
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.util.Extensions.*

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

   var BasicJavaSourceGenerator basicJavaSourceGenerator 
   
   var ParameterBundle.Builder paramBundle = null
   
   private def getTypeResolver()
   {
       basicJavaSourceGenerator.typeResolver
   }
   
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
      paramBundle = ParameterBundle.createBuilder(Util.getModuleStack(module))
      
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
      paramBundle.reset(Util.getModuleStack(module))
      
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
            paramBundle.reset(Util.getModuleStack(interfaceDeclaration))

            val activeProjectTypes = Sets.intersection(projectTypes, new HashSet<ProjectType>(Arrays.asList(
                ProjectType.SERVICE_API,
                ProjectType.IMPL,
                ProjectType.PROTOBUF,
                ProjectType.PROXY,
                ProjectType.DISPATCHER,
                ProjectType.TEST,
                ProjectType.SERVER_RUNNER,
                ProjectType.CLIENT_CONSOLE
            )))

            if (!activeProjectTypes.empty)
            {
                // record type aliases
                for (typeAlias : interfaceDeclaration.contains.filter(AliasDeclaration))
                { 
                   if (!typedefTable.containsKey(typeAlias.name))
                   {
                      typedefTable.put(typeAlias.name, typeResolver.resolve(typeAlias.type))
                   }
                }
                  
                activeProjectTypes.forEach[generateProject(it, interfaceDeclaration)]
                generatePOM(interfaceDeclaration)
            }
        }
    }

   private def void generatePOM(EObject container)
   {
      val pom_path = makeProjectRootPath(container) + "pom".xml
        fileSystemAccess.generateFile(pom_path, ArtifactNature.JAVA.label,
            new POMGenerator(generationSettingsProvider).generatePOMContents(container, dependencies,
                protobufArtifacts?.get(container)))
   }

   private def String makeProjectRootPath(EObject container)
   {
      // TODO change return type to Path or something similar
      MavenResolver.getArtifactId(container) + Constants.SEPARATOR_FILE
   }
   
   private def String makeProjectSourcePath(EObject container, ProjectType projectType, MavenArtifactType mavenType, PathType pathType)
   {
      val tempParameterBundleBuilder = new ParameterBundle.Builder()
      tempParameterBundleBuilder.reset(Util.getModuleStack(container))
      
      var result = new StringBuilder
      result.append(makeProjectRootPath(container))
      result.append(mavenType.directoryLayout)
      result.append(Constants.SEPARATOR_FILE)
      
      if (pathType == PathType.FULL)
      {
         result.append(GeneratorUtil.getTransformedModuleName(tempParameterBundleBuilder.build, ArtifactNature.JAVA, TransformType.FILE_SYSTEM))
         result.append((if (container instanceof InterfaceDeclaration) "/" + container.name.toLowerCase else ""))
         result.append(Constants.SEPARATOR_FILE)
         result.append(projectType.getName.toLowerCase)
         result.append(Constants.SEPARATOR_FILE)
      }

      result.toString
   }
   
   private def void generateProject(ProjectType projectType, InterfaceDeclaration interfaceDeclaration)
   {
      paramBundle.reset(projectType)
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
   
   private def generateSourceFile(EObject container, CharSequence mainContents)
   {
      '''
      package «MavenResolver.resolvePackage(container, Optional.of(paramBundle.projectType))»;
      
      «FOR reference : typeResolver.referenced_types.sort AFTER System.lineSeparator»
         import «reference»;
      «ENDFOR»
      «mainContents»
      '''
   }
   
   private def void generateCommon(String projectSourceRootPath, ModuleDeclaration module)
   {
      paramBundle.reset(ProjectType.COMMON)
      
      for ( element : module.moduleComponents.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)] )
      {
         generateJavaFile(projectSourceRootPath + Names.plain(element).java, module, 
             [basicJavaSourceGenerator|basicJavaSourceGenerator.toDeclaration(element)]
         )
      }
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      // TODO the "common" service fault handler factory is also generated as part of the ServiceAPI!?      
      val serviceFaultHandlerFactoryName = module.asServiceFaultHandlerFactory
      generateJavaFile(projectSourceRootPath + paramBundle.projectType.getClassName(ArtifactNature.JAVA, serviceFaultHandlerFactoryName).java,
          module, [basicJavaSourceGenerator|new ServiceFaultHandlerFactoryGenerator(basicJavaSourceGenerator).generateServiceFaultHandlerFactory(serviceFaultHandlerFactoryName, module )]
      )
   }
   
   private def void generateServiceAPI(String projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {      
      // generate all contained types
      for (abstractType : interfaceDeclaration.contains.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)])
      {
         val fileName = Names.plain(abstractType)
         generateJavaFile(projectSourceRootPath + fileName.java, interfaceDeclaration, 
             [basicJavaSourceGenerator|new ServiceAPIGenerator(basicJavaSourceGenerator, paramBundle.build).generateContainedType(abstractType)]
         )
      }
      
      // generate named events
      for (event : interfaceDeclaration.namedEvents)
      {
          // TODO do not use basicJavaSourceGenerator/typeResolver to generate the file name!
          generateJavaFile(projectSourceRootPath + basicJavaSourceGenerator.toText(event).java, interfaceDeclaration,
             [basicJavaSourceGenerator|new ServiceAPIGenerator(basicJavaSourceGenerator, paramBundle.build).generateEvent(event)]   
          )
      }
      
      generateJavaFile(projectSourceRootPath + paramBundle.projectType.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name).java,
          interfaceDeclaration,
          [basicJavaSourceGenerator|          
          new ServiceAPIGenerator(basicJavaSourceGenerator, paramBundle.build).generateMain(interfaceDeclaration)])
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      val serviceFaultHandlerFactoryName = interfaceDeclaration.asServiceFaultHandlerFactory
      generateJavaFile(projectSourceRootPath + serviceFaultHandlerFactoryName.java,
          interfaceDeclaration, [basicJavaSourceGenerator|new ServiceFaultHandlerFactoryGenerator(basicJavaSourceGenerator).generateServiceFaultHandlerFactory(serviceFaultHandlerFactoryName, interfaceDeclaration )]
      )
   }   
   
   private def void generateTest(String projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val log4jName = "log4j.Test".properties
      
      val testName = paramBundle.projectType.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      generateJavaFile(projectSourceRootPath + testName.java, interfaceDeclaration, 
          [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateTestStub(testName, projectSourceRootPath, interfaceDeclaration)])
      
      val impl_test_name = interfaceDeclaration.name + "ImplTest"
      generateJavaFile(projectSourceRootPath + impl_test_name.java,
         interfaceDeclaration, 
          [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileImplTest(impl_test_name, testName, interfaceDeclaration)]
      )
      
      val zmqTestName = interfaceDeclaration.name + "ZeroMQIntegrationTest"
      generateJavaFile(projectSourceRootPath + zmqTestName.java,
         interfaceDeclaration, 
            [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileZeroMQItegrationTest(zmqTestName, testName, log4jName, projectSourceRootPath, interfaceDeclaration)]         
      )
      
      fileSystemAccess.generateFile(
         makeProjectSourcePath(interfaceDeclaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4jName,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   private def void generateProtobuf(String projectSourceRootPath, EObject container)
   {
      // TODO param_bundle should also be converted into a local
      paramBundle.reset(ProjectType.PROTOBUF)      
      
      val codecName = paramBundle.projectType.getClassName(ArtifactNature.JAVA, if (container instanceof InterfaceDeclaration) container.name else Constants.FILE_NAME_TYPES) + "Codec"
      // TODO most of the generated file is reusable, and should be moved to com.btc.cab.commons (UUID utilities) or something similar
      
      generateJavaFile(projectSourceRootPath + codecName.java, container,
          [basicJavaSourceGenerator|new ProtobufCodecGenerator(basicJavaSourceGenerator).generateProtobufCodecBody(container, codecName)]          
      )  
   }
   
   private def void generateClientConsole(String projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val programName = "Program"
      val log4jName = "log4j.ClientConsole".properties
      
      generateJavaFile(projectSourceRootPath + programName.java,
         interfaceDeclaration,
            [basicJavaSourceGenerator|new ClientConsoleGenerator(basicJavaSourceGenerator).generateClientConsoleProgram(programName, log4jName, interfaceDeclaration)]         
      )
      
      fileSystemAccess.generateFile(
         makeProjectSourcePath(interfaceDeclaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4jName,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   private def void generateServerRunner(String projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val programName = "Program"
      val serverRunnerName = ProjectType.SERVER_RUNNER.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      val beansName = "ServerRunnerBeans".xml
      val log4jName = "log4j.ServerRunner".properties
      
      generateJavaFile(projectSourceRootPath + programName.java,
         interfaceDeclaration,
         [basicJavaSourceGenerator|new ServerRunnerGenerator(basicJavaSourceGenerator).generateServerRunnerProgram(programName, serverRunnerName, beansName, log4jName, interfaceDeclaration)]
      )

      generateJavaFile(projectSourceRootPath + serverRunnerName.java,
         interfaceDeclaration, [basicJavaSourceGenerator|new ServerRunnerGenerator(basicJavaSourceGenerator).generateServerRunnerImplementation(serverRunnerName, interfaceDeclaration)]
      )
      
      val packageName = MavenResolver.resolvePackage(interfaceDeclaration, Optional.of(paramBundle.projectType))
      fileSystemAccess.generateFile(
         makeProjectSourcePath(interfaceDeclaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + beansName,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateSpringBeans(packageName, programName)
      )
      
      fileSystemAccess.generateFile(
         makeProjectSourcePath(interfaceDeclaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4jName,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   private def void generateProxy(String projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val proxyFactoryName = paramBundle.projectType.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name) + "Factory"
      generateJavaFile(projectSourceRootPath + proxyFactoryName.java,
         interfaceDeclaration, [basicJavaSourceGenerator|new ProxyFactoryGenerator(basicJavaSourceGenerator).generateProxyFactory(proxyFactoryName, interfaceDeclaration)]
      )

      val proxyClassName = paramBundle.projectType.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      generateJavaFile(
         projectSourceRootPath + proxyClassName.java,
         interfaceDeclaration, 
         [basicJavaSourceGenerator|new ProxyGenerator(basicJavaSourceGenerator).generateProxyImplementation(proxyClassName, interfaceDeclaration)]
      )
   }
      
   private def void generateDispatcher(String projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val dispatcherClassName = paramBundle.projectType.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)
      
      generateJavaFile(projectSourceRootPath + dispatcherClassName.java, interfaceDeclaration, [basicJavaSourceGenerator|new DispatcherGenerator(basicJavaSourceGenerator).generateDispatcherBody(dispatcherClassName, interfaceDeclaration)])
   }
   
   private def void generateImplementationStub(String projectSourceRootPath, InterfaceDeclaration interfaceDeclaration)
   {
      val implementationName = paramBundle.projectType.getClassName(ArtifactNature.JAVA, interfaceDeclaration.name)

      generateJavaFile(projectSourceRootPath + implementationName.java, interfaceDeclaration, [basicJavaSourceGenerator|new ImplementationStubGenerator(basicJavaSourceGenerator).generateImplementationStubBody(implementationName, interfaceDeclaration)])   
   }
   
   private def <T extends EObject> void generateJavaFile(String fileName, T declarator, (BasicJavaSourceGenerator)=>CharSequence generateBody)
   {
       // TODO T can be InterfaceDeclaration or ModuleDeclaration, the metamodel should be changed to introduce a common base type of these
      reinitializeFile
      
      fileSystemAccess.generateFile(fileName, ArtifactNature.JAVA.label, 
         generateSourceFile(declarator,
         generateBody.apply(this.basicJavaSourceGenerator)
         )
      )
   }
   
   // TODO remove this function
   private def void reinitializeFile()
   {
      val typeResolver = new TypeResolver(qualifiedNameProvider, paramBundle.build, dependencies)
      basicJavaSourceGenerator = new BasicJavaSourceGenerator(qualifiedNameProvider, generationSettingsProvider, typeResolver, idl, typedefTable)
   }
   
   private def void reinitializeAll()
   {
      reinitializeFile
      dependencies.clear
      typedefTable.clear
   }
      
}
