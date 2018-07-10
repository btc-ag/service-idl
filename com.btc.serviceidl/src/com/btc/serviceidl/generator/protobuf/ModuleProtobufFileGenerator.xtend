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

import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(NONE)
final class ModuleProtobufFileGenerator extends ProtobufFileGeneratorBase
{
    def String generateModuleContent(ModuleDeclaration module, Iterable<EObject> moduleContents)
    {
        val fileBody = '''
            «generateFailable(module)»
            «generateTypes(module, module.moduleComponents.reject[it instanceof InterfaceDeclaration].toList)»
        '''

        val fileHeader = '''
            «generatePackageName(module)»
            «generateImports(module)»
        '''

        return fileHeader + fileBody
    }

}
