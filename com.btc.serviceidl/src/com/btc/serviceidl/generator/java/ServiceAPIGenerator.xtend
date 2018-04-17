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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import java.util.ArrayList
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ServiceAPIGenerator
{
    private val BasicJavaSourceGenerator basicJavaSourceGenerator
    private val ParameterBundle.Builder param_bundle

    def private getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def public generateEvent(EventDeclaration event)
    {
        val keys = new ArrayList<Pair<String, String>>
        for (key : event.keys)
        {
            keys.add(Pair.of(key.keyName, basicJavaSourceGenerator.toText(key.type)))
        }

        '''
            public abstract class «basicJavaSourceGenerator.toText(event)» implements «typeResolver.resolve(JavaClassNames.OBSERVABLE)»<«basicJavaSourceGenerator.toText(event.data)»> {
               
               «IF !keys.empty»
                   public class KeyType {
                      
                      «FOR key : keys»
                          private «key.value» «key.key»;
                      «ENDFOR»
                      
                      public KeyType(«FOR key : keys SEPARATOR ", "»«key.value» «key.key»«ENDFOR»)
                      {
                         «FOR key : keys»
                             this.«key.key» = «key.key»;
                         «ENDFOR»
                      }
                      
                      «FOR key : keys SEPARATOR System.lineSeparator»
                          «BasicJavaSourceGenerator.makeGetter(key.value, key.key)»
                      «ENDFOR»
                   }
                   
                   public abstract «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«basicJavaSourceGenerator.toText(event.data)»> subscriber, Iterable<KeyType> keys);
               «ENDIF»
            }
        '''
    }

    def generateMain(InterfaceDeclaration interface_declaration)
    {
        val anonymous_event = interface_declaration.anonymousEvent
        '''
        public interface «param_bundle.projectType.getClassName(param_bundle.artifactNature, interface_declaration.name)»«IF anonymous_event !== null» extends «typeResolver.resolve(JavaClassNames.OBSERVABLE)»<«basicJavaSourceGenerator.toText(anonymous_event.data)»>«ENDIF» {
        
           «typeResolver.resolve(JavaClassNames.UUID)» TypeGuid = UUID.fromString("«GuidMapper.get(interface_declaration)»");
           
           «FOR function : interface_declaration.functions»
               «basicJavaSourceGenerator.makeInterfaceMethodSignature(function)»;
               
           «ENDFOR»
           
           «FOR event : interface_declaration.events.filter[name !== null]»
               «val observable_name = basicJavaSourceGenerator.toText(event)»
               «observable_name» get«observable_name»();
           «ENDFOR»
        }
        '''
    }
    
    def generateContainedType(AbstractTypeDeclaration abstract_type) {
        basicJavaSourceGenerator.toDeclaration(abstract_type)
    }

}
