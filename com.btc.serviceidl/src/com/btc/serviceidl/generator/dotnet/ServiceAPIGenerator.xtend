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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import java.util.ArrayList
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.util.Pair
import org.eclipse.xtext.util.Tuples

import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

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

    def generate(InterfaceDeclaration interfaceDeclaration, AbstractTypeDeclaration abstractType)
    {
        toText(abstractType, interfaceDeclaration)
    }

    def generateConstants(InterfaceDeclaration interfaceDeclaration, String fileName)
    {
        '''
            public static class «fileName»
            {
               public static readonly «resolve("System.Guid")» «typeGuidProperty» = new Guid("«GuidMapper.get(interfaceDeclaration)»");
               
               public static readonly «resolve("System.string")» «typeNameProperty» = typeof(«resolve(interfaceDeclaration)»).FullName;
            }
        '''
    }

    def generateInterface(InterfaceDeclaration interfaceDeclaration, String fileName)
    {
        val anonymousEvent = com.btc.serviceidl.util.Util.getAnonymousEvent(interfaceDeclaration)

        '''
            «IF !interfaceDeclaration.docComments.empty»
                /// <summary>
                «FOR comment : interfaceDeclaration.docComments»«toText(comment, comment)»«ENDFOR»
                /// </summary>
            «ENDIF»
            public interface «GeneratorUtil.getClassName(ArtifactNature.DOTNET, parameterBundle.projectType, interfaceDeclaration.name)»«IF anonymousEvent !== null» : «resolve("System.IObservable")»<«toText(anonymousEvent.data, anonymousEvent)»>«ENDIF»
            {
               
               «FOR function : interfaceDeclaration.functions SEPARATOR System.lineSeparator»
                   «val isVoid = function.returnedType instanceof VoidType»
                   /// <summary>
                   «FOR comment : function.docComments»«toText(comment, comment)»«ENDFOR»
                   /// </summary>
                   «FOR parameter : function.parameters»
                       /// <param name="«parameter.paramName.asParameter»"></param>
                   «ENDFOR»
                   «FOR exception : function.raisedExceptions»
                       /// <exception cref="«toText(exception, function)»"></exception>
                   «ENDFOR»
                   «IF !isVoid»/// <returns></returns>«ENDIF»
                   «typeResolver.makeReturnType(function)» «function.name»(
                      «FOR param : function.parameters SEPARATOR ","»
                          «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function)»
                      «ENDFOR»
                   );
               «ENDFOR»
               
               «FOR event : interfaceDeclaration.events.filter[name !== null]»
                   «toText(event, interfaceDeclaration)» Get«toText(event, interfaceDeclaration)»();
               «ENDFOR»
            }
        '''
    }

}
