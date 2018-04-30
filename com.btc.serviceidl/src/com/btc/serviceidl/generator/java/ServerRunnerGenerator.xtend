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

    def private getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def public generateServerRunnerImplementation(String class_name, InterfaceDeclaration interface_declaration)
    {
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

    def public generateServerRunnerProgram(String class_name, String server_runner_class_name, String beans_name,
        String log4j_name, InterfaceDeclaration interface_declaration)
    {
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
}
