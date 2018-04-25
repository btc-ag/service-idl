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
    private Deque<ModuleDeclaration> module_stack
    private TransformType transform_type
    private ArtifactNature artifact_nature
    private Optional<ProjectType> project_type = Optional.empty

    // TODO redesign this, the role of "master_data" is unclear and confusing
    static class Builder
    {
        private Optional<TransformType> transform_type = Optional.empty
        private Optional<ProjectType> project_type = Optional.empty
        private val master_data = new ParameterBundle

        def Builder reset(ArtifactNature element)
        {
            master_data.artifact_nature = element
            return this
        }

        def void reset(Deque<ModuleDeclaration> element)
        {
            master_data.module_stack = element
        }

        def void reset(ProjectType element)
        {
            master_data.project_type = Optional.of(element)
        }

        def Builder with(TransformType element)
        {
            transform_type = Optional.of(element)
            return this
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

            // overwrite with optionally provided values, if applicable
            if (transform_type.present)
            {
                bundle.transform_type = transform_type.get
                transform_type = Optional.empty // reset
            }

            if (project_type.present)
            {
                bundle.project_type = Optional.of(project_type.get)
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
        module_stack = builder.master_data.module_stack
        artifact_nature = builder.master_data.artifact_nature
        transform_type = builder.master_data.transform_type
        project_type = builder.master_data.project_type
    }
    
    def static Builder createBuilder(Deque<ModuleDeclaration> module_stack)
    {
        val builder = new Builder
        builder.reset(module_stack)
        return builder
    }
}
