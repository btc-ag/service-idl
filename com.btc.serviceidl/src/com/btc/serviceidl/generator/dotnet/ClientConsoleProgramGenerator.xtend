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
package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ClientConsoleProgramGenerator
{
    val extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
    val NuGetPackageResolver nugetPackages

    private def getTypeResolver()
    {
        basicCSharpSourceGenerator.typeResolver
    }

    def generate(String className, ModuleDeclaration module)
    {
        nugetPackages.resolvePackage("CommandLine")

        val console = typeResolver.resolve("System.Console")
        val exception = typeResolver.resolve("System.Exception")
        val aggregateException = typeResolver.resolve("System.AggregateException")

        '''
            internal class «className»
            {
               private static int Main(«typeResolver.resolve("System.string")»[] args)
               {
                  var options = new Options();
                  if (!Parser.Default.ParseArguments(args, options))
                  {
                     return 0;
                  }
            
                  var ctx = «typeResolver.resolve("Spring.Context.Support.ContextRegistry")».GetContext();
                  
                  var loggerFactory = («typeResolver.resolve("BTC.CAB.Logging.API.NET.ILoggerFactory")») ctx.GetObject("BTC.CAB.Logging.API.NET.LoggerFactory");
                  var logger = loggerFactory.GetLogger(typeof (Program));
                  logger.«typeResolver.resolve("BTC.CAB.Commons.Core.NET.CodeWhere").alias("Info")»("ConnectionString: " + options.ConnectionString);
                  
                  var clientFactory = («typeResolver.resolve("BTC.CAB.ServiceComm.NET.API.IClientFactory")») ctx.GetObject("BTC.CAB.ServiceComm.NET.API.ClientFactory");
                  
                  var client = clientFactory.Create(options.ConnectionString);
                  
                  «FOR interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration)»
                      «val proxyName = interfaceDeclaration.name.toFirstLower + "Proxy"»
                      // «interfaceDeclaration.name» proxy
                      var «proxyName» = «typeResolver.resolve(interfaceDeclaration, ProjectType.PROXY).alias(getProxyFactoryName(interfaceDeclaration))».CreateProtobufProxy(client.ClientEndpoint);
                      TestRequestResponse«interfaceDeclaration.name»(«proxyName»);
                      
                  «ENDFOR»
                  
                  client.Dispose();
                  return 0;
               }
               
               «FOR interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration)»
                   «val apiName = typeResolver.resolve(interfaceDeclaration).shortName»
                   private static void TestRequestResponse«interfaceDeclaration.name»(«typeResolver.resolve(interfaceDeclaration)» proxy)
                   {
                      var errorCount = 0;
                      var callCount = 0;
                      «FOR function : interfaceDeclaration.functions»
                          «val isVoid = function.returnedType instanceof VoidType»
                          try
                          {
                             callCount++;
                             «FOR param : function.parameters»
                                 var «param.paramName.asParameter» = «makeDefaultValue(basicCSharpSourceGenerator, param.paramType)»;
                             «ENDFOR»
                      «IF !isVoid»var «typeResolver.resolve(function.returnedType.actualType.ultimateType).alias("result")» = «ENDIF»proxy.«function.name»(«function.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT) "out " else "") + paramName.asParameter].join(", ")»)«IF !function.sync».«IF isVoid»Wait()«ELSE»Result«ENDIF»«ENDIF»;
                      «console».WriteLine("Result of «apiName».«function.name»: «IF isVoid»Void"«ELSE»" + result.ToString()«ENDIF»);
                      }
                      catch («exception» e)
                      {
                         errorCount++;
                         var realException = (e is «aggregateException») ? (e as «aggregateException»).Flatten().InnerException : e;
                         «console».WriteLine("Result of «apiName».«function.name»: " + realException.ToString());
                          }
               «ENDFOR»
               
               «console».WriteLine("");
               «console».ForegroundColor = ConsoleColor.Yellow;
               «console».WriteLine("READY! Overall result: " + callCount + " function calls, " + errorCount + " errors.");
               «console».ResetColor();
               «console».WriteLine("Press any key to exit...");
               «console».ReadLine();
               }
               «ENDFOR»
            
               private class Options
               {
                  [«typeResolver.resolve("CommandLine.Option")»('c', "connectionString", DefaultValue = null,
                     HelpText = "connection string, e.g. tcp://127.0.0.1:12345 (for ZeroMQ).")]
                  public string ConnectionString { get; set; }
                  
                  [Option('f', "configurationFile", DefaultValue = null,
                     HelpText = "file that contains an alternative spring configuration. By default this is taken from the application configuration.")]
                  public string ConfigurationFile { get; set; }
                  
                  [ParserState]
                  public «typeResolver.resolve("CommandLine.IParserState")» LastParserState { get; set; }
                  
                  [HelpOption]
                  public string GetUsage()
                  {
                     return «typeResolver.resolve("CommandLine.Text.HelpText")».AutoBuild(this,
                        (HelpText current) => HelpText.DefaultParsingErrorsHandler(this, current));
                  }
               }
            }
        '''
    }

}
