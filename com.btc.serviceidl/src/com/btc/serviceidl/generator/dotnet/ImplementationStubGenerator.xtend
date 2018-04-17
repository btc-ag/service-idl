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

import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.Util.*

@Accessors(NONE)
class ImplementationStubGenerator extends GeneratorBase
{

    def generateStub(FunctionDeclaration function)
    {
        val is_void = function.returnedType.isVoid

        '''
            «IF !function.sync»
                // TODO Auto-generated method stub
                «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                    «param.paramName.asParameter» = «basicCSharpSourceGenerator.makeDefaultValue(param.paramType)»;
                «ENDFOR»
                return «resolve("System.Threading.Tasks.Task")»«IF !is_void»<«toText(function.returnedType, function)»>«ENDIF».Factory.StartNew(() => { throw new «resolve("System.NotSupportedException")»("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»"); });
            «ELSE»
                «makeDefaultMethodStub(typeResolver)»
            «ENDIF»
        '''
    }

}
