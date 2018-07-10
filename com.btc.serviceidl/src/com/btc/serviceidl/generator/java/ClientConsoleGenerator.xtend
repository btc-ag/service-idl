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
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ClientConsoleGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateClientConsoleProgram(String class_name, String log4j_name,
        InterfaceDeclaration interface_declaration)
    {
        val resources_location = MavenArtifactType.TEST_RESOURCES.directoryLayout
        val api_name = typeResolver.resolve(interface_declaration)
        val connection_string = '''tcp://127.0.0.1:«Constants.DEFAULT_PORT»'''

        val loggerFactoryType = basicJavaSourceGenerator.resolveLoggerFactory 
        val loggerType = basicJavaSourceGenerator.resolveLogger 

        '''
        public class «class_name» {
        
           private final static String connectionString = "«connection_string»";
           private static final «loggerType» logger = «loggerFactoryType».getLogger(«class_name».class);
           
           public static void main(String[] args) {
              
              «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» client = null;
              «api_name» proxy = null;
              «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
              «typeResolver.resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resources_location»/«log4j_name»", 60 * 1000);
              «ENDIF»
        
              logger.info("Client trying to connect to " + connectionString);
              «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.api.IConnectionFactory")» connectionFactory = new «basicJavaSourceGenerator.resolveZeroMqClientConnectionFactory»(
                 «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                     logger
                 «ENDIF» 
                        );
              
              try {
                client = new «typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.core.ClientEndpointFactory")»(
                     «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                         logger,
                     «ENDIF» 
                     connectionFactory).create(connectionString);
              } catch (Exception e)
              {
                 logger.error("Client could not start! Is there a server running on «connection_string»? Error: " + e.toString());
              }
        
              logger.info("Client started...");
              try {
                 proxy = «typeResolver.resolve(basicJavaSourceGenerator.typeResolver.resolvePackage(interface_declaration, ProjectType.PROXY) + '''.«interface_declaration.name»ProxyFactory''')».createDirectProtobufProxy(client);
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
                 try { client.close(); } catch (Exception e) { logger.error("Exception while closing client", e); }
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
                         «val is_sequence = param.paramType.isSequenceType»
                         «val basic_type = typeResolver.resolve(param.paramType.ultimateType)»
                         «val is_failable = is_sequence && param.paramType.isFailable»
                     «IF is_sequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«ENDIF»«basic_type»«IF is_sequence»«IF is_failable»>«ENDIF»>«ENDIF» «param.paramName.asParameter» = «basicJavaSourceGenerator.makeDefaultValue(param.paramType)»;
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

}
