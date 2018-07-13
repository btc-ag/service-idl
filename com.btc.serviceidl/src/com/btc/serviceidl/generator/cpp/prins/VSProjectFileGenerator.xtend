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
package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import com.btc.serviceidl.util.Constants
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors
class VSProjectFileGenerator
{
    val IFileSystemAccess fileSystemAccess
    val ParameterBundle paramBundle
    val IProjectSet projectSet
    val Iterable<IProjectReference> projectReferences

    val ProjectFileSet projectFileSet

    val ProjectType projectType
    val IPath projectPath
    val String projectName

    def generate()
    {
        // root folder of the project
        fileSystemAccess.generateFile(
            projectPath + Constants.SEPARATOR_FILE + projectName.vcxproj,
            ArtifactNature.CPP.label,
            generateVcxproj(projectName)
        )
        fileSystemAccess.generateFile(
            projectPath + Constants.SEPARATOR_FILE + projectName.vcxproj.filters,
            ArtifactNature.CPP.label,
            generateVcxprojFilters()
        )
        // *.vcxproj.user file for executable projects
        if (projectType == ProjectType.TEST || projectType == ProjectType.SERVER_RUNNER)
        {
            fileSystemAccess.generateFile(
                projectPath + Constants.SEPARATOR_FILE + projectName.vcxproj.user,
                ArtifactNature.CPP.label,
                generateVcxprojUser(projectType)
            )
        }
    }

    private def generateVcxprojUser(ProjectType projectType)
    {
        new VcxProjGenerator(
            paramBundle,
            vsSolution,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateVcxprojUser(projectType)
    }

    def getMyProjectReferences()
    {
        projectReferences.downcast
    }

    static def private downcast(extension Iterable<IProjectReference> set)
    {
        set.map[it as VSSolution.ProjectReference].toSet
    }

    def getVsSolution()
    {
        // TODO inject this such that no dynamic cast is necessary
        projectSet as VSSolution
    }

    private def generateVcxprojFilters()
    {
        new VcxProjGenerator(
            paramBundle,
            vsSolution,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateVcxprojFilters()
    }

    private def String generateVcxproj(String projectName)
    {
        new VcxProjGenerator(
            paramBundle,
            vsSolution,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generate(projectName, projectPath).toString
    }

}
