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
    val QualifiedName qualifiedName
    val TransformType transformType
    val boolean fullyQualified

    new(String name, TransformType tp)
    {
        this(QualifiedName.create(name.split(Pattern.quote(tp.separator))), tp, true)
    }

    new(String name, TransformType tp, boolean fullyQualified)
    {
        this(QualifiedName.create(name.split(Pattern.quote(tp.separator))), tp, fullyQualified)
    }

    new(QualifiedName qn, TransformType tp)
    {
        this(qn, tp, true)
    }

    new(QualifiedName qn, TransformType tp, boolean fullyQualified)
    {
        transformType = tp
        qualifiedName = qn
        this.fullyQualified = fullyQualified
    }

    def String getFullyQualifiedName()
    {
        GeneratorUtil.switchPackageSeperator(qualifiedName.toString, transformType)
    }

    def String getShortName()
    {
        qualifiedName.lastSegment
    }

    def String getNamespace()
    {
        qualifiedName.skipLast(1).toString
    }

    /**
     * By default, return the fully qualified name.
     */
    override String toString()
    {
        if (fullyQualified)
            fullyQualifiedName
        else
            return qualifiedName.lastSegment
    }
}
