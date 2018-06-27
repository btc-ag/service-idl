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
 * \file       ResolvedName.xtend
 * 
 * \brief      Type to represent an identifier which can be easily accessed 
 *             either by fully qualified name or by short name.
 */
package com.btc.serviceidl.generator.common

import org.eclipse.xtext.naming.QualifiedName
import java.util.regex.Pattern

class ResolvedName
{
    val QualifiedName qualified_name
    val TransformType transform_type
    val boolean fully_qualified

    new(String name, TransformType tp)
    {
        this(QualifiedName.create(name.split(Pattern.quote(tp.separator))), tp, true)
    }

    new(String name, TransformType tp, boolean fully_qualified)
    {
        this(QualifiedName.create(name.split(Pattern.quote(tp.separator))), tp, fully_qualified)
    }

    new(QualifiedName qn, TransformType tp)
    {
        this(qn, tp, true)
    }

    new(QualifiedName qn, TransformType tp, boolean fully_qualified)
    {
        transform_type = tp
        qualified_name = qn
        this.fully_qualified = fully_qualified
    }

    def String getFullyQualifiedName()
    {
        GeneratorUtil.switchPackageSeperator(qualified_name.toString, transform_type)
    }

    def String getShortName()
    {
        qualified_name.lastSegment
    }

    def String getNamespace()
    {
        qualified_name.skipLast(1).toString
    }

    /**
     * By default, return the fully qualified name.
     */
    override String toString()
    {
        if (fully_qualified)
            fullyQualifiedName
        else
            return qualified_name.lastSegment
    }
}
