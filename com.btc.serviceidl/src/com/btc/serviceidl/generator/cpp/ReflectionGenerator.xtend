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

    def generateImplFileBody(InterfaceDeclaration interfaceDeclaration)
    {
        val className = resolve(interfaceDeclaration, paramBundle.projectType)

        '''
            extern "C" 
            {
               «makeExportMacro()» void Reflect_«className.shortName»( «resolveSymbol("BTC::Commons::CoreExtras::ReflectedClass")» &ci )
               {  
                  ci.Set< «className» >().AddConstructor
                  (
                      ci.CContextRef()
                     ,ci.CArgRefNotNull< «resolveSymbol("BTC::Logging::API::LoggerFactory")» >( "loggerFactory" )
                     «IF paramBundle.projectType == ProjectType.PROXY»
                         ,ci.CArgRefNotNull< «resolveSymbol("BTC::ServiceComm::API::IClientEndpoint")» >( "localEndpoint" )
                         ,ci.CArgRefOptional< «resolveSymbol("BTC::Commons::CoreExtras::Optional")»<«resolveSymbol("BTC::Commons::CoreExtras::UUID")»> >( "serverServiceInstanceGuid" )
                     «ELSEIF paramBundle.projectType == ProjectType.DISPATCHER»
                         ,ci.CArgRefNotNull< «resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")» >( "serviceEndpoint" )
                         ,ci.CArgRef< «resolveSymbol("BTC::Commons::Core::AutoPtr")»<«resolve(interfaceDeclaration, ProjectType.SERVICE_API)»> >( "dispatchee" )
                     «ENDIF»
                  );
               }
            }
        '''

    }
}
