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
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import com.google.common.collect.Sets
import java.util.ArrayList
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
         result.append(GeneratorUtil.transform(temp_param.with(TransformType.FILE_SYSTEM).build))
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
          module, [basicJavaSourceGenerator|generateServiceFaultHandlerFactory(service_fault_handler_factory_name, module )]
      )
   }
   
   def private void generateServiceAPI(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val anonymous_event = Util.getAnonymousEvent(interface_declaration)
      
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
      
      // generate all contained types
      for (abstract_type : interface_declaration.contains.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)])
      {
         val file_name = Names.plain(abstract_type)
         generateJavaFile(src_root_path + file_name.java, interface_declaration, 
             [basicJavaSourceGenerator|basicJavaSourceGenerator.toDeclaration(abstract_type)]
         )
      }
      
      // generate named events
      for (event : interface_declaration.namedEvents)
      {
          // TODO do not use basicJavaSourceGenerator/typeResolver to generate the file name!
          generateJavaFile(src_root_path + basicJavaSourceGenerator.toText(event).java, interface_declaration,
             [basicJavaSourceGenerator|generateEvent(event)]   
          )
      }
      
      generateJavaFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name).java,
          interface_declaration,
          [basicJavaSourceGenerator|          
          '''
          public interface «param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)»«IF anonymous_event !== null» extends «typeResolver.resolve(JavaClassNames.OBSERVABLE)»<«basicJavaSourceGenerator.toText(anonymous_event.data)»>«ENDIF» {
          
             «typeResolver.resolve(JavaClassNames.UUID)» TypeGuid = UUID.fromString("«GuidMapper.get(interface_declaration)»");
             
             «FOR function : interface_declaration.functions»
                «basicJavaSourceGenerator.makeInterfaceMethodSignature(function)»;
                
             «ENDFOR»
             
             «FOR event : interface_declaration.events.filter[name !== null]»
                «val observable_name = basicJavaSourceGenerator.toText(event)»
                «observable_name» get«observable_name»();
             «ENDFOR»
          }
          '''])
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      val service_fault_handler_factory_name = interface_declaration.asServiceFaultHandlerFactory
      generateJavaFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, service_fault_handler_factory_name).java,
          interface_declaration, [basicJavaSourceGenerator|generateServiceFaultHandlerFactory(service_fault_handler_factory_name, interface_declaration )]
      )
   }
   
   def private String generateServiceFaultHandlerFactory(String class_name, EObject container)
   {
      val service_fault_handler = typeResolver.resolve(JavaClassNames.DEFAULT_SERVICE_FAULT_HANDLER)
      val i_error = typeResolver.resolve(JavaClassNames.ERROR)
      val optional = typeResolver.resolve(JavaClassNames.OPTIONAL)
      val raised_exceptions = Util.getRaisedExceptions(container)
      val failable_exceptions = Util.getFailableExceptions(container)
      
      // merge both collections to avoid duplicate entries
      val exceptions = new HashSet<AbstractException>
      exceptions.addAll(raised_exceptions)
      exceptions.addAll(failable_exceptions)
      
      // TODO except for the static initializer, this can be extracted into a reusable class, which can be provided 
      // from com.btc.cab.servicecomm
      
      // TODO InvalidArgumentException and UnsupportedOperationException should not be added to the error map, only 
      // service-specific subtypes 
      
      '''
      public class «class_name»
      {
         private static final «typeResolver.resolve("org.apache.commons.collections4.BidiMap")»<String, Exception> errorMap = new «typeResolver.resolve("org.apache.commons.collections4.bidimap.DualHashBidiMap")»<>();
         
         static
         {
            «FOR exception : exceptions.sortBy[name]»
               errorMap.put("«Util.getCommonExceptionName(exception, qualified_name_provider)»", new «typeResolver.resolve(exception)»());
            «ENDFOR»
            
            // most commonly used exception types
            errorMap.put("«Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER»", new IllegalArgumentException());
            errorMap.put("«Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER»", new UnsupportedOperationException());
         }
         
         public static final «typeResolver.resolve(JavaClassNames.SERVICE_FAULT_HANDLER)» createServiceFaultHandler()
         {
            «service_fault_handler» serviceFaultHandler = new «service_fault_handler»();
            errorMap.forEach( (key, value) -> serviceFaultHandler.registerException(key, value) );
            return serviceFaultHandler;
            
         }
         
         public static final Exception createException(String errorType, String message, String stackTrace)
         {
            if (errorMap.containsKey(errorType))
            {
               Exception exception = errorMap.get(errorType);
               try
               {
                  «typeResolver.resolve("java.lang.reflect.Constructor")»<?> constructor = exception.getClass().getConstructor(String.class);
                  return (Exception) constructor.newInstance( new Object[] {message} );
               } catch (Exception ex)
               {
                  return exception;
               }
            }
            
            return new Exception(message); // default exception
         }
         
         public static final «i_error» createError(Exception exception)
         {
            «optional»<String> errorType = «optional».empty();
            for (Exception e : errorMap.values())
            {
               if (e.getClass().equals(exception.getClass()))
               {
                  errorType = «optional».of(errorMap.inverseBidiMap().get(e));
                  break;
               }
            }
            «i_error» error = new «typeResolver.resolve("com.btc.cab.servicecomm.faulthandling.ErrorMessage")»(
                exception.getMessage(),
                errorType.isPresent() ? errorType.get() : exception.getClass().getName(),
                «typeResolver.resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getStackTrace(exception));
            return error;
         }
      }
      '''
   }
   
   def private void generateTest(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val log4j_name = "log4j.Test".properties
      
      val test_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      generateJavaFile(src_root_path + test_name.java, interface_declaration, 
          [basicJavaSourceGenerator|generateFileTest(test_name, src_root_path, interface_declaration)])
      
      val impl_test_name = interface_declaration.name + "ImplTest"
      generateJavaFile(src_root_path + impl_test_name.java,
         interface_declaration, 
          [basicJavaSourceGenerator|generateFileImplTest(impl_test_name, test_name, interface_declaration)]
      )
      
      val zmq_test_name = interface_declaration.name + "ZeroMQIntegrationTest"
      generateJavaFile(src_root_path + zmq_test_name.java,
         interface_declaration, 
            [basicJavaSourceGenerator|generateFileZeroMQItegrationTest(zmq_test_name, test_name, log4j_name, src_root_path, interface_declaration)]         
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4j_name,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   def private String generateFileImplTest(String class_name, String super_class, InterfaceDeclaration interface_declaration)
   {
      '''
      public class «class_name» extends «super_class» {
      
         «typeResolver.resolve(JavaClassNames.JUNIT_BEFORE).alias("@Before")»
         public void setUp() throws Exception {
            super.setUp();
            testSubject = new «typeResolver.resolve(interface_declaration, ProjectType.IMPL)»();
         }
      }
      '''
   }
   
   def private String generateFileTest(String class_name, String src_root_path, InterfaceDeclaration interface_declaration)
   {
       // TODO is this really useful? it only generates a stub, what should be done when regenerating?
       // TODO _assertExceptionType should be moved to com.btc.cab.commons or the like
       
      val api_class = typeResolver.resolve(interface_declaration)
      val junit_assert = typeResolver.resolve(JavaClassNames.JUNIT_ASSERT)
      
      '''
      «typeResolver.resolve(JavaClassNames.JUNIT_IGNORE).alias("@Ignore")»
      public abstract class «class_name» {
      
         protected «api_class» testSubject;
      
         «typeResolver.resolve(JavaClassNames.JUNIT_BEFORE_CLASS).alias("@BeforeClass")»
         public static void setUpBeforeClass() throws Exception {
         }
      
         «typeResolver.resolve(JavaClassNames.JUNIT_AFTER_CLASS).alias("@AfterClass")»
         public static void tearDownAfterClass() throws Exception {
         }
      
         «typeResolver.resolve(JavaClassNames.JUNIT_BEFORE).alias("@Before")»
         public void setUp() throws Exception {
         }
      
         «typeResolver.resolve(JavaClassNames.JUNIT_AFTER).alias("@After")»
         public void tearDown() throws Exception {
         }

         «FOR function : interface_declaration.functions»
            «val is_sync = function.sync»
            «typeResolver.resolve(JavaClassNames.JUNIT_TEST).alias("@Test")»
            public void «function.name.asMethod»Test() throws Exception
            {
               boolean _success = false;
               «FOR param : function.parameters»
                  «basicJavaSourceGenerator.toText(param.paramType)» «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
               «ENDFOR»
               try {
                  testSubject.«function.name.asMethod»(«function.parameters.map[paramName.asParameter].join(",")»)«IF !is_sync».get()«ENDIF»;
               } catch (Exception e) {
                  _success = _assertExceptionType(e);
                  if (!_success)
                     e.printStackTrace();
               } finally {
                  «junit_assert».assertTrue(_success);
               }
            }
         «ENDFOR»
         
         public «typeResolver.resolve(interface_declaration)» getTestSubject() {
            return testSubject;
         }
         
         private boolean _assertExceptionType(Throwable e)
         {
            if (e == null)
               return false;
            
            if (e instanceof UnsupportedOperationException)
                return (e.getMessage() != null && e.getMessage().equals("Auto-generated method stub is not implemented!"));
            else
               return _assertExceptionType(«typeResolver.resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getRootCause(e));
         }
      }
      '''
   }
   
   def private String generateFileZeroMQItegrationTest(String class_name, String super_class, String log4j_name, String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val resources_location = MavenArtifactType.TEST_RESOURCES.directoryLayout
      val junit_assert = typeResolver.resolve(JavaClassNames.JUNIT_ASSERT)
      val server_runner_name = typeResolver.resolve(interface_declaration, ProjectType.SERVER_RUNNER)
      
      // TODO this is definitely outdated, as log4j is no longer used
      
      '''
      public class «class_name» extends «super_class» {
      
         private final static String connectionString = "tcp://127.0.0.1:«Constants.DEFAULT_PORT»";
         private static final «typeResolver.resolve("org.apache.log4j.Logger")» logger = Logger.getLogger(«class_name».class);
         
         private «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» _serverEndpoint;
         private «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» _clientEndpoint;
         private «server_runner_name» _serverRunner;
         
         public «class_name»() {
         }
         
         «typeResolver.resolve(JavaClassNames.JUNIT_BEFORE).alias("@Before")»
         public void setupEndpoints() throws Exception {
            super.setUp();
      
            «typeResolver.resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);
      
            // Start Server
            try {
               «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqServerConnectionFactory")» _serverConnectionFactory = new ZeroMqServerConnectionFactory(logger);
               _serverEndpoint = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ServerEndpointFactory")»(logger, _serverConnectionFactory).create(connectionString);
               _serverRunner = new «server_runner_name»(_serverEndpoint);
               _serverRunner.registerService();
      
               logger.debug("Server started...");
               
               // start client
               «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» connectionFactory = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqClientConnectionFactory")»(
                     logger);
               _clientEndpoint = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ClientEndpointFactory")»(logger, connectionFactory).create(connectionString);
      
               logger.debug("Client started...");
               testSubject = «typeResolver.resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.PROXY)) + '''.«interface_declaration.name»ProxyFactory''')»
                     .createDirectProtobufProxy(_clientEndpoint);
      
               logger.debug("«interface_declaration.name» instantiated...");
               
            } catch (Exception e) {
               logger.error("Error on start: ", e);
               «junit_assert».fail(e.getMessage());
            }
         }
      
         «typeResolver.resolve(JavaClassNames.JUNIT_AFTER).alias("@After")»
         public void tearDown() {
      
            try {
               if (_serverEndpoint != null)
                  _serverEndpoint.close();
            } catch (Exception e) {
               e.printStackTrace();
               «junit_assert».fail(e.getMessage());
            }
            try {
               if (_clientEndpoint != null)
                  _clientEndpoint.close();
               testSubject = null;
      
            } catch (Exception e) {
               e.printStackTrace();
               «junit_assert».fail(e.getMessage());
            }
         }
      }
      '''
   }
      
   def private String generateEvent(EventDeclaration event)
   {
      val keys = new ArrayList<Pair<String, String>>
      for (key : event.keys)
      {
         keys.add(Pair.of(key.keyName, basicJavaSourceGenerator.toText(key.type)))
      }

      '''
      public abstract class «basicJavaSourceGenerator.toText(event)» implements «typeResolver.resolve(JavaClassNames.OBSERVABLE)»<«basicJavaSourceGenerator.toText(event.data)»> {
         
         «IF !keys.empty»
            public class KeyType {
               
               «FOR key : keys»
                  private «key.value» «key.key»;
               «ENDFOR»
               
               public KeyType(«FOR key : keys SEPARATOR ", "»«key.value» «key.key»«ENDFOR»)
               {
                  «FOR key : keys»
                     this.«key.key» = «key.key»;
                  «ENDFOR»
               }
               
               «FOR key : keys SEPARATOR System.lineSeparator»
                  «BasicJavaSourceGenerator.makeGetter(key.value, key.key)»
               «ENDFOR»
            }
            
            public abstract «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«basicJavaSourceGenerator.toText(event.data)»> subscriber, Iterable<KeyType> keys);
         «ENDIF»
      }
      '''
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
         interface_declaration, [basicJavaSourceGenerator|new ProxyFactoryGenerator(basicJavaSourceGenerator, param_bundle).generateProxyFactory(proxy_factory_name, interface_declaration).toString]
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
      basicJavaSourceGenerator = new BasicJavaSourceGenerator(qualified_name_provider, typeResolver, idl)
   }
   
   def private void reinitializeAll()
   {
      reinitializeFile
      dependencies.clear
   }
      
   def private String makeDefaultValue(EObject element)
   {
       basicJavaSourceGenerator.makeDefaultValue(element)
   }

}
