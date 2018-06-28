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
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Data

@Data
class ParameterBundle
{
    val Iterable<ModuleDeclaration> moduleStack
    val ProjectType projectType

    // TODO redesign this, the role of "master_data" is unclear and confusing
    static class Builder
    {
        Optional<ProjectType> projectType = Optional.empty
        var ParameterBundle masterData = null

        new()
        {
        }

        new(ParameterBundle bundle)
        {
            // TODO check if handling of projectType is correct
            this.masterData = new ParameterBundle(bundle.moduleStack, bundle.projectType)

            this.projectType = Optional.of(bundle.projectType)
        }

        def Builder reset(Iterable<ModuleDeclaration> element)
        {
            masterData = new ParameterBundle(ImmutableList.copyOf(element),
                if (masterData !== null) masterData.projectType else null)
            this
        }

        def Builder with(ProjectType element)
        {
            projectType = Optional.of(element)
            return this
        }

        def ParameterBundle build()
        {
            val bundle = new ParameterBundle(masterData.moduleStack, if (projectType.present)
                projectType.get
            else
                masterData.projectType)

            projectType = Optional.empty

            return bundle
        }

        def ParameterBundle read()
        {
            return masterData
        }
    }

    static def Builder createBuilder(Iterable<ModuleDeclaration> moduleStack)
    {
        val builder = new Builder
        builder.reset(moduleStack)
        return builder
    }
}
