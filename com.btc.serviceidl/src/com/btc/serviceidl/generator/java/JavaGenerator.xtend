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
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
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
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.ReturnTypeElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import java.util.ArrayList
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider
import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.ProtobufType
import java.util.Optional
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.Collection
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.util.Util
import com.btc.serviceidl.generator.common.GeneratorUtil
import java.util.Set
import com.google.common.collect.Sets
import java.util.Arrays

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
   
   private val typedef_table = new HashMap<String, ResolvedName>
   private val referenced_types = new HashSet<String>
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

         val activeProjectTypes = Sets.intersection(projectTypes, 
			new HashSet<ProjectType>(Arrays.asList(ProjectType.SERVICE_API, ProjectType.IMPL, ProjectType.PROTOBUF, ProjectType.PROXY,
				ProjectType.DISPATCHER, ProjectType.TEST, ProjectType.SERVER_RUNNER, ProjectType.CLIENT_CONSOLE  
			)))
		 for (projectType : activeProjectTypes)
		 {
		   generateProject(projectType, interface_declaration)
		 }

         if (!activeProjectTypes.empty)
           generatePOM(interface_declaration)
      }
   }

   def private void generatePOM(EObject container)
   {
      val pom_path = makeProjectRootPath(container) + "pom".xml
      file_system_access.generateFile(pom_path, generatePOMContents(container))
   }

   def private String makeProjectRootPath(EObject container)
   {
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

   def private String generatePOMContents(EObject container)
   {
      val root_name = MavenResolver.resolvePackage(container, Optional.empty)
      val version = MavenResolver.resolveVersion(container)
      
      '''
      <project xmlns="http://maven.apache.org/POM/4.0.0"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                                   http://maven.apache.org/xsd/maven-4.0.0.xsd">

         <modelVersion>4.0.0</modelVersion>

         <groupId>«root_name»</groupId>
         <artifactId>«root_name»</artifactId>
         <version>«version»</version>

         <properties>
            <!-- ServiceComm properties -->
            <servicecomm.version>0.3.0</servicecomm.version>
            
            <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
            <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
            
            <maven.compiler.source>1.8</maven.compiler.source>
            <maven.compiler.target>1.8</maven.compiler.target>
            
            <!-- directory for files generated by the protoc compiler (default = /src/main/java) -->
            <protobuf.outputDirectory>${project.build.sourceDirectory}</protobuf.outputDirectory>
            <!-- *.proto source files (default = /src/main/proto) -->
            <protobuf.sourceDirectory>${basedir}/src/main/proto</protobuf.sourceDirectory>
            <!-- directory containing the protoc executable (default = %PROTOC_HOME% environment variable) -->
            <protobuf.binDirectory>${PROTOC_HOME}</protobuf.binDirectory>
         </properties>
         
         <repositories>
            <repository>
               <id>cab-maven-resolver</id>
               <url>http://artifactory.inf.bop/artifactory/cab-maven-resolver//</url>
               <releases>
                  <enabled>true</enabled>
               </releases>
               <snapshots>
                   <enabled>false</enabled>
               </snapshots>
            </repository>
         </repositories>
         
         <distributionManagement>
            <repository>
               <id>cab-maven</id>
               <name>CAB Main Maven Repository</name>
               <url>http://artifactory.inf.bop/artifactory/cab-maven/</url>
            </repository>
         </distributionManagement>
         
         <dependencies>
            «FOR dependency : dependencies.filter[ artifactId != root_name ]»
            <dependency>
               <groupId>«dependency.groupId»</groupId>
               <artifactId>«dependency.artifactId»</artifactId>
               <version>«dependency.version»</version>
               «IF dependency.scope !== null»
                  <scope>«dependency.scope»</scope>
               «ENDIF»
            </dependency>
            «ENDFOR»
         </dependencies>

         <build>
            <pluginManagement>
               <plugins>
                  <plugin>
                     <groupId>org.eclipse.m2e</groupId>
                     <artifactId>lifecycle-mapping</artifactId>
                     <version>1.0.0</version>
                     <configuration>
                        <lifecycleMappingMetadata>
                           <pluginExecutions>
                              <pluginExecution>
                                 <pluginExecutionFilter>
                                    <groupId>org.apache.maven.plugins</groupId>
                                    <artifactId>maven-antrun-plugin</artifactId>
                                    <versionRange>[1.0.0,)</versionRange>
                                    <goals>
                                       <goal>run</goal>
                                    </goals>
                                 </pluginExecutionFilter>
                                 <action>
                                    <execute />
                                 </action>
                              </pluginExecution>
                           </pluginExecutions>
                        </lifecycleMappingMetadata>
                     </configuration>
                  </plugin>
               </plugins>
            </pluginManagement>
            <plugins>
               <plugin>
                  <groupId>org.apache.maven.plugins</groupId>
                  <artifactId>maven-antrun-plugin</artifactId>
                  <version>1.8</version>
                  <executions>
                     <execution>
                        <id>generate-sources</id>
                        <phase>generate-sources</phase>
                        <configuration>
                           <target>
                              <mkdir dir="${protobuf.outputDirectory}" />
                              <exec executable="${protobuf.binDirectory}/protoc">
                                 <arg value="--java_out=${protobuf.outputDirectory}" />
                                 <arg value="-I=${basedir}\.." />
                                 <arg value="--proto_path=${protobuf.sourceDirectory}" />
                                 «IF protobuf_artifacts.containsKey(container)»
                                    <arg value="${protobuf.sourceDirectory}/«protobuf_artifacts.get(container)».proto" />
                                 «ENDIF»
                              </exec> 
                           </target>
                        </configuration>
                        <goals>
                           <goal>run</goal>
                        </goals>
                     </execution>
                  </executions>
               </plugin>
               <plugin>
                  <groupId>org.apache.maven.plugins</groupId>
                  <artifactId>maven-compiler-plugin</artifactId>
                  <version>3.3</version>
                  <configuration>
                     <source>1.8</source>
                     <target>1.8</target>
                  </configuration>
               </plugin>
            </plugins>
         </build>

      </project>
      '''
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
      
      «FOR reference : referenced_types.sort AFTER System.lineSeparator»
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
         file_system_access.generateFile(src_root_path + Names.plain(element).java, generateSourceFile(module, toDeclaration(element)))
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
            type_name = resolve(type_alias.type)
            typedef_table.put(type_alias.name, type_name)
         }
      }
      
      // generate all contained types
      for (abstract_type : interface_declaration.contains.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)])
      {
         val file_name = Names.plain(abstract_type)
         reinitializeFile
         file_system_access.generateFile(src_root_path + file_name.java, generateSourceFile(interface_declaration, toDeclaration(abstract_type)))
      }
      
      // generate named events
      for (event : interface_declaration.contains.filter(EventDeclaration).filter[name !== null])
      {
         reinitializeFile
         file_system_access.generateFile(src_root_path + toText(event).java, generateSourceFile(interface_declaration, generateEvent(event)))
      }
      
      reinitializeFile
      file_system_access.generateFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name).java,
      generateSourceFile(interface_declaration,
      '''
      public interface «param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)»«IF anonymous_event !== null» extends «resolve("com.btc.cab.commons.IObservable")»<«toText(anonymous_event.data)»>«ENDIF» {

         «resolve("java.util.UUID")» TypeGuid = UUID.fromString("«GuidMapper.get(interface_declaration)»");
         
         «FOR function : interface_declaration.functions»
            «makeInterfaceMethodSignature(function)»;
            
         «ENDFOR»
         
         «FOR event : interface_declaration.events.filter[name !== null]»
            «val observable_name = toText(event)»
            «observable_name» get«observable_name»();
         «ENDFOR»
      }
      '''))
      
      // common service fault handler factory
      reinitializeFile
      val service_fault_handler_factory_name = interface_declaration.asServiceFaultHandlerFactory
      file_system_access.generateFile(src_root_path + param_bundle.projectType.getClassName(param_bundle.artifactNature, service_fault_handler_factory_name).java,
         generateSourceFile( interface_declaration, generateServiceFaultHandlerFactory(service_fault_handler_factory_name, interface_declaration ))
      )
   }
   
   def private String generateServiceFaultHandlerFactory(String class_name, EObject container)
   {
      val service_fault_handler = resolve("com.btc.cab.servicecomm.faulthandling.DefaultServiceFaultHandler")
      val i_error = resolve("com.btc.cab.servicecomm.api.IError")
      val optional = resolve("java.util.Optional")
      val raised_exceptions = Util.getRaisedExceptions(container)
      val failable_exceptions = Util.getFailableExceptions(container)
      
      // merge both collections to avoid duplicate entries
      val exceptions = new HashSet<AbstractException>
      exceptions.addAll(raised_exceptions)
      exceptions.addAll(failable_exceptions)
      
      '''
      public class «class_name»
      {
         private static final «resolve("org.apache.commons.collections4.BidiMap")»<String, Exception> errorMap = new «resolve("org.apache.commons.collections4.bidimap.DualHashBidiMap")»<>();
         
         static
         {
            «FOR exception : exceptions.sortBy[name]»
               errorMap.put("«Util.getCommonExceptionName(exception, qualified_name_provider)»", new «resolve(exception)»());
            «ENDFOR»
            
            // most commonly used exception types
            errorMap.put("«Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER»", new IllegalArgumentException());
            errorMap.put("«Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER»", new UnsupportedOperationException());
         }
         
         public static final «resolve("com.btc.cab.servicecomm.api.IServiceFaultHandler")» createServiceFaultHandler()
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
                  «resolve("java.lang.reflect.Constructor")»<?> constructor = exception.getClass().getConstructor(String.class);
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
            «i_error» error = new «resolve("com.btc.cab.servicecomm.faulthandling.ErrorMessage")»(
                exception.getMessage(),
                errorType.isPresent() ? errorType.get() : exception.getClass().getName(),
                «resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getStackTrace(exception));
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
         generateLog4jProperties()
      )
   }
   
   def private String generateFileImplTest(String class_name, String super_class, InterfaceDeclaration interface_declaration)
   {
      '''
      public class «class_name» extends «super_class» {
      
         «resolve("org.junit.Before").alias("@Before")»
         public void setUp() throws Exception {
            super.setUp();
            testSubject = new «resolve(interface_declaration, ProjectType.IMPL)»();
         }
      }
      '''
   }
   
   def private String generateFileTest(String class_name, String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val api_class = resolve(interface_declaration)
      val junit_assert = resolve("org.junit.Assert")
      
      '''
      «resolve("org.junit.Ignore").alias("@Ignore")»
      public abstract class «class_name» {
      
         protected «api_class» testSubject;
      
         «resolve("org.junit.BeforeClass").alias("@BeforeClass")»
         public static void setUpBeforeClass() throws Exception {
         }
      
         «resolve("org.junit.AfterClass").alias("@AfterClass")»
         public static void tearDownAfterClass() throws Exception {
         }
      
         «resolve("org.junit.Before").alias("@Before")»
         public void setUp() throws Exception {
         }
      
         «resolve("org.junit.After").alias("@After")»
         public void tearDown() throws Exception {
         }

         «FOR function : interface_declaration.functions»
            «val is_sync = function.sync»
            «resolve("org.junit.Test").alias("@Test")»
            public void «function.name.asMethod»Test() throws Exception
            {
               boolean _success = false;
               «FOR param : function.parameters»
                  «toText(param.paramType)» «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
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
         
         public «resolve(interface_declaration)» getTestSubject() {
            return testSubject;
         }
         
         private boolean _assertExceptionType(Throwable e)
         {
            if (e == null)
               return false;
            
            if (e instanceof UnsupportedOperationException)
                return (e.getMessage() != null && e.getMessage().equals("Auto-generated method stub is not implemented!"));
            else
               return _assertExceptionType(«resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getRootCause(e));
         }
      }
      '''
   }
   
   def private String generateFileZeroMQItegrationTest(String class_name, String super_class, String log4j_name, String src_root_path, InterfaceDeclaration interface_declaration)
   {
      val resources_location = MavenArtifactType.TEST_RESOURCES.directoryLayout
      val junit_assert = resolve("org.junit.Assert")
      val server_runner_name = resolve(interface_declaration, ProjectType.SERVER_RUNNER)
      
      '''
      public class «class_name» extends «super_class» {
      
         private final static String connectionString = "tcp://127.0.0.1:«Constants.DEFAULT_PORT»";
         private static final «resolve("org.apache.log4j.Logger")» logger = Logger.getLogger(«class_name».class);
         
         private «resolve("com.btc.cab.servicecomm.api.IServerEndpoint")» _serverEndpoint;
         private «resolve("com.btc.cab.servicecomm.api.IClientEndpoint")» _clientEndpoint;
         private «server_runner_name» _serverRunner;
         
         public «class_name»() {
         }
         
         «resolve("org.junit.Before").alias("@Before")»
         public void setupEndpoints() throws Exception {
            super.setUp();
      
            «resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);
      
            // Start Server
            try {
               «resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqServerConnectionFactory")» _serverConnectionFactory = new ZeroMqServerConnectionFactory(logger);
               _serverEndpoint = new «resolve("com.btc.cab.servicecomm.singlequeue.core.ServerEndpointFactory")»(logger, _serverConnectionFactory).create(connectionString);
               _serverRunner = new «server_runner_name»(_serverEndpoint);
               _serverRunner.registerService();
      
               logger.debug("Server started...");
               
               // start client
               «resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» connectionFactory = new «resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqClientConnectionFactory")»(
                     logger);
               _clientEndpoint = new «resolve("com.btc.cab.servicecomm.singlequeue.core.ClientEndpointFactory")»(logger, connectionFactory).create(connectionString);
      
               logger.debug("Client started...");
               testSubject = «resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.PROXY)) + '''.«interface_declaration.name»ProxyFactory''')»
                     .createDirectProtobufProxy(_clientEndpoint);
      
               logger.debug("«interface_declaration.name» instantiated...");
               
            } catch (Exception e) {
               logger.error("Error on start: ", e);
               «junit_assert».fail(e.getMessage());
            }
         }
      
         «resolve("org.junit.After").alias("@After")»
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
      «IF !is_sync»«resolve("java.util.concurrent.Future")»<«ENDIF»«IF !is_sync && is_void»Void«ELSE»«toText(function.returnedType)»«ENDIF»«IF !function.isSync»>«ENDIF» «function.name.toFirstLower»(
         «FOR param : function.parameters SEPARATOR ","»
            «IF param.direction == ParameterDirection.PARAM_IN»final «ENDIF»«toText(param.paramType)» «toText(param)»
         «ENDFOR»
      ) throws«FOR exception : function.raisedExceptions SEPARATOR ',' AFTER ','» «toText(exception)»«ENDFOR» Exception'''
   }
   
   def private String generateEvent(EventDeclaration event)
   {
      reinitializeFile
      
      val keys = new ArrayList<Pair<String, String>>
      for (key : event.keys)
      {
         keys.add(Pair.of(key.keyName, toText(key.type)))
      }

      '''
      public abstract class «toText(event)» implements «resolve("com.btc.cab.commons.IObservable")»<«toText(event.data)»> {
         
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
                  «makeGetter(key.value, key.key)»
               «ENDFOR»
            }
            
            public abstract «resolve("java.io.Closeable")» subscribe(«resolve("com.btc.cab.commons.IObserver")»<«toText(event.data)»> subscriber, Iterable<KeyType> keys);
         «ENDIF»
      }
      '''
   }
   
   def private void generateProtobuf(String src_root_path, EObject container)
   {
      reinitializeFile
      param_bundle.reset(ProjectType.PROTOBUF)
      
      // collect all used data types to avoid duplicates
      val data_types = GeneratorUtil.getEncodableTypes(container)
      
      val java_uuid = resolve("java.util.UUID")
      val byte_string = resolve("com.google.protobuf.ByteString")
      val byte_buffer = resolve("java.nio.ByteBuffer")
      val i_error = resolve("com.btc.cab.servicecomm.api.IError")
      val service_fault_handler_factory = resolve(MavenResolver.resolvePackage(container, Optional.of(container.mainProjectType)) + "." + container.asServiceFaultHandlerFactory)
      val completable_future = resolve("java.util.concurrent.CompletableFuture")
      val method = resolve("java.lang.reflect.Method")
      val collection = resolve("java.util.Collection")
      val collectors = resolve("java.util.stream.Collectors")
      
      val codec_name = param_bundle.projectType.getClassName(param_bundle.artifactNature, if (container instanceof InterfaceDeclaration) container.name else Constants.FILE_NAME_TYPES) + "Codec"
      file_system_access.generateFile(src_root_path + codec_name.java, generateSourceFile(container,
         '''
         public class «codec_name» {
            
            private static «i_error» encodeException(Exception e)
            {
               Exception cause = (Exception) «resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getRootCause(e);
               return «service_fault_handler_factory».createError(cause);
            }
            
            private static Exception decodeException(String errorType, String message, String stackTrace)
            {
               return «service_fault_handler_factory».createException(errorType, message, stackTrace);
            }
            
            @SuppressWarnings("unchecked")
            public static<TOut, TIn> «collection»<TOut> encode(Collection<TIn> plainData) {
               return
                  plainData
                  .stream()
                  .map(item -> (TOut) encode(item))
                  .collect(«collectors».toList());
            }
            
            public static<TOut, TIn> «collection»<TOut> encodeFailable(«collection»<«completable_future»<TIn>> plainData, Class<TOut> targetType)
            {
               return
                  plainData
                  .stream()
                  .map(item -> encodeFailableWrapper(item, targetType) )
                  .collect(«collectors».toList());
            }
            
            private static<TOut, TIn> TOut encodeFailableWrapper(«completable_future»<TIn> failableData, Class<TOut> targetType)
            {
               try { return encodeFailable(failableData, targetType); }
               catch (Exception e) { throw new RuntimeException(e); }
            }
            
            @SuppressWarnings("unchecked")
            public static<TOut, TIn> «collection»<TOut> decode(«collection»<TIn> encodedData) {
               return
                  encodedData
                  .stream()
                  .map(item -> (item instanceof «byte_string») ? (TOut) decode( («byte_string») item) : (TOut) decode(item))
                  .collect(«collectors».toList());
            }
            
            public static «byte_string» encode(«java_uuid» plainData) {
               
               byte[] rawBytes = «byte_buffer».allocate(16)
                  .putLong(plainData.getMostSignificantBits())
                  .putLong(plainData.getLeastSignificantBits())
                  .array();

               return «byte_string».copyFrom( switchByteOrder(rawBytes) );
            }
            
            @SuppressWarnings( {"boxing", "unchecked"} )
            private static<TOut, TIn> TOut encodeFailable(«completable_future»<TIn> failableData, Class<TOut> targetType) throws Exception
            {
               if (failableData == null)
                  throw new NullPointerException();
            
               if (failableData.isCompletedExceptionally())
               {
                 try
                 {
                    failableData.get();
                 } catch (Exception e) // retrieve and encode underlying exception
                 {
                    «resolve("com.btc.cab.servicecomm.api.IError")» error = encodeException(e);
                    «method» newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
                    Object builder = newBuilderMethod.invoke(null);
                    «method» setExceptionMethod = builder.getClass().getDeclaredMethod("setException", String.class);
                    setExceptionMethod.invoke(builder, error.getServerErrorType());
                    «method» setMessageMethod = builder.getClass().getDeclaredMethod("setMessage", String.class);
                    setMessageMethod.invoke(builder, error.getMessage());
                    «method» setStacktraceMethod = builder.getClass().getDeclaredMethod("setStacktrace", String.class);
                    setStacktraceMethod.invoke(builder, error.getServerContextInformation());
                    «method» buildMethod = builder.getClass().getDeclaredMethod("build");
                    return (TOut) buildMethod.invoke(builder);
                 }
               }
               else
               {
                 TIn plainData = failableData.get();
                 «method» newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
                 Object builder = newBuilderMethod.invoke(null);
                 «method» getValueMethod = builder.getClass().getDeclaredMethod("getValue");
                 Class<?> paramType = getValueMethod.getReturnType();
                 «method» setValueMethod = builder.getClass().getDeclaredMethod("setValue", paramType);
                 setValueMethod.invoke(builder, encode( plainData ));
                 «method» buildMethod = builder.getClass().getDeclaredMethod("build");
                 return (TOut) buildMethod.invoke(builder);
               }
               
               throw new IllegalArgumentException("Unknown target type for encoding: " + targetType.getCanonicalName());
            }
            
            @SuppressWarnings("unchecked")
            public static<TOut, TIn> «collection»<«completable_future»<TOut>> decodeFailable(«collection»<TIn> encodedData)
            {
               return
                  encodedData
                  .stream()
                  .map( item -> («completable_future»<TOut>) decodeFailableWrapper(item) )
                  .collect(«collectors».toList());
            }
            
            private static<TOut, TIn> «completable_future»<TOut> decodeFailableWrapper(TIn encodedData)
            {
               try { return decodeFailable(encodedData); }
               catch (Exception e) { throw new RuntimeException(e); }
            }
            
            @SuppressWarnings( {"boxing", "unchecked"} )
            public static<TOut, TIn> «completable_future»<TOut> decodeFailable(TIn encodedData) throws Exception
            {
               if (encodedData == null)
                  throw new NullPointerException();
         
               «completable_future»<TOut> result = new «completable_future»<TOut>();
               
               «method» hasValueMethod = encodedData.getClass().getDeclaredMethod("hasValue");
               Boolean hasValue = (Boolean) hasValueMethod.invoke(encodedData);
               if (hasValue)
               {
                  «method» getValueMethod = encodedData.getClass().getDeclaredMethod("getValue");
                  Object value = getValueMethod.invoke(encodedData);
                  if (encodedData.getClass().getSimpleName().toLowerCase().endsWith("_uuid")) // it's a failable UUID: explicit handling
                     result.complete( (TOut) decode( («byte_string») value) );
                  else
                     result.complete( (TOut) decode(value) );
                  return result;
               }
               else
               {
                  «method» hasExceptionMethod = encodedData.getClass().getDeclaredMethod("hasException");
                  Boolean hasException = (Boolean) hasExceptionMethod.invoke(encodedData);
                  if (hasException)
                  {
                     «method» getExceptionMethod = encodedData.getClass().getDeclaredMethod("getException");
                     String errorType = getExceptionMethod.invoke(encodedData).toString();
                     «method» getMessageMethod = encodedData.getClass().getDeclaredMethod("getMessage");
                     String message = getMessageMethod.invoke(encodedData).toString();
                     «method» getStacktraceMethod = encodedData.getClass().getDeclaredMethod("getStacktrace");
                     String stackTrace = getStacktraceMethod.invoke(encodedData).toString();
                     result.completeExceptionally( decodeException(errorType, message, stackTrace) );
                     return result;
                  }
               }
               
               throw new IllegalArgumentException("Failed to decode the type: " + encodedData.getClass().getCanonicalName());
            }
            
            public static «java_uuid» decode(«byte_string» encodedData) {
               «byte_buffer» byteBuffer = «byte_buffer».wrap(switchByteOrder(encodedData.toByteArray()));
               return new «java_uuid»(byteBuffer.getLong(), byteBuffer.getLong());
            }
            
            /**
             * Utility function to change the endianness of the given GUID bytes.
             */
            private static byte[] switchByteOrder(byte[] rawBytes) {
               
               // raw GUID data have this format: AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE
               byte[] switchedBytes = new byte[16];
         
               // switch AAAAAAAA bytes
               switchedBytes[0] = rawBytes[3];
               switchedBytes[1] = rawBytes[2];
               switchedBytes[2] = rawBytes[1];
               switchedBytes[3] = rawBytes[0];
         
               // switch BBBB bytes
               switchedBytes[4] = rawBytes[5];
               switchedBytes[5] = rawBytes[4];
         
               // switch CCCC bytes
               switchedBytes[6] = rawBytes[7];
               switchedBytes[7] = rawBytes[6];
         
               // switch EEEEEEEEEEEE bytes
               for (int i = 8; i < 16; i++)
                  switchedBytes[i] = rawBytes[i];
         
               return switchedBytes;
            }
            
            @SuppressWarnings("boxing")
            public static Object encode(Object plainData) {
            
               if (plainData == null)
                  throw new NullPointerException();
            
               if (plainData instanceof «java_uuid»)
                  return encode( («java_uuid») plainData );

               «FOR data_type : data_types»
                  if (plainData instanceof «resolve(data_type)»)
                  {
                     «makeEncode(data_type)»
                  }
                  
               «ENDFOR»
               return plainData;
            }
            
            @SuppressWarnings("boxing")
            public static Object decode(Object encodedData) {
            
               if (encodedData == null)
                  throw new NullPointerException();
            
               «FOR data_type : data_types»
                  if (encodedData instanceof «resolveProtobuf(data_type, Optional.empty)»)
                  {
                     «makeDecode(data_type)»
                  }
               «ENDFOR»
               
               return encodedData;
            }
         }
         '''
      ))
   }
   
   def private dispatch String makeDecode(AbstractType element)
   {
      if (element.referenceType !== null)
         return makeDecode(element.referenceType)
   }
   
   def private dispatch String makeDecode(EnumDeclaration element)
   {
      val api_type_name = resolve(element)
      val protobuf_type_name = resolveProtobuf(element, Optional.empty)
      
      '''
      «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
      «FOR item : element.containedIdentifiers»
         «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «protobuf_type_name».«item»)
            return «api_type_name».«item»;
      «ENDFOR»
      else
         throw new «resolve("java.util.NoSuchElementException")»("Unknown value " + typedData.toString() + " for enumeration «element.name»");
      '''
   }
   
   def private dispatch String makeDecode(StructDeclaration element)
   {
      makeDecodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
   }

   def private dispatch String makeDecode(ExceptionDeclaration element)
   {
      makeDecodeStructOrException(element, element.allMembers, Optional.empty)
   }
   
   def private String makeDecodeStructOrException(EObject element, Iterable<MemberElementWrapper> members, Optional<Collection<AbstractTypeDeclaration>> type_declarations)
   {
      val api_type_name = resolve(element)
      val protobuf_type_name = resolveProtobuf(element, Optional.empty)
      
      val all_types = new ArrayList<MemberElementWrapper>
      all_types.addAll(members)
      
      if (type_declarations.present)
         type_declarations.get
            .filter(StructDeclaration)
            .filter[declarator !== null]
            .forEach[ all_types.add( new MemberElementWrapper(it) )]
      
      '''
      «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
      «FOR member : members»
         «val codec = resolveCodec(member.type)»
         «val is_sequence = Util.isSequenceType(member.type)»
         «val is_failable = is_sequence && Util.isFailable(member.type)»
         «val is_byte = Util.isByte(member.type)»
         «val is_short = Util.isInt16(member.type)»
         «val is_char = Util.isChar(member.type)»
         «val use_codec = GeneratorUtil.useCodec(member.type, param_bundle.artifactNature)»
         «val is_optional = member.optional»
         «val api_type = toText(member.type)»
         «val member_name = member.name.asParameter»
         «IF is_optional»«resolve("java.util.Optional")»<«ENDIF»«api_type»«IF is_optional»>«ENDIF» «member_name» = «IF is_optional»(typedData.«IF is_sequence»get«ELSE»has«ENDIF»«member.name.asProtobufName»«IF is_sequence»Count«ENDIF»()«IF is_sequence» > 0«ENDIF») ? «ENDIF»«IF is_optional»Optional.of(«ENDIF»«IF use_codec»«IF !is_sequence»(«api_type») «ENDIF»«codec».decode«IF is_failable»Failable«ENDIF»(«ENDIF»«IF is_short || is_byte || is_char»(«IF is_byte»byte«ELSEIF is_char»char«ELSE»short«ENDIF») «ENDIF»typedData.get«member.name.asProtobufName»«IF is_sequence»List«ENDIF»()«IF use_codec»)«ENDIF»«IF is_optional»)«ENDIF»«IF is_optional» : Optional.empty()«ENDIF»;
      «ENDFOR»
      
      return new «api_type_name» (
         «FOR member : members SEPARATOR ","»
            «member.name.toFirstLower»
         «ENDFOR»
      );
      '''
   }
   
   def private dispatch String makeEncode(AbstractType element)
   {
      if (element.referenceType !== null)
         return makeEncode(element.referenceType)
   }
   
   def private dispatch String makeEncode(EnumDeclaration element)
   {
      val api_type_name = resolve(element)
      val protobuf_type_name = resolveProtobuf(element, Optional.empty)
      
      '''
      «api_type_name» typedData = («api_type_name») plainData;
      «FOR item : element.containedIdentifiers»
         «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «api_type_name».«item»)
            return «protobuf_type_name».«item»;
      «ENDFOR»
      else
         throw new «resolve("java.util.NoSuchElementException")»("Unknown value " + typedData.toString() + " for enumeration «element.name»");
      '''
   }
   
   def private dispatch String makeEncode(StructDeclaration element)
   {
      makeEncodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
   }
   
   def private dispatch String makeEncode(ExceptionDeclaration element)
   {
      makeEncodeStructOrException(element, element.allMembers, Optional.empty)
   }
   
   def private String makeEncodeStructOrException(EObject element, Iterable<MemberElementWrapper> members, Optional<Collection<AbstractTypeDeclaration>> type_declarations)
   {
      val protobuf_type = resolveProtobuf(element, Optional.empty)
      val plain_type = resolve(element)
      
      '''
      «IF !members.empty»«plain_type» typedData = («plain_type») plainData;«ENDIF»
      «protobuf_type».Builder builder
         = «protobuf_type».newBuilder();
      «FOR member : members»
         «val use_codec = GeneratorUtil.useCodec(member.type, param_bundle.artifactNature)»
         «val is_sequence = Util.isSequenceType(member.type)»
         «val is_failable = is_sequence && Util.isFailable(member.type)»
         «val method_name = '''«IF is_sequence»addAll«ELSE»set«ENDIF»«member.name.asProtobufName»'''»
         «IF member.optional»
            if (typedData.get«resolve("java.util.Optional").alias(member.name.toFirstUpper)»().isPresent())
            {
               builder.«method_name»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(member.type, Optional.empty)») «ENDIF»encode«IF is_failable»Failable«ENDIF»(«ENDIF»typedData.get«member.name.toFirstUpper»().get()«IF is_failable», «resolveFailableProtobufType(member.type, Util.getScopeDeterminant(member.type))».class«ENDIF»«IF use_codec»)«ENDIF»);
            }
         «ELSE»
            builder.«method_name»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(member.type, Optional.empty)») «ENDIF»encode«IF is_failable»Failable«ENDIF»(«ENDIF»typedData.get«member.name.toFirstUpper»()«IF is_failable», «resolveFailableProtobufType(member.type, Util.getScopeDeterminant(member.type))».class«ENDIF»«IF use_codec»)«ENDIF»);
         «ENDIF»
      «ENDFOR»
      return builder.build();
      '''
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
         generateLog4jProperties()
      )
   }
   
   def private String generateClientConsoleProgram(String class_name, String log4j_name, InterfaceDeclaration interface_declaration)
   {
      val resources_location = MavenArtifactType.TEST_RESOURCES.directoryLayout
      val api_name = resolve(interface_declaration)
      val connection_string = '''tcp://127.0.0.1:«Constants.DEFAULT_PORT»'''
      
      '''
      public class «class_name» {
      
         private final static String connectionString = "«connection_string»";
         private static final «resolve("org.apache.log4j.Logger")» logger = Logger.getLogger(«class_name».class);
         
         public static void main(String[] args) {
            
            «resolve("com.btc.cab.servicecomm.api.IClientEndpoint")» client = null;
            «api_name» proxy = null;
            «resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);

            logger.info("Client trying to connect to " + connectionString);
            «resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» connectionFactory = new «resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqClientConnectionFactory")»(logger);
            
            try {
               client = new «resolve("com.btc.cab.servicecomm.singlequeue.core.ClientEndpointFactory")»(logger, connectionFactory).create(connectionString);
            } catch (Exception e)
            {
               logger.error("Client could not start! Is there a server running on «connection_string»? Error: " + e.toString());
            }
      
            logger.info("Client started...");
            try {
               proxy = «resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.PROXY)) + '''.«interface_declaration.name»ProxyFactory''')».createDirectProtobufProxy(client);
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
                     «val basic_type = resolve(Util.getUltimateType(param.paramType))»
                     «val is_failable = is_sequence && Util.isFailable(param.paramType)»
                     «IF is_sequence»«resolve("java.util.Collection")»<«IF is_failable»«resolve("java.util.concurrent.CompletableFuture")»<«ENDIF»«ENDIF»«basic_type»«IF is_sequence»«IF is_failable»>«ENDIF»>«ENDIF» «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
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
         generateSpringBeans(package_name, program_name, interface_declaration)
      )
      
      file_system_access.generateFile(
         makeProjectSourcePath(interface_declaration, ProjectType.SERVER_RUNNER, MavenArtifactType.TEST_RESOURCES, PathType.ROOT) + log4j_name,
         generateLog4jProperties()
      )
   }
   
   def private String generateLog4jProperties()
   {
      reinitializeFile
      
      '''
      # Root logger option
      log4j.rootLogger=INFO, stdout
      
      # Direct log messages to stdout
      log4j.appender.stdout=org.apache.log4j.ConsoleAppender
      log4j.appender.stdout.Target=System.out
      log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
      log4j.appender.stdout.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss} %-5p %c{1}:%L - %m%n
      '''
   }
   
   def private String generateSpringBeans(String package_name, String program_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      '''
      <?xml version="1.0" encoding="UTF-8"?>
      <beans xmlns="http://www.springframework.org/schema/beans"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans-3.0.xsd">
      
         <bean id="ServerFactory" class="com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqServerConnectionFactory">
            <constructor-arg ref="logger" />
         </bean>
      
         <bean id="logger" class="org.apache.log4j.Logger" factory-method="getLogger">
            <constructor-arg type="java.lang.String" value="«package_name».«program_name»" />
         </bean>
      </beans>
      '''
   }
   
   def private String generateServerRunnerImplementation(String class_name, InterfaceDeclaration interface_declaration)
   {
      reinitializeFile
      
      val api_name = resolve(interface_declaration)
      val impl_name = resolve(interface_declaration, ProjectType.IMPL)
      val dispatcher_name = resolve(interface_declaration, ProjectType.DISPATCHER)
      
      '''
      public class «class_name» implements «resolve("java.lang.AutoCloseable")» {
      
         private final «resolve("com.btc.cab.servicecomm.api.IServerEndpoint")» _serverEndpoint;
         private «resolve("com.btc.cab.servicecomm.api.IServiceRegistration")» _serviceRegistration;
      
         public «class_name»(IServerEndpoint serverEndpoint) {
            _serverEndpoint = serverEndpoint;
         }
      
         public void registerService() throws Exception {
      
            // Create ServiceDescriptor for the service
            «resolve("com.btc.cab.servicecomm.api.dto.ServiceDescriptor")» serviceDescriptor = new ServiceDescriptor();

            serviceDescriptor.setServiceTypeUuid(«api_name».TypeGuid);
            serviceDescriptor.setServiceTypeName("«api_name.fullyQualifiedName»");
            serviceDescriptor.setServiceInstanceName("«interface_declaration.name»TestService");
            serviceDescriptor
               .setServiceInstanceDescription("«api_name.fullyQualifiedName» instance for integration tests");
      
            // Create dispatcher and dispatchee instances
            «resolve("com.btc.cab.servicecomm.protobuf.ProtoBufServerHelper")» protoBufServerHelper = new ProtoBufServerHelper();
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
         public void close() throws «resolve("java.lang.Exception")» {
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
         private static «resolve("com.btc.cab.servicecomm.api.IServerEndpoint")» _serverEndpoint;
         private static «server_runner_class_name» _serverRunner;
         private static final «resolve("org.apache.log4j.Logger")» logger = Logger.getLogger(Program.class);
         private static String _file;
         
         public static void main(String[] args) {
            
            «resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);
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
            «resolve("org.springframework.context.ApplicationContext")» ctx = new «resolve("org.springframework.context.support.FileSystemXmlApplicationContext")»(_file);
            
            «resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» _serverConnectionFactory = (IConnectionFactory) ctx
                  .getBean("ServerFactory", logger);
            
            try {
               _serverEndpoint = new «resolve("com.btc.cab.servicecomm.singlequeue.core.ServerEndpointFactory")»(logger,_serverConnectionFactory).create(_connectionString);
               
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
                  } catch («resolve("java.lang.Exception")» e) {
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
      val api_name = resolve(interface_declaration)
      val protobuf_request = resolveProtobuf(interface_declaration, Optional.of(ProtobufType.REQUEST))
      val protobuf_response = resolveProtobuf(interface_declaration, Optional.of(ProtobufType.RESPONSE))

      '''
      public class «class_name» implements «api_name» {
         
         private final «resolve("com.btc.cab.servicecomm.api.IClientEndpoint")» _endpoint;
         private final «resolve("com.btc.cab.servicecomm.api.IServiceReference")» _serviceReference;
         private final «resolve("com.btc.cab.servicecomm.serialization.IMessageBufferSerializer")» _serializer;
         
         public «class_name»(IClientEndpoint endpoint) throws Exception {
            _endpoint = endpoint;

            _serviceReference = _endpoint
               .connectService(«api_name».TypeGuid);

            _serializer = new «resolve("com.btc.cab.servicecomm.serialization.SinglePartMessageBufferSerializer")»(new «resolve("com.btc.cab.servicecomm.protobuf.ProtobufSerializer")»());

            // ServiceFaultHandler
            _serviceReference
               .getServiceFaultHandlerManager()
               .registerHandler(«resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.SERVICE_API)) + '''.«interface_declaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
         }
         
         «FOR function : interface_declaration.functions SEPARATOR newLine»
            «val is_void = function.returnedType.isVoid»
            «val is_sync = function.sync»
            «val return_type = (if (is_void) "Void" else toText(function.returnedType) )»
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
                     .«method_name»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(param.paramType, Optional.empty)») «ENDIF»«codec».encode«IF is_failable»Failable«ENDIF»(«ENDIF»«param.paramName»«IF is_failable», «resolveFailableProtobufType(param.paramType, interface_declaration)».class«ENDIF»«IF use_codec»)«ENDIF»)
                  «ENDFOR»
                  .build();
               
               «protobuf_request» request = «protobuf_request».newBuilder()
                 .set«protobuf_function_name»«Constants.PROTOBUF_REQUEST»(request«function.name»)
                 .build();
               
               «resolve("java.util.concurrent.Future")»<byte[]> requestFuture = «resolve("com.btc.cab.servicecomm.util.ClientEndpointExtensions")».RequestAsync(_endpoint, _serviceReference, _serializer, request);
               «resolve("java.util.concurrent.Callable")»<«return_type»> returnCallable = () -> {
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
                              «val out_param_type = toText(out_param.paramType)»
                              «out_param_type» «temp_param_name» = («out_param_type») «codec».decode( «response_name».get«out_param.paramName.asProtobufName»() );
                              «handleOutputParameter(out_param, temp_param_name, param_name)»
                           «ELSE»
                              «val is_failable = Util.isFailable(out_param.paramType)»
                              «resolve("java.util.Collection")»<«IF is_failable»«resolve("java.util.concurrent.CompletableFuture")»<«ENDIF»«toText(Util.getUltimateType(out_param.paramType))»«IF is_failable»>«ENDIF»> «temp_param_name» = «codec».decode«IF is_failable»Failable«ENDIF»( «response_name».get«out_param.paramName.asProtobufName»List() );
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

               «IF !is_void || !is_sync»return «ENDIF»«resolve("com.btc.cab.commons.helper.AsyncHelper")».createAndRunFutureTask(returnCallable)«IF is_sync».get()«ENDIF»;
            }
         «ENDFOR»
         
         «IF anonymous_event !== null»
            «IF anonymous_event.keys.empty»
               «val event_type_name = resolve(anonymous_event.data)»
               /**
                  @see com.btc.cab.commons.IObservable#subscribe
               */
               @Override
               public «resolve("java.io.Closeable")» subscribe(«resolve("com.btc.cab.commons.IObserver")»<«resolve(anonymous_event.data)»> observer) throws Exception {
                  _endpoint.getEventRegistry().createEventRegistration(
                        «event_type_name».EventTypeGuid,
                        «resolve("com.btc.cab.servicecomm.api.EventKind")».EVENTKINDPUBLISHSUBSCRIBE,
                        «event_type_name».EventTypeGuid.toString());
                  return «resolve("com.btc.cab.servicecomm.util.EventRegistryExtensions")».subscribe(_endpoint.getEventRegistry()
                        .getSubscriberManager(), _serializerDeserializer,
                        «event_type_name».EventTypeGuid,
                        EventKind.EVENTKINDPUBLISHSUBSCRIBE, observer);
               }
             «ELSE»
               /**
                  @see ???
               */
               public «resolve("java.io.Closeable")» subscribe(«resolve("com.btc.cab.commons.IObserver")»<«resolve(anonymous_event.data)»> observer, Iterable<KeyType> keys) throws Exception {
                  «makeDefaultMethodStub»
               }
            «ENDIF»
         «ENDIF»
         «FOR event : interface_declaration.contains.filter(EventDeclaration).filter[name !== null]»
            «val observable_name = toText(event)»
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
      
      val api_type = resolve(interface_declaration)
      
      '''
      public class «class_name» {
         
         public static «api_type» createDirectProtobufProxy(«resolve("com.btc.cab.servicecomm.api.IClientEndpoint")» endpoint) throws Exception
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
      val api_class_name = resolve(interface_declaration)
      
      val protobuf_request = resolveProtobuf(interface_declaration, Optional.of(ProtobufType.REQUEST))
      val protobuf_response = resolveProtobuf(interface_declaration, Optional.of(ProtobufType.RESPONSE))
      
      file_system_access.generateFile(
         src_root_path + dispatcher_class_name.java,
         generateSourceFile(interface_declaration,
         '''
         public class «dispatcher_class_name» implements «resolve("com.btc.cab.servicecomm.api.IServiceDispatcher")» {
            
            private final «api_class_name» _dispatchee;

            private final «resolve("com.btc.cab.servicecomm.protobuf.ProtoBufServerHelper")» _protoBufHelper;

            private final «resolve("com.btc.cab.servicecomm.api.IServiceFaultHandlerManager")» _faultHandlerManager;
            
            public «dispatcher_class_name»(«api_class_name» dispatchee, ProtoBufServerHelper protoBufHelper) {
               _dispatchee = dispatchee;
               _protoBufHelper = protoBufHelper;

               // ServiceFaultHandlerManager
               _faultHandlerManager = new «resolve("com.btc.cab.servicecomm.faulthandling.ServiceFaultHandlerManager")»();
         
               // ServiceFaultHandler
               _faultHandlerManager.registerHandler(«resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.SERVICE_API)) + '''.«interface_declaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
            }
            
            /**
               @see com.btc.cab.servicecomm.api.IServiceDispatcher#processRequest
            */
            @Override
            public «resolve("com.btc.cab.servicecomm.common.IMessageBuffer")» processRequest(
               IMessageBuffer requestBuffer, «resolve("com.btc.cab.servicecomm.common.IPeerIdentity")» peerIdentity, «resolve("com.btc.cab.servicecomm.api.IServerEndpoint")» serverEndpoint) throws Exception {
               
               byte[] requestByte = _protoBufHelper.deserializeRequest(requestBuffer);
               «protobuf_request» request
                  = «protobuf_request».parseFrom(requestByte);
               
               «FOR function : interface_declaration.functions SEPARATOR newLine»
                  «val is_sync = function.isSync»
                  «val is_void = function.returnedType.isVoid»
                  «val result_type = resolve(function.returnedType)»
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
                           «IF is_sequence»«resolve("java.util.Collection")»<«IF is_failable»«resolve("java.util.concurrent.CompletableFuture")»<«ENDIF»«resolve(Util.getUltimateType(param.paramType))»«IF is_failable»>«ENDIF»>«ELSE»«resolve(param.paramType)»«ENDIF» «param.paramName.asParameter» = «makeDefaultValue(param.paramType)»;
                        «ENDFOR»
                     «ENDIF»
                     
                     // call actual method
                     «IF !is_void»«IF result_is_sequence»«resolve("java.util.Collection")»<«IF result_is_failable»«resolve("java.util.concurrent.CompletableFuture")»<«ENDIF»«resolve(Util.getUltimateType(function.returnedType))»«IF result_is_failable»>«ENDIF»>«ELSE»«result_type»«ENDIF» result = «ENDIF»_dispatchee.«function.name.asMethod»
                     (
                        «FOR param : function.parameters SEPARATOR ","»
                           «val plain_type = resolve(param.paramType)»
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
                        «IF !is_void».«IF result_is_sequence»addAll«function.name.asProtobufName»«ELSE»set«function.name.asProtobufName»«ENDIF»(«IF result_use_codec»«IF !result_is_sequence»(«resolveProtobuf(function.returnedType, Optional.empty)»)«ENDIF»«result_codec».encode«IF result_is_failable»Failable«ENDIF»(«ENDIF»result«IF result_is_failable», «resolveFailableProtobufType(function.returnedType, interface_declaration)».class«ENDIF»«IF result_use_codec»)«ENDIF»)«ENDIF»
                        «FOR out_param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                           «val is_sequence = Util.isSequenceType(out_param.paramType)»
                           «val is_failable = is_sequence && Util.isFailable(out_param.paramType)»
                           «val use_codec = GeneratorUtil.useCodec(out_param.paramType, param_bundle.artifactNature) || is_failable»
                           «val codec = resolveCodec(out_param.paramType)»
                           .«IF is_sequence»addAll«out_param.paramName.asProtobufName»«ELSE»set«out_param.paramName.asProtobufName»«ENDIF»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(out_param.paramType, Optional.empty)») «ENDIF»«codec».encode«IF is_failable»Failable«ENDIF»(«ENDIF»«out_param.paramName.asParameter»«IF is_failable», «resolveFailableProtobufType(out_param.paramType, interface_declaration)».class«ENDIF»«IF use_codec»)«ENDIF»)
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
               throw new «resolve("com.btc.cab.servicecomm.api.exceptions.InvalidMessageReceivedException")»("Unknown or invalid request");
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
      val api_name = resolve(interface_declaration)
      
      file_system_access.generateFile(src_root_path + impl_name.java,
         generateSourceFile(interface_declaration,
         '''
         public class «impl_name» implements «api_name» {
            
            «FOR function : interface_declaration.functions SEPARATOR newLine»
               /**
                  @see «api_name.fullyQualifiedName»#«function.name.toFirstLower»
               */
               @Override
               public «makeInterfaceMethodSignature(function)» {
                  «makeDefaultMethodStub»
               }
            «ENDFOR»
            
            «FOR event : interface_declaration.contains.filter(EventDeclaration).filter[name !== null]»
               «val observable_name = toText(event)»
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
   
   def private dispatch String toText(ParameterElement element)
   {
      '''
      «resolve(element)»
      '''
   }
   
   def private dispatch String toText(MemberElement element)
   {
      '''«IF element.optional»«resolve("java.util.Optional")»<«ENDIF»«toText(element.type)»«IF element.optional»>«ENDIF»'''
   }
   
   def private dispatch String toText(ReturnTypeElement element)
   {
      if (element.isVoid)
         return "void"

      throw new IllegalArgumentException("Unknown ReturnTypeElement: " + element.class.toString)
   }
   
   def private dispatch String toText(AbstractType element)
   {
      if (element.primitiveType !== null)
         return toText(element.primitiveType)
      else if (element.referenceType !== null)
         return toText(element.referenceType)
      else if (element.collectionType !== null)
         return toText(element.collectionType)
      
      throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
   }
   
   def private dispatch String toText(PrimitiveType element)
   {
      if (element.isInt64)
         return "Long"
      else if (element.isInt32)
         return "Integer"
      else if (element.isInt16)
         return "Short"
      else if (element.isByte)
         return "Byte"
      else if (element.isString)
         return "String"
      else if (element.isFloat)
         return "Float"
      else if (element.isDouble)
         return "Double"
      else if (element.isUUID)
         return resolve("java.util.UUID").toString
      else if (element.isBoolean)
         return "Boolean"
      else if (element.isChar)
         return "Character"

      throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
   }
   
   def private dispatch String toText(AliasDeclaration element)
   {
      var type_name = typedef_table.get(element.name)
      val ultimate_type = Util.getUltimateType(element.type)
      if (type_name === null)
      {
         type_name = resolve(ultimate_type)
         typedef_table.put(element.name, type_name)
      }

      if (!Util.isPrimitive(ultimate_type))
         referenced_types.add(type_name.fullyQualifiedName)
      return type_name.toString
   }
   
   def private dispatch String toText(EnumDeclaration element)
   {
      '''«resolve(element)»'''
   }
   
   def private dispatch String toText(EventDeclaration element)
   {
      '''«resolve(element)»'''
   }
   
   def private dispatch String toText(StructDeclaration element)
   {
      '''«resolve(element)»'''
   }
   
   def private String makeGetterSetter(String type_name, String var_name)
   {
      '''
      «makeGetter(type_name, var_name)»
      
      «makeSetter(type_name, var_name)»
      '''
   }
   
   def private String makeGetter(String type_name, String var_name)
   {
      '''
      public «type_name» get«var_name.toFirstUpper»() {
         return «var_name»;
      };
      '''
   }
   
   def private String makeSetter(String type_name, String var_name)
   {
      '''
      public void set«var_name.toFirstUpper»(«type_name» «var_name») {
         this.«var_name» = «var_name»;
      };
      '''
   }
   
   def private dispatch String toDeclaration(EObject element)
   {
      '''
      // TODO: implement this...
      '''
   }
   
   def private dispatch String toDeclaration(ExceptionDeclaration element)
   {
      val class_members = new ArrayList<Pair<String, String>>
      for (member : element.effectiveMembers) class_members.add(Pair.of(member.name, toText(member.type)))

      '''
      public class «element.name» extends «IF element.supertype === null»Exception«ELSE»«toText(element.supertype)»«ENDIF» {
         
         static final long serialVersionUID = «element.name.hashCode»L;
         «FOR class_member : class_members BEFORE newLine»
            private «class_member.value» «class_member.key»;
         «ENDFOR»
         
         public «element.name»() {
            // this default constructor is always necessary for exception registration in ServiceComm framework
         }
         
         «IF !class_members.empty»
            public «element.name»(«FOR class_member : class_members SEPARATOR ", "»«class_member.value» «class_member.key»«ENDFOR») {
               «FOR class_member : class_members»
                  this.«class_member.key» = «class_member.key»;
               «ENDFOR»
            };
         «ENDIF»
         
         «FOR class_member : class_members SEPARATOR newLine»
            «makeGetterSetter(class_member.value, class_member.key)»
         «ENDFOR»
         
         «IF !(class_members.size == 1 && class_members.head.value.equalsIgnoreCase("string"))»
         public «element.name»(String message) {
            // this default constructor is necessary to be able to use Exception#getMessage() method
            super(message);
         }
         «ENDIF»
      }
      '''
   }
   
   def private dispatch String toDeclaration(EnumDeclaration element)
   {
      '''
      public enum «element.name» {
         «FOR enum_value : element.containedIdentifiers SEPARATOR ","»
            «enum_value»
         «ENDFOR»
      }
      '''
   }
   
   def private dispatch String toDeclaration(StructDeclaration element)
   {
      val class_members = new ArrayList<Pair<String, String>>
      for (member : element.effectiveMembers) class_members.add(Pair.of(member.name, '''«IF member.optional»«resolve("java.util.Optional")»<«ENDIF»«toText(member.type)»«IF member.optional»>«ENDIF»'''))
      
      val all_class_members = new ArrayList<Pair<String, String>>
      for (member : element.allMembers) all_class_members.add(Pair.of(member.name, '''«IF member.optional»«resolve("java.util.Optional")»<«ENDIF»«toText(member.type)»«IF member.optional»>«ENDIF»'''))
      
      val is_derived = ( element.supertype !== null )
      val related_event =  Util.getRelatedEvent(element, idl)
      
      '''
      public class «element.name» «IF is_derived»extends «toText(element.supertype)» «ENDIF»{
         «IF related_event !== null»
            
            public static final «resolve("java.util.UUID")» EventTypeGuid = UUID.fromString("«GuidMapper.get(related_event)»");
         «ENDIF»
         «FOR class_member : class_members BEFORE newLine»
            private «class_member.value» «class_member.key»;
         «ENDFOR»
         
         «IF !class_members.empty»public «element.name»() { «IF is_derived»super(); «ENDIF»};«ENDIF»
         
         public «element.name»(«FOR class_member : all_class_members SEPARATOR ", "»«class_member.value» «class_member.key»«ENDFOR») {
            «IF is_derived»super(«element.supertype.allMembers.map[name].join(", ")»);«ENDIF»
            
            «FOR class_member : class_members»
               this.«class_member.key» = «class_member.key»;
            «ENDFOR»
         };
         
         «FOR class_member : class_members SEPARATOR newLine»
            «makeGetterSetter(class_member.value, class_member.key)»
         «ENDFOR»
         
         «FOR type : element.typeDecls SEPARATOR newLine AFTER newLine»
            «toDeclaration(type)»
         «ENDFOR»
      }
      '''
   }
   
   def private dispatch String toText(ExceptionDeclaration element)
   {
      val exception_name = resolveException(qualified_name_provider.getFullyQualifiedName(element).toString)
      if (exception_name.isPresent)
         return exception_name.get()
      else
         '''«resolve(element)»'''
   }
   
   def private dispatch String toText(SequenceDeclaration item)
   {
      val is_failable = item.failable
      
      '''«resolve("java.util.Collection")»<«IF is_failable»«resolve("java.util.concurrent.CompletableFuture")»<«ENDIF»«toText(item.type)»«IF is_failable»>«ENDIF»>'''
   }
   
   def private ResolvedName resolve(String name)
   {
      val fully_qualified_name = QualifiedName.create(name.split(Pattern.quote(Constants.SEPARATOR_PACKAGE)))
      referenced_types.add(name)
      val dependency = MavenResolver.resolveDependency(name)
      if (dependency.present) dependencies.add(dependency.get)
      return new ResolvedName(fully_qualified_name, TransformType.PACKAGE, false)
   }
   
   def private ResolvedName resolve(EObject element)
   {
      return resolve(element, element.mainProjectType)
   }
   
   def private ResolvedName resolve(EObject element, ProjectType project_type)
   {
      val fully_qualified = false // we want the toString method show short names by default!
      var name = qualified_name_provider.getFullyQualifiedName(element)
      
      // try to resolve CAB-related pseudo-exceptions
      if (Util.isException(element))
      {
         val exception_name = resolveException(name.toString)
         if (exception_name.present)
            return new ResolvedName(exception_name.get(), TransformType.PACKAGE, fully_qualified)
      }
      
      if (name === null)
      {
         if (element instanceof AbstractType)
         {
            if (element.primitiveType !== null)
            {
               return resolve(element.primitiveType, project_type)
            }
            else if (element.referenceType !== null)
            {
               return resolve(Util.getUltimateType(element.referenceType), if (project_type != ProjectType.PROTOBUF) element.referenceType.mainProjectType else project_type)
            }
         }
         else if (element instanceof PrimitiveType)
         {
            if (element.uuidType !== null)
            {
               if (project_type == ProjectType.PROTOBUF)
                  return resolve("com.google.protobuf.ByteString")
               else
                  return resolve("java.util.UUID")
            }
            else
               return new ResolvedName(toText(element), TransformType.PACKAGE, fully_qualified)
         }
         return new ResolvedName(Names.plain(element), TransformType.PACKAGE, fully_qualified)
      }
      
      val effective_name = MavenResolver.resolvePackage(element, Optional.of(project_type)) + TransformType.PACKAGE.separator
         + if (element instanceof InterfaceDeclaration) project_type.getClassName(param_bundle.artifactNature, name.lastSegment)
         else if (element instanceof EventDeclaration) getObservableName(element)
         else name.lastSegment
      val fully_qualified_name = QualifiedName.create(effective_name.split(Pattern.quote(Constants.SEPARATOR_PACKAGE)))
      
      referenced_types.add(fully_qualified_name.toString)
      dependencies.add(MavenResolver.resolveDependency(element))

      return new ResolvedName(fully_qualified_name, TransformType.PACKAGE, fully_qualified)
   }
   
   def private void reinitializeFile()
   {
      referenced_types.clear
   }
   
   def private void reinitializeAll()
   {
      reinitializeFile
      dependencies.clear
   }
   
   def private String makeDefaultMethodStub()
   {
      '''
      // TODO Auto-generated method stub
      throw new UnsupportedOperationException("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»");
      '''
   }
   
   def private ResolvedName resolveProtobuf(EObject object, Optional<ProtobufType> protobuf_type)
   {
      if (Util.isUUIDType(object))
         return resolve(object, ProjectType.PROTOBUF)
      else if (Util.isAlias(object))
         return resolveProtobuf(Util.getUltimateType(object), protobuf_type)
      else if (object instanceof PrimitiveType)
         return new ResolvedName(toText(object), TransformType.PACKAGE)
      else if (object instanceof AbstractType && (object as AbstractType).primitiveType !== null)
         return resolveProtobuf((object as AbstractType).primitiveType, protobuf_type)
      else if (object instanceof AbstractType && (object as AbstractType).referenceType !== null)
         return resolveProtobuf((object as AbstractType).referenceType, protobuf_type)

      val is_function = (object instanceof FunctionDeclaration)
      val is_interface = (object instanceof InterfaceDeclaration)
      val scope_determinant = Util.getScopeDeterminant(object)

      var result = MavenResolver.resolvePackage(object, Optional.of(ProjectType.PROTOBUF))
      result += Constants.SEPARATOR_PACKAGE
      if (is_interface && Util.ensurePresentOrThrow(protobuf_type))
         result += Names.plain(object) + "." + Names.plain(object) + "_" + protobuf_type.get.getName
      else if (is_function && Util.ensurePresentOrThrow(protobuf_type))
         result += Names.plain(scope_determinant) + "_" + protobuf_type.get.getName + "_" + Names.plain(object) + "_" + protobuf_type.get.getName
      else if (scope_determinant instanceof ModuleDeclaration)
         result += Constants.FILE_NAME_TYPES + "." + Names.plain(object)
      else
         result += Names.plain(scope_determinant) + "." + Names.plain(object)
      
      val dependency = MavenResolver.resolveDependency(object)
      dependencies.add(dependency)
      return new ResolvedName(result, TransformType.PACKAGE)
   }
   
   def private String resolveCodec(EObject object)
   {
      val ultimate_type = Util.getUltimateType(object)
      
      val codec_name = GeneratorUtil.getCodecName(ultimate_type)
      MavenResolver.resolvePackage(ultimate_type, Optional.of(ProjectType.PROTOBUF)) + TransformType.PACKAGE.separator + codec_name
   }
   
   def private String getObservableName(EventDeclaration event)
   {
      if (event.name === null)
         throw new IllegalArgumentException("No named observable for anonymous events!")
         
      event.name.toFirstUpper + "Observable"
   }
   
   def private String newLine()
   {
      '''
      
      '''
   }
   
   def private static String asProtobufName(String name)
   {
      name.toLowerCase.toFirstUpper
   }
   
   def private static String asMethod(String name)
   {
      name.toFirstLower
   }
   
   def private static String asParameter(String name)
   {
      name.toFirstLower
   }
   
   def private String makeDefaultValue(EObject element)
   {
      if (element instanceof PrimitiveType)
      {
         if (element.isString)
            return '''""'''
         else if (element.isUUID)
            return '''«resolve("java.util.UUID")».randomUUID()'''
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
         val type = toText(element.type)
         val is_failable = element.failable
         return '''new «resolve("java.util.Vector")»<«IF is_failable»«resolve("java.util.concurrent.CompletableFuture")»<«ENDIF»«type»«IF is_failable»>«ENDIF»>()'''
      }
      else if (element instanceof StructDeclaration)
      {
         return '''new «resolve(element)»(«FOR member : element.allMembers SEPARATOR ", "»«IF member.optional»«resolve("java.util.Optional")».empty()«ELSE»«makeDefaultValue(member.type)»«ENDIF»«ENDFOR»)'''
      }
      else if (element instanceof EnumDeclaration)
      {
         return '''«toText(element)».«element.containedIdentifiers.head»''';
      }
      
      return '''0'''
   }
   
   def private Optional<String> resolveException(String name)
   {
      // temporarily some special handling for exceptions, because not all
      // C++ CAB exceptions are supported by the Java CAB
      switch (name)
      {
         case "BTC.Commons.Core.InvalidArgumentException":
            return Optional.of("IllegalArgumentException")
         default:
            return Optional.empty
      }
   }
   
   def private static String asServiceFaultHandlerFactory(EObject container)
   {
      val name = if (container instanceof InterfaceDeclaration) container.name else ""
      '''«name»ServiceFaultHandlerFactory'''
   }
   
   def private String resolveFailableProtobufType(EObject element, EObject container)
   {
      val container_name = if (container instanceof InterfaceDeclaration) '''«container.name».''' else "" 
      return MavenResolver.resolvePackage(container, Optional.of(ProjectType.PROTOBUF))
         + TransformType.PACKAGE.separator
         + ( if (container instanceof ModuleDeclaration) '''«Constants.FILE_NAME_TYPES».''' else "" )
         + container_name
         + GeneratorUtil.asFailable(element, container, qualified_name_provider)
   }
}
