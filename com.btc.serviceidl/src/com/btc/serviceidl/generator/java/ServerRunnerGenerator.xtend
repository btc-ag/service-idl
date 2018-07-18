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

import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtend.lib.annotations.Accessors
import com.btc.serviceidl.generator.common.ProjectType

@Accessors(NONE)
class ServerRunnerGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateServerRunnerImplementation(String className, InterfaceDeclaration interfaceDeclaration)
    {
        val apiName = typeResolver.resolve(interfaceDeclaration)
        val implName = typeResolver.resolve(interfaceDeclaration, ProjectType.IMPL)
        val dispatcherName = typeResolver.resolve(interfaceDeclaration, ProjectType.DISPATCHER)

        '''
            public class «className» implements «typeResolver.resolve("java.lang.AutoCloseable")» {
            
               private final «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» _serverEndpoint;
               private «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceRegistration")» _serviceRegistration;
            
               public «className»(IServerEndpoint serverEndpoint) {
                  _serverEndpoint = serverEndpoint;
               }
            
               public void registerService() throws Exception {
            
                  // Create ServiceDescriptor for the service
                  «typeResolver.resolve("com.btc.cab.servicecomm.api.dto.ServiceDescriptor")» serviceDescriptor = new ServiceDescriptor();
            
                  serviceDescriptor.setServiceTypeUuid(«apiName».TypeGuid);
                  serviceDescriptor.setServiceTypeName("«apiName.fullyQualifiedName»");
                  serviceDescriptor.setServiceInstanceName("«interfaceDeclaration.name»TestService");
                  serviceDescriptor
               .setServiceInstanceDescription("«apiName.fullyQualifiedName» instance for integration tests");
            
                  // Create dispatcher and dispatchee instances                  
                  «implName» dispatchee = new «implName»();
                  «dispatcherName» dispatcher = new «dispatcherName»(dispatchee, 
                      new «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                              «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtoBufServerHelper")»
                           «ELSE»
                              «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtobufSerializer")»
                           «ENDIF»()
                      );
            
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

    def generateServerRunnerProgram(String className, String serverRunnerClassName, String beansName,
        String log4j_name, InterfaceDeclaration interfaceDeclaration)
    {
        val resourcesLocation = MavenArtifactType.TEST_RESOURCES.directoryLayout

        val loggerFactoryType = basicJavaSourceGenerator.resolveLoggerFactory
        val loggerType = basicJavaSourceGenerator.resolveLogger 
        '''
            public class «className» {
               
               private static String _connectionString;
               private static «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» _serverEndpoint;
               private static «serverRunnerClassName» _serverRunner;
               private static final «loggerType» logger = «loggerFactoryType».getLogger(«className».class);
               private static String _file;
               
               public static void main(String[] args) {                  
                  «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                  «typeResolver.resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resourcesLocation»/«log4j_name»", 60 * 1000);
                  «ENDIF»
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
                     _file = "«resourcesLocation»/«beansName»";
                  
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
                        .getBean("ServerFactory"
                        «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                        , logger
                        «ENDIF»
                        );
                  
                  try {
                     _serverEndpoint = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ServerEndpointFactory")»(
                         «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                         logger,
                         «ENDIF»
                         _serverConnectionFactory).create(_connectionString);
                     
                     _serverRunner = new «serverRunnerClassName»(_serverEndpoint);
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
}
