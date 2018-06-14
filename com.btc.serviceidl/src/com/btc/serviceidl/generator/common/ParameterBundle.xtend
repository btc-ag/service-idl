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
import java.util.ArrayDeque
import java.util.Deque
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER)
class ParameterBundle
{
    private Deque<ModuleDeclaration> moduleStack // TODO can't this be changed to Iterable?
    private ProjectType projectType

    // TODO redesign this, the role of "master_data" is unclear and confusing
    static class Builder
    {
        private Optional<ProjectType> project_type = Optional.empty
        val master_data = new ParameterBundle

        new()
        {
        }

        new(ParameterBundle bundle)
        {
            this.master_data.moduleStack = bundle.moduleStack

            // TODO check if handling of projectType is correct
            this.master_data.projectType = bundle.projectType
            this.project_type = Optional.of(bundle.projectType)
        }

        def Builder reset(Iterable<ModuleDeclaration> element)
        {
            master_data.moduleStack = new ArrayDeque<ModuleDeclaration>()
            master_data.moduleStack.addAll(element)
            this
        }

        def void reset(ProjectType element)
        {
            master_data.projectType = element
        }

        def Builder with(ProjectType element)
        {
            project_type = Optional.of(element)
            return this
        }

        def ParameterBundle build()
        {
            // initially same as default data
            val bundle = new ParameterBundle(this)

            if (project_type.present)
            {
                bundle.projectType = project_type.get
                project_type = Optional.empty // reset
            }

            return bundle
        }

        def ParameterBundle read()
        {
            return master_data
        }
    }

    private new()
    {
    }

    private new(Builder builder)
    {
        moduleStack = builder.master_data.moduleStack
        projectType = builder.master_data.projectType
    }

    static def Builder createBuilder(Iterable<ModuleDeclaration> module_stack)
    {
        val builder = new Builder
        builder.reset(module_stack)
        return builder
    }
}
