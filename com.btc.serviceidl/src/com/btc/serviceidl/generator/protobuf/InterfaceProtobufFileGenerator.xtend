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

package com.btc.serviceidl.generator.protobuf

import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.util.Util
import java.util.concurrent.atomic.AtomicInteger
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.protobuf.ProtobufGeneratorUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
final class InterfaceProtobufFileGenerator extends ProtobufFileGeneratorBase
{
    def String generateInterface(InterfaceDeclaration interface_declaration)
    {
        var request_part_id = 1
        var response_part_id = 1

        var file_body = '''
            «generateFailable(interface_declaration)»
            «generateTypes(interface_declaration, interface_declaration.contains.toList)»
            
            message «interface_declaration.name.asRequest»
            {
               «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
                   message «function.name.asRequest»
                   {
                      «var field_id = new AtomicInteger»
                      «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                          «IF Util.isSequenceType(param.paramType)»
                              «makeSequence(Util.getUltimateType(param.paramType), Util.isFailable(param.paramType), param, interface_declaration, param.protoFileAttributeName, field_id)»
                          «ELSE»
                              required «resolve(param.paramType, interface_declaration, interface_declaration)» «param.protoFileAttributeName» = «field_id.incrementAndGet»;
                          «ENDIF»
                      «ENDFOR»
                   }
               «ENDFOR»
            
               «FOR function : interface_declaration.functions»
                   «val message_part = function.name.asRequest»
                   optional «message_part» «message_part.asProtoFileAttributeName» = «request_part_id++»;
               «ENDFOR»
            }
            
            message «interface_declaration.name.asResponse»
            {
               «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
                   message «function.name.asResponse»
                   {
                      «var field_id = new AtomicInteger»
                      «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                          «IF Util.isSequenceType(param.paramType)»
                              «val sequence = Util.tryGetSequence(param.paramType).get»
                              «toText(sequence, param, interface_declaration, field_id)»
                          «ELSE»
                              required «resolve(param.paramType, interface_declaration, interface_declaration)» «param.protoFileAttributeName» = «field_id.incrementAndGet»;
                          «ENDIF»
                      «ENDFOR»
                      «generateReturnType(function, interface_declaration, interface_declaration, field_id)»
                   }
               «ENDFOR»
            
               «FOR function : interface_declaration.functions»
                   «val message_part = function.name.asResponse»
                   optional «message_part» «message_part.asProtoFileAttributeName» = «response_part_id++»;
               «ENDFOR»
            }
        '''

        var file_header = '''
            «generatePackageName(interface_declaration)»
            «generateImports(interface_declaration)»
        '''

        return file_header + file_body
    }

    private def String generateReturnType(FunctionDeclaration function, EObject context, EObject container,
        AtomicInteger id)
    {
        val element = function.returnedType
        '''
            «IF !element.isVoid»
                «IF requiresNewMessageType(element)»
                    «toText(element, function, container, id)»
                «ELSE»
                    «IF Util.isSequenceType(element)»
                        «toText(element, function, container, id)»
                    «ELSE»
                        required «resolve(element, context, container)» «function.protoFileAttributeName» = «id.incrementAndGet»;
                    «ENDIF»
                «ENDIF»
            «ENDIF»
        '''
    }

}
