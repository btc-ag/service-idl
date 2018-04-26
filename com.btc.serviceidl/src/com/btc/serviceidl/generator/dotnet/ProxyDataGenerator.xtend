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

import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ProxyDataGenerator extends GeneratorBase
{
    def generate(InterfaceDeclaration interface_declaration)
    {
        '''
            «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
                [«resolve("System.Runtime.Serialization.DataContract")»]
                internal class «getDataContractName(interface_declaration, function, ProtobufType.REQUEST)»
                {
                   «FOR param : function.parameters»
                       public «toText(param.paramType, function)» «param.paramName.asProperty» { get; set; }
                   «ENDFOR»
                }
                
                «IF !function.returnedType.isVoid»
                    [DataContract]
                    internal class «getDataContractName(interface_declaration, function, ProtobufType.RESPONSE)»
                    {
                       public «toText(function.returnedType, function)» «returnValueProperty» { get; set; }
                    }
                «ENDIF»
            «ENDFOR»
        '''

    }
}
