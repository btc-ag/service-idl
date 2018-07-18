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
import com.btc.serviceidl.idl.VoidType
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

    def generateClientConsoleProgram(String className, String log4j_name,
        InterfaceDeclaration interfaceDeclaration)
    {
        val resourcesLocation = MavenArtifactType.TEST_RESOURCES.directoryLayout
        val apiName = typeResolver.resolve(interfaceDeclaration)
        val connectionString = '''tcp://127.0.0.1:«Constants.DEFAULT_PORT»'''

        val loggerFactoryType = basicJavaSourceGenerator.resolveLoggerFactory 
        val loggerType = basicJavaSourceGenerator.resolveLogger 

        '''
        public class «className» {
        
           private final static String connectionString = "«connectionString»";
           private static final «loggerType» logger = «loggerFactoryType».getLogger(«className».class);
           
           public static void main(String[] args) {
              
              «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» client = null;
              «apiName» proxy = null;
              «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
              «typeResolver.resolve("org.apache.log4j.PropertyConfigurator")».configureAndWatch("«resourcesLocation»/«log4j_name»", 60 * 1000);
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
                 logger.error("Client could not start! Is there a server running on «connectionString»? Error: " + e.toString());
              }
        
              logger.info("Client started...");
              try {
                 proxy = «typeResolver.resolve(basicJavaSourceGenerator.typeResolver.resolvePackage(interfaceDeclaration, ProjectType.PROXY) + '''.«interfaceDeclaration.name»ProxyFactory''')».createDirectProtobufProxy(client);
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
           
           private static void callAllProxyMethods(«apiName» proxy) {
              
              int errorCount = 0;
              int callCount = 0;
              «FOR function : interfaceDeclaration.functions»
                  «val functionName = function.name.asMethod»
                  «val isVoid = function.returnedType instanceof VoidType»
                  try
                  {
                     callCount++;
                     «FOR param : function.parameters»
                         «val isSequence = param.paramType.isSequenceType»
                         «val basicType = typeResolver.resolve(param.paramType.ultimateType)»
                         «val isFailable = isSequence && param.paramType.isFailable»
                     «IF isSequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF isFailable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«ENDIF»«basicType»«IF isSequence»«IF isFailable»>«ENDIF»>«ENDIF» «param.paramName.asParameter» = «basicJavaSourceGenerator.makeDefaultValue(param.paramType)»;
                  «ENDFOR»
                  «IF !isVoid»Object result = «ENDIF»proxy.«functionName»(«function.parameters.map[paramName.asParameter].join(", ")»)«IF !function.sync».get()«ENDIF»;
                  logger.info("Result of «apiName».«functionName»: «IF isVoid»void"«ELSE»" + result.toString()«ENDIF»);
                  }
                  catch (Exception e)
                  {
                     errorCount++;
                     logger.error("Result of «apiName».«functionName»: " + e.toString());
                  }
              «ENDFOR»
              
              logger.info("READY! Overall result: " + callCount + " function calls, " + errorCount + " errors.");
           }
        }
        '''
    }

}
