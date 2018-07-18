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

import com.btc.serviceidl.idl.AbstractTypeReference
import java.util.Collection
import java.util.LinkedHashSet
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER)
class TypeWrapper
{
    private AbstractTypeReference type
    private Collection<AbstractTypeReference> forwardDeclarations = new LinkedHashSet<AbstractTypeReference>
        
    def void addForwardDeclaration(AbstractTypeReference object)
    {
        forwardDeclarations.add(object)
    }

    def Iterable<AbstractTypeReference> getForwardDeclarations()
    {
        forwardDeclarations.unmodifiableView
    }

    new(AbstractTypeReference type)
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
