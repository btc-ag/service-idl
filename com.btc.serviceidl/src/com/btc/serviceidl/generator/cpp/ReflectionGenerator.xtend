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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class ReflectionGenerator extends BasicCppGenerator
{

    def generateImplFileBody(InterfaceDeclaration interface_declaration)
    {
        val class_name = resolve(interface_declaration, paramBundle.projectType)

        '''
            extern "C" 
            {
               «makeExportMacro()» void Reflect_«class_name.shortName»( «resolveCAB("BTC::Commons::CoreExtras::ReflectedClass")» &ci )
               {  
                  ci.Set< «class_name» >().AddConstructor
                  (
                      ci.CContextRef()
                     ,ci.CArgRefNotNull< «resolveCAB("BTC::Logging::API::LoggerFactory")» >( "loggerFactory" )
                     «IF paramBundle.projectType == ProjectType.PROXY»
                         ,ci.CArgRefNotNull< «resolveCAB("BTC::ServiceComm::API::IClientEndpoint")» >( "localEndpoint" )
                         ,ci.CArgRefOptional< «resolveCAB("BTC::Commons::CoreExtras::UUID")» >( "serverServiceInstanceGuid" )
                     «ELSEIF paramBundle.projectType == ProjectType.DISPATCHER»
                         ,ci.CArgRefNotNull< «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» >( "serviceEndpoint" )
                         ,ci.CArgRef< «resolveCAB("BTC::Commons::Core::AutoPtr")»<«resolve(interface_declaration, ProjectType.SERVICE_API)»> >( "dispatchee" )
                     «ENDIF»
                  );
               }
            }
        '''

    }
}
