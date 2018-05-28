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
package com.btc.serviceidl.generator

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.IProjectSetFactory
import com.btc.serviceidl.generator.cpp.prins.PrinsModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.prins.VSSolutionFactory
import java.util.Arrays
import java.util.HashSet
import java.util.Set

class DefaultGenerationSettingsProvider implements IGenerationSettingsProvider
{

    public Set<ArtifactNature> languages
    public Set<ProjectType> projectTypes
    public IProjectSetFactory projectSetFactory
    public IModuleStructureStrategy moduleStructureStrategy

    new()
    {
        reset
    }

    override getLanguages()
    {
        languages
    }

    override getProjectTypes()
    {
        projectTypes
    }

    def reset()
    {
        languages = new HashSet<ArtifactNature>(
            Arrays.asList(ArtifactNature.CPP, ArtifactNature.JAVA, ArtifactNature.DOTNET));
        projectTypes = new HashSet<ProjectType>(
            Arrays.asList(ProjectType.SERVICE_API, ProjectType.PROXY, ProjectType.DISPATCHER, ProjectType.IMPL,
                ProjectType.PROTOBUF, ProjectType.COMMON, ProjectType.TEST, ProjectType.SERVER_RUNNER,
                ProjectType.CLIENT_CONSOLE, ProjectType.EXTERNAL_DB_IMPL));
        projectSetFactory = new VSSolutionFactory
        moduleStructureStrategy = new PrinsModuleStructureStrategy
    }
    
    override getProjectSetFactory() {
        projectSetFactory
    }
    
    override getModuleStructureStrategy() {
        moduleStructureStrategy
    }

}
