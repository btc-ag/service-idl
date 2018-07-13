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

import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors
class ImplementationStubGenerator extends BasicCppGenerator
{
    def generateCppImpl(InterfaceDeclaration interfaceDeclaration)
    {
        val className = resolve(interfaceDeclaration, paramBundle.projectType).shortName

        '''
            «className»::«className»
            (
               «resolveSymbol("BTC::Commons::Core::Context")»& context
               ,«resolveSymbol("BTC::Logging::API::LoggerFactory")»& loggerFactory
            ) :
            m_context(context)
            , «resolveSymbol("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
            «FOR event : interfaceDeclaration.events»
                , «event.observableName»(context)
            «ENDFOR»
            {}
            
            «generateCppDestructor(interfaceDeclaration)»
            
            «generateInheritedInterfaceMethods(interfaceDeclaration)»
            
            «FOR event : interfaceDeclaration.events»
                «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Disposable")»> «className»::Subscribe( «resolveSymbol("BTC::Commons::CoreExtras::IObserver")»<«toText(event.data, event)»> &observer )
                {
                   return «event.observableName».Subscribe(observer);
                }
            «ENDFOR»
        '''
    }

}
