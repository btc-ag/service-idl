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
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.generator.common.ParameterBundle.Builder
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.emf.ecore.EObject
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.util.Util

class Extensions
{
    static def ProjectType getProjectType(Builder param)
    {
        param.read.getProjectType
    }

    static def ProjectType getMainProjectType(EObject item)
    {
        val scope_determinant = Util.getScopeDeterminant(item)
        if (scope_determinant instanceof InterfaceDeclaration)
            return ProjectType.SERVICE_API

        if (scope_determinant instanceof ModuleDeclaration)
            return ProjectType.COMMON

        throw new IllegalArgumentException("Cannot determine main project type for " + item.toString)
    }

    /**
     * Allows to print the given text for any object: useful, when we need
     * to resolve a type, but do not want/may not print the resulting string.
     */
    static def String alias(ResolvedName object, String text)
    {
        text
    }

}
