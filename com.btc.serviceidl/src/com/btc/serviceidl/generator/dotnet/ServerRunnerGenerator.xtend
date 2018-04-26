package com.btc.serviceidl.generator.dotnet

import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*

@Accessors(NONE)
class ServerRunnerGenerator extends GeneratorBase
{

    def generate(String class_name)
    {
        '''
            /// <summary>
            /// This application is a simplified copy of the BTC.CAB.ServiceComm.NET.ServerRunner. It only exists to have a context to start the demo server
            /// explicitly under this name or directly from VisualStudio. The configuration can also be used directly with the generic
            /// BTC.CAB.ServiceComm.NET.ServerRunner.
            /// </summary>
            public class «class_name»
            {
               public static int Main(«resolve("System.string")»[] args)
               {
                  var options = new «resolve("BTC.CAB.ServiceComm.NET.ServerRunner.ServerRunnerCommandLineOptions")»();
                  if (!«resolve("CommandLine.Parser")».Default.ParseArguments(args, options))
                  {
                     return 0;
                  }
            
                  «resolve("Spring.Context.IApplicationContext").alias("var")» ctx = «resolve("Spring.Context.Support.ContextRegistry")».GetContext();
               
                  try
                  {
                     var serverRunner = new «resolve("BTC.CAB.ServiceComm.NET.ServerRunner.SpringServerRunner")»(ctx, options.ConnectionString);
                     serverRunner.Start();
                     // shutdown
                     «resolve("System.Console")».WriteLine("Press any key to shutdown the server");
                     Console.Read();
                     serverRunner.Stop();
                     return 0;
                  }
                  catch («resolve("System.Exception")» e)
                  {
                     Console.WriteLine("Exception thrown by ServerRunner: "+ e);
                     return 1;
                  }
               }
            }
        '''
    }

}
