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

import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import java.util.ArrayList
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.util.Pair
import org.eclipse.xtext.util.Tuples

import static extension com.btc.serviceidl.generator.dotnet.Util.*

@Accessors(NONE)
class ServiceAPIGenerator extends GeneratorBase
{
    def generateEvent(EventDeclaration event)
    {

        val keys = new ArrayList<Pair<String, String>>
        for (key : event.keys)
        {
            keys.add(Tuples.create(key.keyName.asProperty, toText(key.type, event)))
        }

        '''
            public abstract class «toText(event, event)» : «resolve("System.IObservable")»<«toText(event.data, event)»>
            {
                  /// <see cref="IObservable{T}.Subscribe"/>
                  public abstract «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«toText(event.data, event)»> subscriber);
               
               «IF !keys.empty»
                   public class KeyType
                   {
                      
                      public KeyType(«FOR key : keys SEPARATOR ", "»«key.second» «key.first.asParameter»«ENDFOR»)
                      {
                         «FOR key : keys»
                             this.«key.first» = «key.first.asParameter»;
                         «ENDFOR»
                      }
                      
                      «FOR key : keys SEPARATOR System.lineSeparator»
                          public «key.second» «key.first.asProperty» { get; set; }
                      «ENDFOR»
                   }
                   
                   public abstract «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«toText(event.data, event)»> subscriber, «resolve("System.Collections.Generic.IEnumerable")»<KeyType> keys);
               «ENDIF»
            }
        '''

    }

    def generate(InterfaceDeclaration interface_declaration, AbstractTypeDeclaration abstract_type)
    {
        toText(abstract_type, interface_declaration)
    }

    def generateConstants(InterfaceDeclaration interface_declaration, String file_name)
    {
        '''
            public static class «file_name»
            {
               public static readonly «resolve("System.Guid")» «typeGuidProperty» = new Guid("«GuidMapper.get(interface_declaration)»");
               
               public static readonly «resolve("System.string")» «typeNameProperty» = typeof(«resolve(interface_declaration)»).FullName;
            }
        '''

    }

}
