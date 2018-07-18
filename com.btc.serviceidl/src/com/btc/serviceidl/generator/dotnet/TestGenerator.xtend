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
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class TestGenerator extends GeneratorBase
{
    def generateIntegrationTest(InterfaceDeclaration interfaceDeclaration, String className)
    {
        val apiClassName = resolve(interfaceDeclaration)
        val loggerFactory = resolve("BTC.CAB.Logging.Log4NET.Log4NETLoggerFactory")
        val serverRegistration = getServerRegistrationName(interfaceDeclaration)
        val connectionFactory = resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory")

        // explicit resolution of necessary assemblies
        resolve("BTC.CAB.Logging.API.NET.ILoggerFactory")
        resolve("BTC.CAB.ServiceComm.NET.Base.AServiceDispatcherBase")
        resolve("BTC.CAB.ServiceComm.NET.Common.IExtensible")
        resolve("BTC.CAB.ServiceComm.NET.ExtensionAPI.IServerFailureObservable")

        '''
            [«resolve("NUnit.Framework.TestFixture")»]
            public class «className» : «getTestClassName(interfaceDeclaration)»
            {
               private «apiClassName» _testSubject;
               
               private «resolve("BTC.CAB.ServiceComm.NET.API.IClient")» _client;
               private «serverRegistration» _serverRegistration;
               private «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.API.IConnectionFactory")» _serverConnectionFactory;
               private «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.Server")» _server;
               
               public «className»()
               {}
            
               [«resolve("NUnit.Framework.SetUp")»]
               public void SetupEndpoints()
               {
                  const «resolve("System.string")» connectionString = "tcp://127.0.0.1:«Constants.DEFAULT_PORT»";
                  
                  var loggerFactory = new «loggerFactory»();
                  
                  // server
                  StartServer(loggerFactory, connectionString);
                  
                  // client
                  var connectionOptions = «connectionFactory».«resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.API.ConnectionOptions").alias("DefaultClientConnectionOptions")»;
                  «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.API.IConnectionFactory")» connectionFactory = new «connectionFactory»(connectionOptions, loggerFactory);
                  _client = new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.Client")»(connectionString, new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.AsyncRpcClientEndpoint")»(loggerFactory), connectionFactory);
                  
                  _testSubject = «resolve(interfaceDeclaration, ProjectType.PROXY).alias(getProxyFactoryName(interfaceDeclaration))».CreateProtobufProxy(_client.ClientEndpoint);
               }
            
               private void StartServer(«loggerFactory» loggerFactory, string connectionString)
               {
                   var connectionOptions = «connectionFactory».«resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.API.ConnectionOptions").alias("DefaultServerConnectionOptions")»;
                  _serverConnectionFactory = new «connectionFactory»(connectionOptions, loggerFactory);
                  _server = new Server(connectionString, new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.AsyncRpcServerEndpoint")»(loggerFactory), _serverConnectionFactory);
                  _serverRegistration = new «serverRegistration»(_server);
                  _serverRegistration.RegisterService();
                  // ensure that the server runs when the client is created.
                  System.Threading.Thread.Sleep(1000);
               }
            
               [«resolve("NUnit.Framework.TearDown")»]
               public void TearDownClientEndpoint()
               {
                  _serverRegistration.Dispose();
                  _server.Dispose();
                  _testSubject = null;
                  if (_client != null)
                     _client.Dispose();
               }
            
               protected override «apiClassName» TestSubject
               {
                  get { return _testSubject; }
               }
            }
        '''

    }

    def generateImplTestStub(InterfaceDeclaration interfaceDeclaration, String className)
    {

        val apiClassName = resolve(interfaceDeclaration)

        '''
            [«resolve("NUnit.Framework.TestFixture")»]
            public class «className» : «getTestClassName(interfaceDeclaration)»
            {
               private «apiClassName» _testSubject;
               
               [«resolve("NUnit.Framework.SetUp")»]
               public void Setup()
               {
                  _testSubject = new «resolve(interfaceDeclaration, ProjectType.IMPL)»();
               }
               
               protected override «apiClassName» TestSubject
               {
                  get { return _testSubject; }
               }
            }
        '''
    }

    def generateCsTest(InterfaceDeclaration interfaceDeclaration, String className)
    {

        val aggregateException = resolve("System.AggregateException")
        val notImplementedException = resolve("System.NotSupportedException")

        '''
            public abstract class «className»
            {
               protected abstract «resolve(interfaceDeclaration)» TestSubject { get; }
            
               «FOR function : interfaceDeclaration.functions»
                   «val isSync = function.sync»
                   «val isVoid = function.returnedType instanceof VoidType»
                   [«resolve("NUnit.Framework.Test")»]
                   public void «function.name»Test()
                   {
                      var e = Assert.Catch(() =>
                      {
                         «FOR param : function.parameters»
                             var «param.paramName.asParameter» = «basicCSharpSourceGenerator.makeDefaultValue(param.paramType)»;
                         «ENDFOR»
                   «IF !isVoid»var «resolve(com.btc.serviceidl.util.Util.getUltimateType(function.returnedType.actualType)).alias("result")» = «ENDIF»TestSubject.«function.name»(«function.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT) "out " else "") + paramName.asParameter].join(", ")»)«IF !isSync».«IF isVoid»Wait()«ELSE»Result«ENDIF»«ENDIF»;
                   });
                   
                   var realException = (e is «aggregateException») ? (e as «aggregateException»).Flatten().InnerException : e;
                   
                   Assert.IsInstanceOf<«notImplementedException»>(realException);
                   Assert.IsTrue(realException.Message.Equals("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»"));
                   }
               «ENDFOR»
            }
        '''
    }
}
