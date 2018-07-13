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
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ImplementationStubGenerator extends GeneratorBase
{

    private def makeImplementatonStub(FunctionDeclaration function)
    {
        val isVoid = function.returnedType instanceof VoidType

        '''
            «IF !function.sync»
                // TODO Auto-generated method stub
                «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                    «param.paramName.asParameter» = «basicCSharpSourceGenerator.makeDefaultValue(param.paramType)»;
                «ENDFOR»
                return «resolve("System.Threading.Tasks.Task")»«IF !isVoid»<«toText(function.returnedType, function)»>«ENDIF».Factory.StartNew(() => { throw new «resolve("System.NotSupportedException")»("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»"); });
            «ELSE»
                «makeDefaultMethodStub(typeResolver)»
            «ENDIF»
        '''
    }

    def generate(InterfaceDeclaration interfaceDeclaration, String implClassName)
    {
        val apiFullyQualifiedName = resolve(interfaceDeclaration)

        val anonymousEvent = com.btc.serviceidl.util.Util.getAnonymousEvent(interfaceDeclaration)
        '''
            public class «implClassName» : «IF anonymousEvent !== null»«resolve("BTC.CAB.ServiceComm.NET.Base.ABasicObservable")»<«resolve(anonymousEvent.data)»>, «ENDIF»«apiFullyQualifiedName.shortName»
            {
               «FOR function : interfaceDeclaration.functions SEPARATOR System.lineSeparator»
                   /// <see cref="«apiFullyQualifiedName».«function.name»"/>
                   public «typeResolver.makeReturnType(function)» «function.name»(
                      «FOR param : function.parameters SEPARATOR ","»
                          «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function).asParameter»
                      «ENDFOR»
                   )
                   {
                      «makeImplementatonStub(function)»
                   }
               «ENDFOR»
               
               «FOR event : interfaceDeclaration.events.filter[name !== null]»
                   «val eventName = toText(event, interfaceDeclaration)»
                   /// <see cref="«apiFullyQualifiedName».Get«eventName»"/>
                   public «eventName» Get«eventName»()
                   {
                      «makeDefaultMethodStub(typeResolver)»
                   }
               «ENDFOR»
            }
        '''

    }

}
