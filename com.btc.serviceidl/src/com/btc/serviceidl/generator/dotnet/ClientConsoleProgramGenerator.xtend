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
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ClientConsoleProgramGenerator
{
    val extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
    val NuGetPackageResolver nuget_packages

    private def getTypeResolver()
    {
        basicCSharpSourceGenerator.typeResolver
    }

    def generate(String class_name, ModuleDeclaration module)
    {
        nuget_packages.resolvePackage("CommandLine")

        val console = typeResolver.resolve("System.Console")
        val exception = typeResolver.resolve("System.Exception")
        val aggregate_exception = typeResolver.resolve("System.AggregateException")

        '''
            internal class «class_name»
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
                  
                  «FOR interface_declaration : module.moduleComponents.filter(InterfaceDeclaration)»
                      «val proxy_name = interface_declaration.name.toFirstLower + "Proxy"»
                      // «interface_declaration.name» proxy
                      var «proxy_name» = «typeResolver.resolve(interface_declaration, ProjectType.PROXY).alias(getProxyFactoryName(interface_declaration))».CreateProtobufProxy(client.ClientEndpoint);
                      TestRequestResponse«interface_declaration.name»(«proxy_name»);
                      
                  «ENDFOR»
                  
                  client.Dispose();
                  return 0;
               }
               
               «FOR interface_declaration : module.moduleComponents.filter(InterfaceDeclaration)»
                   «val api_name = typeResolver.resolve(interface_declaration).shortName»
                   private static void TestRequestResponse«interface_declaration.name»(«typeResolver.resolve(interface_declaration)» proxy)
                   {
                      var errorCount = 0;
                      var callCount = 0;
                      «FOR function : interface_declaration.functions»
                          «val is_void = function.returnedType.isVoid»
                          try
                          {
                             callCount++;
                             «FOR param : function.parameters»
                                 var «param.paramName.asParameter» = «makeDefaultValue(basicCSharpSourceGenerator, param.paramType)»;
                             «ENDFOR»
                      «IF !is_void»var «typeResolver.resolve(com.btc.serviceidl.util.Util.getUltimateType(function.returnedType)).alias("result")» = «ENDIF»proxy.«function.name»(«function.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT) "out " else "") + paramName.asParameter].join(", ")»)«IF !function.sync».«IF is_void»Wait()«ELSE»Result«ENDIF»«ENDIF»;
                      «console».WriteLine("Result of «api_name».«function.name»: «IF is_void»Void"«ELSE»" + result.ToString()«ENDIF»);
                      }
                      catch («exception» e)
                      {
                         errorCount++;
                         var realException = (e is «aggregate_exception») ? (e as «aggregate_exception»).Flatten().InnerException : e;
                         «console».WriteLine("Result of «api_name».«function.name»: " + realException.ToString());
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
