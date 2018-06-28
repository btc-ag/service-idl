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
 * \file       ParameterBundle.xtend
 * 
 * \brief      Parameter aggregation class with a builder
 */
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.idl.ModuleDeclaration
import com.google.common.collect.ImmutableList
import org.eclipse.xtend.lib.annotations.Data

@Data
class ParameterBundle
{
    val Iterable<ModuleDeclaration> moduleStack
    val ProjectType projectType

    static class Builder
    {
        var Iterable<ModuleDeclaration> moduleStack = null
        var ProjectType projectType = null

        new()
        {
        }

        new(ParameterBundle bundle)
        {
            this.moduleStack = bundle.moduleStack
            this.projectType = bundle.projectType
        }

        def Builder reset(Iterable<ModuleDeclaration> element)
        {
            this.moduleStack = ImmutableList.copyOf(element)
            this
        }

        def Builder with(ProjectType element)
        {
            this.projectType = element
            this
        }

        def ParameterBundle build()
        {
            if (this.moduleStack === null)
                throw new UnsupportedOperationException("Builder is incomplete")
                
            val bundle = new ParameterBundle(this.moduleStack, this.projectType)

            this.moduleStack = null
            this.projectType = null

            bundle
        }
    }

    static def Builder createBuilder(Iterable<ModuleDeclaration> moduleStack)
    {
        val builder = new Builder
        builder.reset(moduleStack)
        return builder
    }
}
