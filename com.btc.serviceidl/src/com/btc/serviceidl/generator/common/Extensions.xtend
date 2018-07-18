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

import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import org.eclipse.core.runtime.IPath

class Extensions
{
    static def ProjectType getMainProjectType(AbstractContainerDeclaration scopeDeterminant)
    {
        switch (scopeDeterminant)
        {
            InterfaceDeclaration:
                ProjectType.SERVICE_API
            ModuleDeclaration:
                ProjectType.COMMON
        }
    }

    /**
     * Allows to print the given text for any object: useful, when we need
     * to resolve a type, but do not want/may not print the resulting string.
     */
    static def String alias(ResolvedName object, String text)
    {
        text
    }

    static def toWindowsString(IPath path)
    {
        path.toPortableString.replace(IPath.SEPARATOR.toString, Constants.SEPARATOR_BACKSLASH)
    }
}
