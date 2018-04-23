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

import java.util.Deque
import java.util.Optional
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER)
class ParameterBundle
{
    private Deque<ModuleDeclaration> moduleStack
    private ArtifactNature artifactNature
    private Optional<ProjectType> projectType = Optional.empty

    // TODO redesign this, the role of "master_data" is unclear and confusing
    static class Builder
    {
        private Optional<ProjectType> project_type = Optional.empty
        private val master_data = new ParameterBundle
        
        new() {}
        
        new(ParameterBundle bundle) { 
            this.master_data.moduleStack = bundle.moduleStack
            this.master_data.artifactNature = bundle.artifactNature
            
            // TODO check if handling of projectType is correct
            this.master_data.projectType = bundle.projectType
            this.project_type = bundle.projectType
        }

        def Builder reset(ArtifactNature element)
        {
            master_data.artifactNature = element
            return this
        }

        def void reset(Deque<ModuleDeclaration> element)
        {
            master_data.moduleStack = element
        }

        def void reset(ProjectType element)
        {
            master_data.projectType = Optional.of(element)
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
                bundle.projectType = Optional.of(project_type.get)
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
        artifactNature = builder.master_data.artifactNature
        projectType = builder.master_data.projectType
    }
    
    def static Builder createBuilder(Deque<ModuleDeclaration> module_stack)
    {
        val builder = new Builder
        builder.reset(module_stack)
        return builder
    }
}
