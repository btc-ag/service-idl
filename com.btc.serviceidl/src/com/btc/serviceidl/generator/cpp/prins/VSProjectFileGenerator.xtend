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
    val IFileSystemAccess file_system_access
    val ParameterBundle param_bundle
    val IProjectSet projectSet
    val Iterable<IProjectReference> project_references

    val ProjectFileSet projectFileSet

    val ProjectType project_type
    val IPath project_path
    val String project_name

    def generate()
    {
        // root folder of the project
        file_system_access.generateFile(
            project_path + Constants.SEPARATOR_FILE + project_name.vcxproj,
            ArtifactNature.CPP.label,
            generateVcxproj(project_name)
        )
        file_system_access.generateFile(
            project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.filters,
            ArtifactNature.CPP.label,
            generateVcxprojFilters()
        )
        // *.vcxproj.user file for executable projects
        if (project_type == ProjectType.TEST || project_type == ProjectType.SERVER_RUNNER)
        {
            file_system_access.generateFile(
                project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.user,
                ArtifactNature.CPP.label,
                generateVcxprojUser(project_type)
            )
        }
    }

    private def generateVcxprojUser(ProjectType project_type)
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateVcxprojUser(project_type)
    }

    def getMyProjectReferences()
    {
        project_references.downcast
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
            param_bundle,
            vsSolution,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateVcxprojFilters()
    }

    private def String generateVcxproj(String project_name)
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generate(project_name, project_path).toString
    }

}
