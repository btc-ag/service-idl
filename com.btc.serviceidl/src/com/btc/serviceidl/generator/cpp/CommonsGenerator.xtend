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

import com.btc.serviceidl.generator.common.FeatureProfile
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

import static com.btc.serviceidl.generator.cpp.TypeResolverExtensions.*

import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*

@Accessors
class CommonsGenerator extends BasicCppGenerator
{

    def generateHeaderFileBody(ModuleDeclaration module, String string)
    {
        val sorted_types = module.topologicallySortedTypes
        val forward_declarations = resolveForwardDeclarations(sorted_types)
      
        '''
         «FOR type : forward_declarations»
            struct «Names.plain(type)»;
         «ENDFOR»

         «FOR wrapper : sorted_types»
            «toText(wrapper.type, module)»

         «ENDFOR»
        '''
    }

    def generateImplFileBody(ModuleDeclaration module, String string)
    {
      // for optional element, include the impl file!
      if ( new FeatureProfile(module.moduleComponents).uses_optionals
         || !module.eAllContents.filter(SequenceDeclaration).filter[failable].empty
      )
      {
         resolveCABImpl("BTC::Commons::CoreExtras::Optional")
      }
           
      // resolve any type to include the header: important for *.lib file
      // to be built even if there is no actual content in the *.cpp file
      resolve(module.moduleComponents.filter[o | !(o instanceof ModuleDeclaration)
         && !(o instanceof InterfaceDeclaration)].head)

      '''
          «FOR exception : module.moduleComponents.filter(ExceptionDeclaration)»
             «makeExceptionImplementation(exception)»
          «ENDFOR»
          
          «makeEventGUIDImplementations(typeResolver, idl, module.moduleComponents.filter(StructDeclaration))»
      '''
    }
}
