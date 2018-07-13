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
 * \file       UniqueWrapper.xtend
 * 
 * \brief      Simple wrapper class to wrap a type in a Set to allow distinction
 * 
 * \details    For example, 2 different instances of a PrimitiveType "boolean" will
 *             be considered as 2 different element in a HashSet (due to how
 *             EMF EObject implements the comparison), but for us they are
 *             identical - simply a boolean (we deal with types, not with values here).
 *             If we wrap those objects into this wrapper before packing them
 *             into the Set, one will be recognized as duplicate.
 */
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.PrimitiveType
import org.eclipse.xtend.lib.annotations.Accessors

class UniqueWrapper
{
    @Accessors(PUBLIC_GETTER) private AbstractTypeReference type

    new(AbstractTypeReference t)
    {
        type = t
    }

    static def UniqueWrapper from(AbstractTypeReference e)
    {
        new UniqueWrapper(e)
    }

    override boolean equals(Object e)
    {
        if (e instanceof UniqueWrapper)
        {
            if (e.type instanceof PrimitiveType)
                return Names.plain(e.type) == Names.plain(type)
            else
                return type.equals(e.type)
        }

        return false
    }

    override int hashCode()
    {
        if (type instanceof PrimitiveType)
            Names.plain(type).hashCode
        else
            type.hashCode
    }
}
