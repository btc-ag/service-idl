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
/**
 * \file       TypeWrapper.xtend
 * 
 * \brief      Wrapper class to ease calculation and retrieval of mutual dependencies.
 */
package com.btc.serviceidl.generator.common

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import java.util.Collection
import java.util.LinkedHashSet

@Accessors(PUBLIC_GETTER)
class TypeWrapper
{
    private EObject type
    private Collection<EObject> forwardDeclarations = new LinkedHashSet<EObject>

    new(EObject type)
    {
        this.type = type
    }

    override boolean equals(Object e)
    {
        if (e !== null && e instanceof TypeWrapper)
        {
            return (e as TypeWrapper).type.equals(type)
        }

        return false
    }
}
