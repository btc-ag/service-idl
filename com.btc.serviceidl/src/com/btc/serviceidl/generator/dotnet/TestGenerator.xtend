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
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static com.btc.serviceidl.generator.dotnet.Util.*

import static extension com.btc.serviceidl.generator.common.Extensions.*

@Accessors(NONE)
class TestGenerator extends GeneratorBase
{
    def generateIntegrationTest(InterfaceDeclaration interface_declaration, String class_name)
    {
        val api_class_name = resolve(interface_declaration)
        val logger_factory = resolve("BTC.CAB.Logging.Log4NET.Log4NETLoggerFactory")
        val server_registration = getServerRegistrationName(interface_declaration)

        // explicit resolution of necessary assemblies
        resolve("BTC.CAB.Logging.API.NET.ILoggerFactory")
        resolve("BTC.CAB.ServiceComm.NET.Base.AServiceDispatcherBase")

        '''
            [«resolve("NUnit.Framework.TestFixture")»]
            public class «class_name» : «getTestClassName(interface_declaration)»
            {
               private «api_class_name» _testSubject;
               
               private «resolve("BTC.CAB.ServiceComm.NET.API.IClient")» _client;
               private «server_registration» _serverRegistration;
               private «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.API.IConnectionFactory")» _serverConnectionFactory;
               private «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.Server")» _server;
               
               public «class_name»()
               {}
            
               [«resolve("NUnit.Framework.SetUp")»]
               public void SetupEndpoints()
               {
                  const «resolve("System.string")» connectionString = "tcp://127.0.0.1:«Constants.DEFAULT_PORT»";
                  
                  var loggerFactory = new «logger_factory»();
                  
                  // server
                  StartServer(loggerFactory, connectionString);
                  
                  // client
                  «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.API.IConnectionFactory")» connectionFactory = new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.ZeroMqClientConnectionFactory")»(loggerFactory);
                  _client = new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.Client")»(connectionString, new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.AsyncRpcClientEndpoint")»(loggerFactory), connectionFactory);
                  
                  _testSubject = «resolve(interface_declaration, ProjectType.PROXY).alias(getProxyFactoryName(interface_declaration))».CreateProtobufProxy(_client.ClientEndpoint);
               }
            
               private void StartServer(«logger_factory» loggerFactory, string connectionString)
               {
                  _serverConnectionFactory = new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.ZeroMqServerConnectionFactory")»(loggerFactory);
                  _server = new Server(connectionString, new «resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.AsyncRpcServerEndpoint")»(loggerFactory), _serverConnectionFactory);
                  _serverRegistration = new «server_registration»(_server);
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
                  if (_client !== null)
                     _client.Dispose();
               }
            
               protected override «api_class_name» TestSubject
               {
                  get { return _testSubject; }
               }
            }
        '''

    }
}
