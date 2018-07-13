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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.google.common.collect.Sets
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class InterfaceProjectGenerator extends BasicProjectGenerator
{
    val InterfaceDeclaration interfaceDeclaration

    def generate()
    {
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
            for (typeAlias : interfaceDeclaration.contains.filter(AliasDeclaration))
            {
                typedefTable.computeIfAbsent(typeAlias.name, [typeResolver.resolve(typeAlias.type)])
            }

            for (projectType : activeProjectTypes)
            {
                generateProject(paramBundle, projectType, interfaceDeclaration)
                generatePOM(interfaceDeclaration, projectType)
            }
        }
    }

    private def void generateProject(ParameterBundle containerParamBundle, ProjectType projectType,
        InterfaceDeclaration interfaceDeclaration)
    {
        val mavenType = if (projectType == ProjectType.TEST)
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
            default:
            { /* no operation */
            }
        }
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
      
      val implTestName = interfaceDeclaration.name + "ImplTest"
      generateJavaFile(projectSourceRootPath.append(implTestName.java),
          paramBundle, 
         interfaceDeclaration, 
          [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileImplTest(implTestName, testName, interfaceDeclaration)]
      )
      
      val zmqTestName = interfaceDeclaration.name + "ZeroMQIntegrationTest"
      generateJavaFile(projectSourceRootPath.append(zmqTestName.java),
          paramBundle, 
         interfaceDeclaration, 
            [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileZeroMQItegrationTest(zmqTestName, testName, log4jName, projectSourceRootPath, interfaceDeclaration)]         
      )
      
      fileSystemAccess.generateFile(
         makeProjectSourcePath(interfaceDeclaration, ProjectType.TEST, MavenArtifactType.TEST_RESOURCES, PathType.ROOT).append(log4jName).toPortableString,
         ArtifactNature.JAVA.label,
         ConfigFilesGenerator.generateLog4jProperties()
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
      
      val packageName = mavenResolver.registerPackage(interfaceDeclaration, ProjectType.SERVER_RUNNER)
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

}
