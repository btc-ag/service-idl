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

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.util.Constants
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class TestGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateFileImplTest(String class_name, String super_class,
        InterfaceDeclaration interface_declaration)
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

    def generateTestStub(String class_name, IPath src_root_path,
        InterfaceDeclaration interface_declaration)
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
                   «basicJavaSourceGenerator.toText(param.paramType)» «param.paramName.asParameter» = «basicJavaSourceGenerator.makeDefaultValue(param.paramType)»;
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

    def generateFileZeroMQItegrationTest(String class_name, String super_class, String log4j_name,
        IPath src_root_path, InterfaceDeclaration interface_declaration)
    {
        val resources_location = MavenArtifactType.TEST_RESOURCES.directoryLayout
        val junit_assert = typeResolver.resolve(JavaClassNames.JUNIT_ASSERT)
        val server_runner_name = typeResolver.resolve(interface_declaration, ProjectType.SERVER_RUNNER)

        val loggerFactoryType = basicJavaSourceGenerator.resolveLoggerFactory 
        val loggerType = basicJavaSourceGenerator.resolveLogger 
                
        val zeroMqServerConnectionFactoryType = basicJavaSourceGenerator.resolveZeroMqServerConnectionFactory
        val zeroMqClientConnectionFactoryType = basicJavaSourceGenerator.resolveZeroMqClientConnectionFactory 
         
        '''
        public class «class_name» extends «super_class» {
        
           private final static String connectionString = "tcp://127.0.0.1:«Constants.DEFAULT_PORT»";
           private static final «loggerType» logger = «loggerFactoryType».getLogger(«class_name».class);
           
           private «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» _serverEndpoint;
           private «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» _clientEndpoint;
           private «server_runner_name» _serverRunner;
           
           public «class_name»() {
           }
           
           «typeResolver.resolve(JavaClassNames.JUNIT_BEFORE).alias("@Before")»
           public void setupEndpoints() throws Exception {
              super.setUp();
        
              «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
              «typeResolver.resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);
              «ENDIF»
        
              // Start Server
              try {
                 «zeroMqServerConnectionFactoryType» _serverConnectionFactory = new «zeroMqServerConnectionFactoryType»(
                    «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                    logger
                    «ENDIF» 
                    );
                 _serverEndpoint = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ServerEndpointFactory")»(
                    «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                    logger,
                    «ENDIF» 
                    _serverConnectionFactory).create(connectionString);
                 _serverRunner = new «server_runner_name»(_serverEndpoint);
                 _serverRunner.registerService();
        
                 logger.debug("Server started...");
                 
                 // start client
                 «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» connectionFactory = new «zeroMqClientConnectionFactoryType»(
                        «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                        logger
                        «ENDIF» 
                       );
                 _clientEndpoint = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ClientEndpointFactory")»(
                    «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                    logger,
                    «ENDIF»
                    connectionFactory).create(connectionString);
        
                 logger.debug("Client started...");
                 testSubject = «typeResolver.resolve(basicJavaSourceGenerator.typeResolver.resolvePackage(interface_declaration, ProjectType.PROXY) + '''.«interface_declaration.name»ProxyFactory''')»
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

}
