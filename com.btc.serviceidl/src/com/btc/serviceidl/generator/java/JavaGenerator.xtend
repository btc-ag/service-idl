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
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
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
import static extension com.btc.serviceidl.generator.java.ProtobufUtil.*
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
   
   private var TypeResolver typeResolver
   private var BasicJavaSourceGenerator basicJavaSourceGenerator 
   
   private val typedef_table = new HashMap<String, ResolvedName>
   private val dependencies = new HashSet<MavenDependency>
   
   private var param_bundle = new ParameterBundle.Builder()
   
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
         generateImpl(src_root_path, interface_declaration)
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
   
   def private String generateSourceFile(EObject container, String main_content)
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
         reinitializeFile
         file_system_access.generateFile(src_root_path + Names.plain(element).java, generateSourceFile(module, basicJavaSourceGenerator.toDeclaration(element)))
      }
      
      // common service fault handler factory
      reinitializeFile
      val service_fault_handler_factory_name = module.asServiceFaultHandlerFactory
      file_system_access.generateFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, service_fault_handler_factory_name).java,
         generateSourceFile( module, generateServiceFaultHandlerFactory(service_fault_handler_factory_name, module ))
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
         reinitializeFile
         file_system_access.generateFile(src_root_path + file_name.java, generateSourceFile(interface_declaration, basicJavaSourceGenerator.toDeclaration(abstract_type)))
      }
      
      // generate named events
      for (event : interface_declaration.contains.filter(EventDeclaration).filter[name !== null])
      {
         reinitializeFile
         file_system_access.generateFile(src_root_path + basicJavaSourceGenerator.toText(event).java, generateSourceFile(interface_declaration, generateEvent(event)))
      }
      
      reinitializeFile
      file_system_access.generateFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name).java,
      generateSourceFile(interface_declaration,
      '''
      public interface «param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)»«IF anonymous_event !== null» extends «typeResolver.resolve(JavaClassNames.OBSERVABLE)»<«basicJavaSourceGenerator.toText(anonymous_event.data)»>«ENDIF» {

         «typeResolver.resolve(JavaClassNames.UUID)» TypeGuid = UUID.fromString("«GuidMapper.get(interface_declaration)»");
         
         «FOR function : interface_declaration.functions»
            «makeInterfaceMethodSignature(function)»;
            
         «ENDFOR»
         
         «FOR event : interface_declaration.events.filter[name !== null]»
            «val observable_name = basicJavaSourceGenerator.toText(event)»
            «observable_name» get«observable_name»();
         «ENDFOR»
      }
      '''))
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      reinitializeFile
      val service_fault_handler_factory_name = interface_declaration.asServiceFaultHandlerFactory
      file_system_access.generateFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, service_fault_handler_factory_name).java,
         generateSourceFile( interface_declaration, generateServiceFaultHandlerFactory(service_fault_handler_factory_name, interface_declaration ))
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
      
      reinitializeFile
      val test_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      file_system_access.generateFile(src_root_path + test_name.java,
         generateSourceFile(interface_declaration, generateFileTest(test_name, src_root_path, interface_declaration))
      )
      
      reinitializeFile
      val impl_test_name = interface_declaration.name + "ImplTest"
      file_system_access.generateFile(src_root_path + impl_test_name.java,
         generateSourceFile(interface_declaration, 
            generateFileImplTest(impl_test_name, test_name, interface_declaration)
         )
      )
      
      reinitializeFile
      val zmq_test_name = interface_declaration.name + "ZeroMQIntegrationTest"
      file_system_access.generateFile(src_root_path + zmq_test_name.java,
         generateSourceFile(interface_declaration, 
            generateFileZeroMQItegrationTest(zmq_test_name, test_name, log4j_name, src_root_path, interface_declaration)
         )
      )
      
      reinitializeFile
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
   
   def private String makeInterfaceMethodSignature(FunctionDeclaration function)
   {
      val is_sync = function.isSync
      val is_void = function.returnedType.isVoid
      
      '''
      «IF !is_sync»«typeResolver.resolve("java.util.concurrent.Future")»<«ENDIF»«IF !is_sync && is_void»Void«ELSE»«basicJavaSourceGenerator.toText(function.returnedType)»«ENDIF»«IF !function.isSync»>«ENDIF» «function.name.toFirstLower»(
         «FOR param : function.parameters SEPARATOR ","»
            «IF param.direction == ParameterDirection.PARAM_IN»final «ENDIF»«basicJavaSourceGenerator.toText(param.paramType)» «basicJavaSourceGenerator.toText(param)»
         «ENDFOR»
      ) throws«FOR exception : function.raisedExceptions SEPARATOR ',' AFTER ','» «basicJavaSourceGenerator.toText(exception)»«ENDFOR» Exception'''
   }
   
   def private String generateEvent(EventDeclaration event)
   {
      reinitializeFile
      
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
      reinitializeFile
      param_bundle.reset(ProjectType.PROTOBUF)
      
      
      val codec_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, if (container instanceof InterfaceDeclaration) container.name else Constants.FILE_NAME_TYPES) + "Codec"
      // TODO most of the generated file is reusable, and should be moved to com.btc.cab.commons (UUID utilities) or something similar 
      file_system_access.generateFile(src_root_path + codec_name.java, generateSourceFile(container,
         new ProtobufCodecGenerator(basicJavaSourceGenerator, param_bundle).generateProtobufCodecBody(container, codec_name).toString
      ))
   }
   
   def private void generateClientConsole(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val program_name = "Program"
      val log4j_name = "log4j.ClientConsole".properties
      
      file_system_access.generateFile(src_root_path + program_name.java,
         generateSourceFile(interface_declaration,
            generateClientConsoleProgram(program_name, log4j_name, interface_declaration)
         )
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.CLIENT_CONSOLE, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4j_name,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   def private String generateClientConsoleProgram(String class_name, String log4j_name, InterfaceDeclaration interface_declaration)
   {
      val resources_location = MavenArtifactType.TEST_RESOURCES.directoryLayout
      val api_name = typeResolver.resolve(interface_declaration)
      val connection_string = '''tcp://127.0.0.1:«Constants.DEFAULT_PORT»'''
      
      '''
      public class «class_name» {
      
         private final static String connectionString = "«connection_string»";
         private static final «typeResolver.resolve("org.apache.log4j.Logger")» logger = Logger.getLogger(«class_name».class);
         
         public static void main(String[] args) {
            
            «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» client = null;
            «api_name» proxy = null;
            «typeResolver.resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);

            logger.info("Client trying to connect to " + connectionString);
            «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» connectionFactory = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqClientConnectionFactory")»(logger);
            
            try {
               client = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ClientEndpointFactory")»(logger, connectionFactory).create(connectionString);
            } catch (Exception e)
            {
               logger.error("Client could not start! Is there a server running on «connection_string»? Error: " + e.toString());
            }
      
            logger.info("Client started...");
            try {
               proxy = «typeResolver.resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.PROXY)) + '''.«interface_declaration.name»ProxyFactory''')».createDirectProtobufProxy(client);
            } catch (Exception e) {
               logger.error("Could not create proxy! Error: " + e.toString());
            }
            
            if (proxy != null)
            {
               logger.info("Start calling proxy methods...");
               callAllProxyMethods(proxy);
            }
            
            if (client != null)
            {
               logger.info("Client closing...");
               try { client.close(); } catch (Exception e) { logger.error(e); }
            }
            
            logger.info("Exit...");
            System.exit(0);
         }
         
         private static void callAllProxyMethods(«api_name» proxy) {
            
            int errorCount = 0;
            int callCount = 0;
            «FOR function : interface_declaration.functions»
               «val function_name = function.name.asMethod»
               «val is_void = function.returnedType.isVoid»
               try
               {
                  callCount++;
                  «FOR param : function.parameters»
                     «val is_sequence = Util.isSequenceType(param.paramType)»
                     «val basic_type = typeResolver.resolve(Util.getUltimateType(param.paramType))»
                     «val is_failable = is_sequence && Util.isFailable(param.paramType)»
                     «IF is_sequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«ENDIF»«basic_type»«IF is_sequence»«IF is_failable»>«ENDIF»>«ENDIF» «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
                  «ENDFOR»
                  «IF !is_void»Object result = «ENDIF»proxy.«function_name»(«function.parameters.map[paramName.asParameter].join(", ")»)«IF !function.sync».get()«ENDIF»;
                  logger.info("Result of «api_name».«function_name»: «IF is_void»void"«ELSE»" + result.toString()«ENDIF»);
               }
               catch (Exception e)
               {
                  errorCount++;
                  logger.error("Result of «api_name».«function_name»: " + e.toString());
               }
            «ENDFOR»
            
            logger.info("READY! Overall result: " + callCount + " function calls, " + errorCount + " errors.");
         }
      }
      '''
   }
   
   def private void generateServerRunner(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val program_name = "Program"
      val server_runner_name = ProjectType.SERVER_RUNNER.getClassName(param_bundle.artifactNature, interface_declaration.name)
      val package_name = MavenResolver.resolvePackage(interface_declaration, Optional.of(param_bundle.projectType))
      val beans_name = "ServerRunnerBeans".xml
      val log4j_name = "log4j.ServerRunner".properties
      
      file_system_access.generateFile(src_root_path + program_name.java,
         generateSourceFile(interface_declaration,
            generateServerRunnerProgram(program_name, server_runner_name, beans_name, log4j_name, interface_declaration)
         )
      )

      file_system_access.generateFile(src_root_path + server_runner_name.java,
         generateSourceFile(interface_declaration, generateServerRunnerImplementation(server_runner_name, interface_declaration))
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + beans_name,
         ConfigFilesGenerator.generateSpringBeans(package_name, program_name)
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4j_name,
         ConfigFilesGenerator.generateLog4jProperties()
      )
   }
   
   def private String generateServerRunnerImplementation(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val api_name = typeResolver.resolve(interface_declaration)
      val impl_name = typeResolver.resolve(interface_declaration, ProjectType.IMPL)
      val dispatcher_name = typeResolver.resolve(interface_declaration, ProjectType.DISPATCHER)
      
      '''
      public class «class_name» implements «typeResolver.resolve("java.lang.AutoCloseable")» {
      
         private final «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» _serverEndpoint;
         private «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceRegistration")» _serviceRegistration;
      
         public «class_name»(IServerEndpoint serverEndpoint) {
            _serverEndpoint = serverEndpoint;
         }
      
         public void registerService() throws Exception {
      
            // Create ServiceDescriptor for the service
            «typeResolver.resolve("com.btc.cab.servicecomm.api.dto.ServiceDescriptor")» serviceDescriptor = new ServiceDescriptor();

            serviceDescriptor.setServiceTypeUuid(«api_name».TypeGuid);
            serviceDescriptor.setServiceTypeName("«api_name.fullyQualifiedName»");
            serviceDescriptor.setServiceInstanceName("«interface_declaration.name»TestService");
            serviceDescriptor
               .setServiceInstanceDescription("«api_name.fullyQualifiedName» instance for integration tests");
      
            // Create dispatcher and dispatchee instances
            «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtoBufServerHelper")» protoBufServerHelper = new ProtoBufServerHelper();
            «impl_name» dispatchee = new «impl_name»();
            «dispatcher_name» dispatcher = new «dispatcher_name»(dispatchee, protoBufServerHelper);
      
            // Register dispatcher
            _serviceRegistration = _serverEndpoint
                  .getLocalServiceRegistry()
                  .registerService(dispatcher, serviceDescriptor);
         }
      
         public IServerEndpoint getServerEndpoint() {
            return _serverEndpoint;
         }
      
         @Override
         public void close() throws «typeResolver.resolve("java.lang.Exception")» {
            _serviceRegistration.unregisterService();
            _serverEndpoint.close();
         }
      }
      '''
   }
   
   def private String generateServerRunnerProgram(String class_name, String server_runner_class_name, String beans_name, String log4j_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val resources_location = MavenArtifactType.TEST_RESOURCES.directoryLayout
      
      '''
      public class «class_name» {
         
         private static String _connectionString;
         private static «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» _serverEndpoint;
         private static «server_runner_class_name» _serverRunner;
         private static final «typeResolver.resolve("org.apache.log4j.Logger")» logger = Logger.getLogger(Program.class);
         private static String _file;
         
         public static void main(String[] args) {
            
            «typeResolver.resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);
            // Parse Parameters
            int i = 0;
            while (i < args.length && args[i].startsWith("-")) {
               if (args[i].equals("-connectionString") || args[i].equals("-c")) {
                  _connectionString = args[++i];
               } else if (args[i].equals("-file") || args[i].equals("-f"))
                  _file = args[++i];
               i++;
            }
            
            if (_file == null)
               _file = "«resources_location»/«beans_name»";
            
            //no parameters; help the user...
            if (i == 0) {
               System.out.println("Parameters:");
               System.out
                     .println("-connectionString or -c  required: set host and port (e.g. tcp://127.0.0.1:1234)");
               System.out.println("");
               System.out
                     .println("-file or -f              set springBeansFile for class of ServerFactory");
               System.out
                     .println("                         use: bean id=\"ServerFactory\";Instance of com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory");
               return;
            }
            
            logger.info("ConnectionString: " + _connectionString);
            
            @SuppressWarnings("resource")
            «typeResolver.resolve("org.springframework.context.ApplicationContext")» ctx = new «typeResolver.resolve("org.springframework.context.support.FileSystemXmlApplicationContext")»(_file);
            
            «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» _serverConnectionFactory = (IConnectionFactory) ctx
                  .getBean("ServerFactory", logger);
            
            try {
               _serverEndpoint = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ServerEndpointFactory")»(logger,_serverConnectionFactory).create(_connectionString);
               
               _serverRunner = new «server_runner_class_name»(_serverEndpoint);
               _serverRunner.registerService();
               
               System.out.println("Server listening at " + _connectionString);
               System.out.println("Press any key to close");
               System.in.read();
               
            } catch (Exception e) {
               logger.error("Exception thrown by ServerRunner", e);
            } finally {
               if (_serverEndpoint != null)
                  try {
                     _serverEndpoint.close();
                  } catch («typeResolver.resolve("java.lang.Exception")» e) {
                     logger.warn("Exception close by ServerRunner", e);
                  }
            }
            
            return;
         }
      }
      '''
   }
   
   def private void generateProxy(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      val proxy_factory_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name) + "Factory"
      file_system_access.generateFile(src_root_path + proxy_factory_name.java,
         generateSourceFile(interface_declaration, generateProxyFactory(proxy_factory_name, interface_declaration))
      )

      reinitializeFile
      val proxy_class_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      file_system_access.generateFile(
         src_root_path + proxy_class_name.java,
         generateSourceFile(interface_declaration, generateProxyImplementation(proxy_class_name, interface_declaration))
      )
   }
   
   def private String generateProxyImplementation(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val anonymous_event = Util.getAnonymousEvent(interface_declaration)
      val api_name = typeResolver.resolve(interface_declaration)
      val protobuf_request = resolveProtobuf(basicJavaSourceGenerator, interface_declaration, Optional.of(ProtobufType.REQUEST))
      val protobuf_response = resolveProtobuf(basicJavaSourceGenerator, interface_declaration, Optional.of(ProtobufType.RESPONSE))

      '''
      public class «class_name» implements «api_name» {
         
         private final «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» _endpoint;
         private final «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceReference")» _serviceReference;
         private final «typeResolver.resolve("com.btc.cab.servicecomm.serialization.IMessageBufferSerializer")» _serializer;
         
         public «class_name»(IClientEndpoint endpoint) throws Exception {
            _endpoint = endpoint;

            _serviceReference = _endpoint
               .connectService(«api_name».TypeGuid);

            _serializer = new «typeResolver.resolve("com.btc.cab.servicecomm.serialization.SinglePartMessageBufferSerializer")»(new «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtobufSerializer")»());

            // ServiceFaultHandler
            _serviceReference
               .getServiceFaultHandlerManager()
               .registerHandler(«typeResolver.resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.SERVICE_API)) + '''.«interface_declaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
         }
         
         «FOR function : interface_declaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
            «val is_void = function.returnedType.isVoid»
            «val is_sync = function.sync»
            «val return_type = (if (is_void) "Void" else basicJavaSourceGenerator.toText(function.returnedType) )»
            «val out_params = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
            /**
               @see «api_name.fullyQualifiedName»#«function.name.toFirstLower»
            */
            @Override
            public «makeInterfaceMethodSignature(function)» {
               «val request_message = protobuf_request + Constants.SEPARATOR_PACKAGE + Util.asRequest(function.name)»
               «val response_message = protobuf_response + Constants.SEPARATOR_PACKAGE + Util.asResponse(function.name)»
               «val response_name = '''response«function.name»'''»
               «val protobuf_function_name = function.name.asProtobufName»
               «request_message» request«function.name» = 
                  «request_message».newBuilder()
                  «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                     «val use_codec = GeneratorUtil.useCodec(param.paramType, param_bundle.artifactNature)»
                     «var codec = resolveCodec(param.paramType)»
                     «val is_sequence = Util.isSequenceType(param.paramType)»
                     «val is_failable = is_sequence && Util.isFailable(param.paramType)»
                     «val method_name = '''«IF is_sequence»addAll«ELSE»set«ENDIF»«param.paramName.asProtobufName»'''»
                     .«method_name»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(basicJavaSourceGenerator, param.paramType, Optional.empty)») «ENDIF»«codec».encode«IF is_failable»Failable«ENDIF»(«ENDIF»«param.paramName»«IF is_failable», «resolveFailableProtobufType(param.paramType, interface_declaration)».class«ENDIF»«IF use_codec»)«ENDIF»)
                  «ENDFOR»
                  .build();
               
               «protobuf_request» request = «protobuf_request».newBuilder()
                 .set«protobuf_function_name»«Constants.PROTOBUF_REQUEST»(request«function.name»)
                 .build();
               
               «typeResolver.resolve("java.util.concurrent.Future")»<byte[]> requestFuture = «typeResolver.resolve("com.btc.cab.servicecomm.util.ClientEndpointExtensions")».RequestAsync(_endpoint, _serviceReference, _serializer, request);
               «typeResolver.resolve("java.util.concurrent.Callable")»<«return_type»> returnCallable = () -> {
                   byte[] bytes = requestFuture.get();
                   «protobuf_response» response = «protobuf_response».parseFrom(bytes);
                     «IF !is_void || !out_params.empty»«response_message» «response_name» = «ENDIF»response.get«protobuf_function_name»«Constants.PROTOBUF_RESPONSE»();
                     «IF !out_params.empty»
                        
                        // handle [out] parameters
                        «FOR out_param : out_params»
                           «val codec = resolveCodec(out_param.paramType)»
                           «val temp_param_name = '''_«out_param.paramName.toFirstLower»'''»
                           «val param_name = out_param.paramName.asParameter»
                           «IF !Util.isSequenceType(out_param.paramType)»
                              «val out_param_type = basicJavaSourceGenerator.toText(out_param.paramType)»
                              «out_param_type» «temp_param_name» = («out_param_type») «codec».decode( «response_name».get«out_param.paramName.asProtobufName»() );
                              «handleOutputParameter(out_param, temp_param_name, param_name)»
                           «ELSE»
                              «val is_failable = Util.isFailable(out_param.paramType)»
                              «typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«basicJavaSourceGenerator.toText(Util.getUltimateType(out_param.paramType))»«IF is_failable»>«ENDIF»> «temp_param_name» = «codec».decode«IF is_failable»Failable«ENDIF»( «response_name».get«out_param.paramName.asProtobufName»List() );
                              «param_name».addAll( «temp_param_name» );
                           «ENDIF»
                           
                        «ENDFOR»
                     «ENDIF»
                     «val codec = resolveCodec(function.returnedType)»
                     «val is_byte = Util.isByte(function.returnedType)»
                     «val is_short = Util.isInt16(function.returnedType)»
                     «val is_char = Util.isChar(function.returnedType)»
                     «val use_codec = GeneratorUtil.useCodec(function.returnedType, param_bundle.artifactNature)»
                     «val is_sequence = Util.isSequenceType(function.returnedType)»
                     «val is_failable = is_sequence && Util.isFailable(function.returnedType)»
                     «IF is_sequence»
                        «return_type» result = «codec».decode«IF is_failable»Failable«ENDIF»(«response_name».get«protobuf_function_name»List());
                     «ELSEIF is_void»
                        return null; // it's a Void!
                     «ELSE»
                        «return_type» result = «IF use_codec»(«return_type») «codec».decode(«ENDIF»«IF is_byte || is_short || is_char»(«IF is_byte»byte«ELSEIF is_char»char«ELSE»short«ENDIF») «ENDIF»«response_name».get«protobuf_function_name»()«IF use_codec»)«ENDIF»;
                     «ENDIF»
                     «IF !is_void»return result;«ENDIF»
                  };

               «IF !is_void || !is_sync»return «ENDIF»«typeResolver.resolve("com.btc.cab.commons.helper.AsyncHelper")».createAndRunFutureTask(returnCallable)«IF is_sync».get()«ENDIF»;
            }
         «ENDFOR»
         
         «IF anonymous_event !== null»
            «IF anonymous_event.keys.empty»
               «val event_type_name = typeResolver.resolve(anonymous_event.data)»
               /**
                  @see com.btc.cab.commons.IObservable#subscribe
               */
               @Override
               public «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«typeResolver.resolve(anonymous_event.data)»> observer) throws Exception {
                  _endpoint.getEventRegistry().createEventRegistration(
                        «event_type_name».EventTypeGuid,
                        «typeResolver.resolve("com.btc.cab.servicecomm.api.EventKind")».EVENTKINDPUBLISHSUBSCRIBE,
                        «event_type_name».EventTypeGuid.toString());
                  return «typeResolver.resolve("com.btc.cab.servicecomm.util.EventRegistryExtensions")».subscribe(_endpoint.getEventRegistry()
                        .getSubscriberManager(), _serializerDeserializer,
                        «event_type_name».EventTypeGuid,
                        EventKind.EVENTKINDPUBLISHSUBSCRIBE, observer);
               }
             «ELSE»
               /**
                  @see ???
               */
               public «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«typeResolver.resolve(anonymous_event.data)»> observer, Iterable<KeyType> keys) throws Exception {
                  «makeDefaultMethodStub»
               }
            «ENDIF»
         «ENDIF»
         «FOR event : interface_declaration.contains.filter(EventDeclaration).filter[name !== null]»
            «val observable_name = basicJavaSourceGenerator.toText(event)»
            /**
               @see «api_name»#get«observable_name»
            */
            @Override
            public «observable_name» get«observable_name»() {
               «makeDefaultMethodStub»
            }
         «ENDFOR»
      }
      '''
   }
   
   def private String handleOutputParameter(ParameterElement element, String source_name, String target_name)
   {
      val ultimate_type = Util.getUltimateType(element.paramType)
      if ( !(ultimate_type instanceof StructDeclaration) )
         throw new IllegalArgumentException("In Java generator, only structs are supported as output parameters!")
      
      '''
      «FOR member : (ultimate_type as StructDeclaration).allMembers»
         «val member_name = member.name.toFirstUpper»
         «target_name».set«member_name»( «source_name».get«member_name»() );
      «ENDFOR»
      '''
   }
   
   def private String generateProxyFactory(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val api_type = typeResolver.resolve(interface_declaration)
      
      '''
      public class «class_name» {
         
         public static «api_type» createDirectProtobufProxy(«typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» endpoint) throws Exception
         {
            return new «GeneratorUtil.getClassName(param_bundle.build, ProjectType.PROXY, interface_declaration.name)»(endpoint);
         }
      }
      '''
   }
   
   def private void generateDispatcher(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val dispatcher_class_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      val api_class_name = typeResolver.resolve(interface_declaration)
      
      val protobuf_request = resolveProtobuf(basicJavaSourceGenerator, interface_declaration, Optional.of(ProtobufType.REQUEST))
      val protobuf_response = resolveProtobuf(basicJavaSourceGenerator, interface_declaration, Optional.of(ProtobufType.RESPONSE))
      
      file_system_access.generateFile(
         src_root_path + dispatcher_class_name.java,
         generateSourceFile(interface_declaration,
         '''
         public class «dispatcher_class_name» implements «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceDispatcher")» {
            
            private final «api_class_name» _dispatchee;

            private final «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtoBufServerHelper")» _protoBufHelper;

            private final «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceFaultHandlerManager")» _faultHandlerManager;
            
            public «dispatcher_class_name»(«api_class_name» dispatchee, ProtoBufServerHelper protoBufHelper) {
               _dispatchee = dispatchee;
               _protoBufHelper = protoBufHelper;

               // ServiceFaultHandlerManager
               _faultHandlerManager = new «typeResolver.resolve("com.btc.cab.servicecomm.faulthandling.ServiceFaultHandlerManager")»();
         
               // ServiceFaultHandler
               _faultHandlerManager.registerHandler(«typeResolver.resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.SERVICE_API)) + '''.«interface_declaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
            }
            
            /**
               @see com.btc.cab.servicecomm.api.IServiceDispatcher#processRequest
            */
            @Override
            public «typeResolver.resolve("com.btc.cab.servicecomm.common.IMessageBuffer")» processRequest(
               IMessageBuffer requestBuffer, «typeResolver.resolve("com.btc.cab.servicecomm.common.IPeerIdentity")» peerIdentity, «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» serverEndpoint) throws Exception {
               
               byte[] requestByte = _protoBufHelper.deserializeRequest(requestBuffer);
               «protobuf_request» request
                  = «protobuf_request».parseFrom(requestByte);
               
               «FOR function : interface_declaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
                  «val is_sync = function.isSync»
                  «val is_void = function.returnedType.isVoid»
                  «val result_type = typeResolver.resolve(function.returnedType)»
                  «val result_is_sequence = Util.isSequenceType(function.returnedType)»
                  «val result_is_failable = result_is_sequence && Util.isFailable(function.returnedType)»
                  «val result_use_codec = GeneratorUtil.useCodec(function.returnedType, param_bundle.artifactNature) || result_is_failable»
                  «var result_codec = resolveCodec(function.returnedType)»
                  «val request_method_name = function.name.asProtobufName + "Request"»
                  «val response_method_name = '''«protobuf_response».«Util.asResponse(function.name)»'''»
                  if (request.has«request_method_name»()) {
                     «val out_params = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                     «IF !out_params.empty»
                        // prepare [out] parameters
                        «FOR param : out_params»
                           «val is_sequence = Util.isSequenceType(param.paramType)»
                           «val is_failable = is_sequence && Util.isFailable(param.paramType)»
                           «IF is_sequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«typeResolver.resolve(Util.getUltimateType(param.paramType))»«IF is_failable»>«ENDIF»>«ELSE»«typeResolver.resolve(param.paramType)»«ENDIF» «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
                        «ENDFOR»
                     «ENDIF»
                     
                     // call actual method
                     «IF !is_void»«IF result_is_sequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF result_is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«typeResolver.resolve(Util.getUltimateType(function.returnedType))»«IF result_is_failable»>«ENDIF»>«ELSE»«result_type»«ENDIF» result = «ENDIF»_dispatchee.«function.name.asMethod»
                     (
                        «FOR param : function.parameters SEPARATOR ","»
                           «val plain_type = typeResolver.resolve(param.paramType)»
                           «val is_byte = Util.isByte(param.paramType)»
                           «val is_short = Util.isInt16(param.paramType)»
                           «val is_char = Util.isChar(param.paramType)»
                           «val is_input = (param.direction == ParameterDirection.PARAM_IN)»
                           «val use_codec = GeneratorUtil.useCodec(param.paramType, param_bundle.artifactNature)»
                           «var codec = resolveCodec(param.paramType)»
                           «val is_sequence = Util.isSequenceType(param.paramType)»
                           «IF is_input»«IF use_codec»«IF !is_sequence»(«plain_type») «ENDIF»«codec».decode(«ENDIF»«IF is_byte || is_short || is_char»(«IF is_byte»byte«ELSEIF is_char»char«ELSE»short«ENDIF») «ENDIF»request.get«request_method_name»().get«param.paramName.asProtobufName»«IF is_sequence»List«ENDIF»()«IF use_codec»)«ENDIF»«ELSE»«param.paramName.asParameter»«ENDIF»
                        «ENDFOR»
                     )«IF !is_sync».get();«IF is_void» // retrieve the result in order to trigger exceptions«ENDIF»«ELSE»;«ENDIF»
                     
                     // deliver response
                     «response_method_name» methodResponse
                        = «response_method_name».newBuilder()
                        «IF !is_void».«IF result_is_sequence»addAll«function.name.asProtobufName»«ELSE»set«function.name.asProtobufName»«ENDIF»(«IF result_use_codec»«IF !result_is_sequence»(«resolveProtobuf(basicJavaSourceGenerator, function.returnedType, Optional.empty)»)«ENDIF»«result_codec».encode«IF result_is_failable»Failable«ENDIF»(«ENDIF»result«IF result_is_failable», «resolveFailableProtobufType(function.returnedType, interface_declaration)».class«ENDIF»«IF result_use_codec»)«ENDIF»)«ENDIF»
                        «FOR out_param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                           «val is_sequence = Util.isSequenceType(out_param.paramType)»
                           «val is_failable = is_sequence && Util.isFailable(out_param.paramType)»
                           «val use_codec = GeneratorUtil.useCodec(out_param.paramType, param_bundle.artifactNature) || is_failable»
                           «val codec = resolveCodec(out_param.paramType)»
                           .«IF is_sequence»addAll«out_param.paramName.asProtobufName»«ELSE»set«out_param.paramName.asProtobufName»«ENDIF»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(basicJavaSourceGenerator, out_param.paramType, Optional.empty)») «ENDIF»«codec».encode«IF is_failable»Failable«ENDIF»(«ENDIF»«out_param.paramName.asParameter»«IF is_failable», «resolveFailableProtobufType(out_param.paramType, interface_declaration)».class«ENDIF»«IF use_codec»)«ENDIF»)
                        «ENDFOR»
                        .build();
                     
                     «protobuf_response» response
                        = «protobuf_response».newBuilder()
                        .set«function.name.asProtobufName»Response(methodResponse)
                        .build();
                     
                     return _protoBufHelper.serializeResponse(response);
                  }
               «ENDFOR»
               
               // request could not be processed
               throw new «typeResolver.resolve("com.btc.cab.servicecomm.api.exceptions.InvalidMessageReceivedException")»("Unknown or invalid request");
            }

            /**
               @see com.btc.cab.servicecomm.api.IServiceDispatcher#getServiceFaultHandlerManager
            */
            @Override
            public IServiceFaultHandlerManager getServiceFaultHandlerManager() {
               return _faultHandlerManager;
            }
         }
         '''
         )
      )
   }
   
   def private void generateImpl(String src_root_path, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      val impl_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)
      val api_name = typeResolver.resolve(interface_declaration)
      
      file_system_access.generateFile(src_root_path + impl_name.java,
         generateSourceFile(interface_declaration,
         '''
         public class «impl_name» implements «api_name» {
            
            «FOR function : interface_declaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
               /**
                  @see «api_name.fullyQualifiedName»#«function.name.toFirstLower»
               */
               @Override
               public «makeInterfaceMethodSignature(function)» {
                  «makeDefaultMethodStub»
               }
            «ENDFOR»
            
            «FOR event : interface_declaration.contains.filter(EventDeclaration).filter[name !== null]»
               «val observable_name = basicJavaSourceGenerator.toText(event)»
               /**
                  @see «api_name»#get«observable_name»
               */
               @Override
               public «observable_name» get«observable_name»() {
                  «makeDefaultMethodStub»
               }
            «ENDFOR»
         }
         '''
         )
      )
   }
   
   // TODO remove this function
   def private void reinitializeFile()
   {
      typeResolver = new TypeResolver(qualified_name_provider, param_bundle, dependencies)
      basicJavaSourceGenerator = new BasicJavaSourceGenerator(qualified_name_provider, typeResolver, idl)
   }
   
   def private void reinitializeAll()
   {
      reinitializeFile
      dependencies.clear
   }
   
   def private static String makeDefaultMethodStub()
   {
      '''
      // TODO Auto-generated method stub
      throw new UnsupportedOperationException("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»");
      '''
   }
   
   def private String makeDefaultValue(EObject element)
   {
      if (element instanceof PrimitiveType)
      {
         if (element.isString)
            return '''""'''
         else if (element.isUUID)
            return '''«typeResolver.resolve(JavaClassNames.UUID)».randomUUID()'''
         else if (element.isBoolean)
            return "false"
         else if (element.isChar)
            return "'\\u0000'"
         else if (element.isDouble)
            return "0D"
         else if (element.isFloat)
            return "0F"
         else if (element.isInt64)
            return "0L"
         else if (element.isByte)
            return "Byte.MIN_VALUE"
         else if (element.isInt16)
            return "Short.MIN_VALUE"
      }
      else if (element instanceof AliasDeclaration)
      {
         return makeDefaultValue(element.type)
      }
      else if (element instanceof AbstractType)
      {
         if (element.referenceType !== null)
            return makeDefaultValue(element.referenceType)
         else if (element.primitiveType !== null)
            return makeDefaultValue(element.primitiveType)
         else if (element.collectionType !== null)
            return makeDefaultValue(element.collectionType)
      }
      else if (element instanceof SequenceDeclaration)
      {
         val type = basicJavaSourceGenerator.toText(element.type)
         val is_failable = element.failable
         // TODO this should better use Collections.emptyList
         return '''new «typeResolver.resolve("java.util.Vector")»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«type»«IF is_failable»>«ENDIF»>()'''
      }
      else if (element instanceof StructDeclaration)
      {
         return '''new «typeResolver.resolve(element)»(«FOR member : element.allMembers SEPARATOR ", "»«IF member.optional»«typeResolver.resolve(JavaClassNames.OPTIONAL)».empty()«ELSE»«makeDefaultValue(member.type)»«ENDIF»«ENDFOR»)'''
      }
      else if (element instanceof EnumDeclaration)
      {
         return '''«basicJavaSourceGenerator.toText(element)».«element.containedIdentifiers.head»''';
      }
      
      return '''0'''
   }
      
   def private String resolveFailableProtobufType(EObject element, EObject container)
   {
       resolveFailableProtobufType(qualified_name_provider, element, container)
   }
}
