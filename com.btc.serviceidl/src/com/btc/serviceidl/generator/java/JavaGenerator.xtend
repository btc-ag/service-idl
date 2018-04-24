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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
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
import java.util.HashMap
import com.btc.serviceidl.generator.common.ResolvedName

class JavaGenerator
{
   enum PathType
   {
      ROOT,
      FULL
   }
   
   // global variables
   private var Resource resource
   private var IFileSystemAccess file_system_access
   private var IQualifiedNameProvider qualified_name_provider
   private var IScopeProvider scope_provider
   private var Map<EObject, String> protobuf_artifacts
   private var IDLSpecification idl
   
   private var BasicJavaSourceGenerator basicJavaSourceGenerator 
   
   private val typedef_table = new HashMap<String, ResolvedName>
   private val dependencies = new HashSet<MavenDependency>
   
   private var param_bundle = new ParameterBundle.Builder()    
   
   def private getTypeResolver()
   {
       basicJavaSourceGenerator.typeResolver
   }
   
   def public void doGenerate(Resource res, IFileSystemAccess fsa, IQualifiedNameProvider qnp, IScopeProvider sp, Set<ProjectType> projectTypes, Map<EObject, String> pa)
   {
      resource = res
      file_system_access = fsa
      qualified_name_provider = qnp
      scope_provider = sp
      protobuf_artifacts = pa
      
      idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
      
      // iterate module by module and generate included content
      for (module : idl.modules)
      {
         processModule(module, projectTypes)
      }
   }

   def private void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {
      param_bundle = ParameterBundle.createBuilder(Util.getModuleStack(module))
      param_bundle.reset(ArtifactNature.JAVA)
      
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

   def private void generateModuleContents(ModuleDeclaration module, Set<ProjectType> projectTypes)
   {
      reinitializeAll
      param_bundle.reset(Util.getModuleStack(module))
      
      if (projectTypes.contains(ProjectType.COMMON))
        generateCommon(makeProjectSourcePath(module, ProjectType.COMMON, MavenArtifactType.MAIN_JAVA, PathType.FULL), module)
        
      if (projectTypes.contains(ProjectType.PROTOBUF))
        generateProtobuf(makeProjectSourcePath(module, ProjectType.PROTOBUF, MavenArtifactType.MAIN_JAVA, PathType.FULL), module)
      
      generatePOM(module)
   }

   def private void generateInterfaceProjects(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            reinitializeAll
            param_bundle.reset(Util.getModuleStack(interface_declaration))

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
                for (type_alias : interface_declaration.contains.filter(AliasDeclaration))
                {
                   var type_name = typedef_table.get(type_alias.name)
                   if (type_name === null)
                   {
                      type_name = typeResolver.resolve(type_alias.type)
                      typedef_table.put(type_alias.name, type_name)
                   }
                }
                  
                activeProjectTypes.forEach[generateProject(it, interface_declaration)]
                generatePOM(interface_declaration)
            }
        }
    }

   def private void generatePOM(EObject container)
   {
      val pom_path = makeProjectRootPath(container) + "pom".xml
      file_system_access.generateFile(pom_path, POMGenerator.generatePOMContents(container, dependencies, 
          if (protobuf_artifacts !== null && protobuf_artifacts.containsKey(container)) protobuf_artifacts.get(container) else null))
   }

   def private String makeProjectRootPath(EObject container)
   {
      // TODO change return type to Path or something similar
      param_bundle.artifactNature.label
         + Constants.SEPARATOR_FILE
         + qualified_name_provider.getFullyQualifiedName(container).toLowerCase
         + Constants.SEPARATOR_FILE
   }
   
   def private String makeProjectSourcePath(EObject container, ProjectType project_type, MavenArtifactType maven_type, PathType path_type)
   {
      val temp_param = new ParameterBundle.Builder()
      temp_param.reset(param_bundle.artifactNature)
      temp_param.reset(Util.getModuleStack(container))
      
      var result = new StringBuilder
      result.append(makeProjectRootPath(container))
      result.append(maven_type.directoryLayout)
      result.append(Constants.SEPARATOR_FILE)
      
      if (path_type == PathType.FULL)
      {
         result.append(GeneratorUtil.transform(temp_param.build, TransformType.FILE_SYSTEM))
         result.append((if (container instanceof InterfaceDeclaration) "/" + container.name.toLowerCase else ""))
         result.append(Constants.SEPARATOR_FILE)
         result.append(project_type.getName.toLowerCase)
         result.append(Constants.SEPARATOR_FILE)
      }

      result.toString
   }
   
   def private void generateProject(ProjectType project_type, InterfaceDeclaration interface_declaration)
   {
      param_bundle.reset(project_type)
      val maven_type =
         if (project_type == ProjectType.TEST
            || project_type == ProjectType.SERVER_RUNNER
            || project_type == ProjectType.CLIENT_CONSOLE
         )
            MavenArtifactType.TEST_JAVA
         else
            MavenArtifactType.MAIN_JAVA
            
      val src_root_path = makeProjectSourcePath(interface_declaration, project_type, maven_type, PathType.FULL)

      // first, generate content to resolve all dependencies
      switch (project_type)
      {
      case SERVICE_API:
         generateServiceAPI(src_root_path, interface_declaration)
      case DISPATCHER:
         generateDispatcher(src_root_path, interface_declaration)
      case IMPL:
         generateImplementationStub(src_root_path, interface_declaration)
      case PROXY:
         generateProxy(src_root_path, interface_declaration)
      case PROTOBUF:
         generateProtobuf(src_root_path, interface_declaration)
      case TEST:
         generateTest(src_root_path, interface_declaration)
      case SERVER_RUNNER:
         generateServerRunner(src_root_path, interface_declaration)
      case CLIENT_CONSOLE:
         generateClientConsole(src_root_path, interface_declaration)
      default: { /* no operation */ }
      }
   }
   
   def private generateSourceFile(EObject container, String main_content)
   {
      '''
      package «MavenResolver.resolvePackage(container, Optional.of(param_bundle.projectType))»;
      
      «FOR reference : typeResolver.referenced_types.sort AFTER System.lineSeparator»
         import «reference»;
      «ENDFOR»
      «main_content»
      '''
   }
   
   def private void generateCommon(String src_root_path, ModuleDeclaration module)
   {
      param_bundle.reset(ProjectType.COMMON)
      
      for ( element : module.moduleComponents.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)] )
      {
         generateJavaFile(src_root_path + Names.plain(element).java, module, 
             [basicJavaSourceGenerator|basicJavaSourceGenerator.toDeclaration(element)]
         )
      }
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      // TODO the "common" service fault handler factory is also generated as part of the ServiceAPI!?      
      val service_fault_handler_factory_name = module.asServiceFaultHandlerFactory
      generateJavaFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, service_fault_handler_factory_name).java,
          module, [basicJavaSourceGenerator|new ServiceFaultHandlerFactoryGenerator(basicJavaSourceGenerator).generateServiceFaultHandlerFactory(service_fault_handler_factory_name, module ).toString]
      )
   }
   
   def private void generateServiceAPI(String src_root_path, InterfaceDeclaration interface_declaration)
   {      
      // generate all contained types
      for (abstract_type : interface_declaration.contains.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)])
      {
         val file_name = Names.plain(abstract_type)
         generateJavaFile(src_root_path + file_name.java, interface_declaration, 
             [basicJavaSourceGenerator|new ServiceAPIGenerator(basicJavaSourceGenerator, param_bundle).generateContainedType(abstract_type)]
         )
      }
      
      // generate named events
      for (event : interface_declaration.namedEvents)
      {
          // TODO do not use basicJavaSourceGenerator/typeResolver to generate the file name!
          generateJavaFile(src_root_path + basicJavaSourceGenerator.toText(event).java, interface_declaration,
             [basicJavaSourceGenerator|new ServiceAPIGenerator(basicJavaSourceGenerator, param_bundle).generateEvent(event).toString]   
          )
      }
      
      generateJavaFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name).java,
          interface_declaration,
          [basicJavaSourceGenerator|          
          new ServiceAPIGenerator(basicJavaSourceGenerator, param_bundle).generateMain(interface_declaration).toString])
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      val service_fault_handler_factory_name = interface_declaration.asServiceFaultHandlerFactory
      generateJavaFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, service_fault_handler_factory_name).java,
          interface_declaration, [basicJavaSourceGenerator|new ServiceFaultHandlerFactoryGenerator(basicJavaSourceGenerator).generateServiceFaultHandlerFactory(service_fault_handler_factory_name, interface_declaration ).toString]
      )
   }   
   
   def private void generateTest(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val log4j_name = "log4j.Test".properties
      
      val test_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      generateJavaFile(src_root_path + test_name.java, interface_declaration, 
          [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateTestStub(test_name, src_root_path, interface_declaration).toString])
      
      val impl_test_name = interface_declaration.name + "ImplTest"
      generateJavaFile(src_root_path + impl_test_name.java,
         interface_declaration, 
          [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileImplTest(impl_test_name, test_name, interface_declaration).toString]
      )
      
      val zmq_test_name = interface_declaration.name + "ZeroMQIntegrationTest"
      generateJavaFile(src_root_path + zmq_test_name.java,
         interface_declaration, 
            [basicJavaSourceGenerator|new TestGenerator(basicJavaSourceGenerator).generateFileZeroMQItegrationTest(zmq_test_name, test_name, log4j_name, src_root_path, interface_declaration).toString]         
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4j_name,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   def private void generateProtobuf(String src_root_path, EObject container)
   {
      // TODO param_bundle should also be converted into a local
      param_bundle.reset(ProjectType.PROTOBUF)      
      
      val codec_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, if (container instanceof InterfaceDeclaration) container.name else Constants.FILE_NAME_TYPES) + "Codec"
      // TODO most of the generated file is reusable, and should be moved to com.btc.cab.commons (UUID utilities) or something similar
      
      generateJavaFile(src_root_path + codec_name.java, container,
          [basicJavaSourceGenerator|new ProtobufCodecGenerator(basicJavaSourceGenerator, param_bundle).generateProtobufCodecBody(container, codec_name).toString]          
      )  
   }
   
   def private void generateClientConsole(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val program_name = "Program"
      val log4j_name = "log4j.ClientConsole".properties
      
      generateJavaFile(src_root_path + program_name.java,
         interface_declaration,
            [basicJavaSourceGenerator|new ClientConsoleGenerator(basicJavaSourceGenerator).generateClientConsoleProgram(program_name, log4j_name, interface_declaration).toString]         
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4j_name,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   def private void generateServerRunner(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val program_name = "Program"
      val server_runner_name = ProjectType.SERVER_RUNNER.getClassName(param_bundle.artifactNature, interface_declaration.name)
      val beans_name = "ServerRunnerBeans".xml
      val log4j_name = "log4j.ServerRunner".properties
      
      generateJavaFile(src_root_path + program_name.java,
         interface_declaration,
         [basicJavaSourceGenerator|new ServerRunnerGenerator(basicJavaSourceGenerator).generateServerRunnerProgram(program_name, server_runner_name, beans_name, log4j_name, interface_declaration).toString]
      )

      generateJavaFile(src_root_path + server_runner_name.java,
         interface_declaration, [basicJavaSourceGenerator|new ServerRunnerGenerator(basicJavaSourceGenerator).generateServerRunnerImplementation(server_runner_name, interface_declaration).toString]
      )
      
      val package_name = MavenResolver.resolvePackage(interface_declaration, Optional.of(param_bundle.projectType))
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + beans_name,
         ConfigFilesGenerator.generateSpringBeans(package_name, program_name)
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4j_name,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   def private void generateProxy(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val proxy_factory_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name) + "Factory"
      generateJavaFile(src_root_path + proxy_factory_name.java,
         interface_declaration, [basicJavaSourceGenerator|new ProxyFactoryGenerator(basicJavaSourceGenerator).generateProxyFactory(proxy_factory_name, interface_declaration).toString]
      )

      val proxy_class_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      generateJavaFile(
         src_root_path + proxy_class_name.java,
         interface_declaration, 
         [basicJavaSourceGenerator|new ProxyGenerator(basicJavaSourceGenerator, param_bundle).generateProxyImplementation(proxy_class_name, interface_declaration)]
      )
   }
      
   def private void generateDispatcher(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val dispatcher_class_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      
      generateJavaFile(src_root_path + dispatcher_class_name.java, interface_declaration, [basicJavaSourceGenerator|new DispatcherGenerator(basicJavaSourceGenerator, param_bundle).generateDispatcherBody(dispatcher_class_name, interface_declaration).toString])
   }
   
   def private void generateImplementationStub(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val impl_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)

      generateJavaFile(src_root_path + impl_name.java, interface_declaration, [basicJavaSourceGenerator|new ImplementationStubGenerator(basicJavaSourceGenerator).generateImplementationStubBody(impl_name, interface_declaration).toString])   
   }
   
   def private <T extends EObject> void generateJavaFile(String fileName, T declarator, (BasicJavaSourceGenerator)=>String generateBody)
   {
       // TODO T can be InterfaceDeclaration or ModuleDeclaration, the metamodel should be changed to introduce a common base type of these
      reinitializeFile
      
      file_system_access.generateFile(fileName,
         generateSourceFile(declarator,
         generateBody.apply(this.basicJavaSourceGenerator)
         )
      )
   }
   
   // TODO remove this function
   def private void reinitializeFile()
   {
      val typeResolver = new TypeResolver(qualified_name_provider, param_bundle, dependencies)
      basicJavaSourceGenerator = new BasicJavaSourceGenerator(qualified_name_provider, typeResolver, idl, typedef_table)
   }
   
   def private void reinitializeAll()
   {
      reinitializeFile
      dependencies.clear
      typedef_table.clear
   }
      
}
