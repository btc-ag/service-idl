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
import org.eclipse.xtend.lib.annotations.Data

@Data
class ParameterBundle
{
    Deque<ModuleDeclaration> moduleStack
    ProjectType projectType

    // TODO redesign this, the role of "master_data" is unclear and confusing
    static class Builder
    {
        Optional<ProjectType> project_type = Optional.empty
        var ParameterBundle master_data = null

        new()
        {
        }

        new(ParameterBundle bundle)
        {
            // TODO check if handling of projectType is correct
            this.master_data = new ParameterBundle(bundle.moduleStack, bundle.projectType)

            this.project_type = Optional.of(bundle.projectType)
        }

        def Builder reset(Iterable<ModuleDeclaration> element)
        {
            val moduleStack = new ArrayDeque<ModuleDeclaration>()
            moduleStack.addAll(element)
            master_data = new ParameterBundle(moduleStack, if (master_data !== null) master_data.projectType else null)
            this
        }

        def void reset(ProjectType element)
        {
            master_data = new ParameterBundle(if (master_data !== null) master_data.moduleStack else null, element)
        }

        def Builder with(ProjectType element)
        {
            project_type = Optional.of(element)
            return this
        }

        def ParameterBundle build()
        {
            val bundle = new ParameterBundle(master_data.moduleStack, if (project_type.present)
                project_type.get
            else
                master_data.projectType)

            project_type = Optional.empty

            return bundle
        }

        def ParameterBundle read()
        {
            return master_data
        }
    }

    static def Builder createBuilder(Iterable<ModuleDeclaration> module_stack)
    {
        val builder = new Builder
        builder.reset(module_stack)
        return builder
    }
}
