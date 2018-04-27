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

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import com.btc.serviceidl.util.Constants
import java.util.HashMap
import java.util.Map
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors
class VSProjectFileGenerator
{
    val IFileSystemAccess file_system_access
    val ParameterBundle param_bundle
    val IProjectSet projectSet
    val Map<String, Set<IProjectReference>> protobuf_project_references
    val Iterable<IProjectReference> project_references

    val ProjectFileSet projectFileSet

    val ProjectType project_type
    val String project_path
    val String project_name

    def generate()
    {
        // root folder of the project
        file_system_access.generateFile(
            project_path + Constants.SEPARATOR_FILE + project_name.vcxproj,
            generateVcxproj(project_name)
        )
        file_system_access.generateFile(
            project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.filters,
            generateVcxprojFilters()
        )
        // *.vcxproj.user file for executable projects
        if (project_type == ProjectType.TEST || project_type == ProjectType.SERVER_RUNNER)
        {
            file_system_access.generateFile(
                project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.user,
                generateVcxprojUser(project_type)
            )
        }
    }

    def private generateVcxprojUser(ProjectType project_type)
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            myProtobufProjectReferences,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateVcxprojUser(project_type)
    }

    def getMyProtobufProjectReferences()
    {
        if (protobuf_project_references === null) return null

        // TODO this should be possible to be simplified
        val res = new HashMap<String, Set<VSSolution.ProjectReference>>
        for (entry : protobuf_project_references.entrySet)
        {
            res.put(entry.key, entry.value.downcast)
        }
        return res
    }

    def getMyProjectReferences()
    {
        project_references.downcast
    }

    def static private downcast(extension Iterable<IProjectReference> set)
    {
        set.map[it as VSSolution.ProjectReference].toSet
    }

    def getVsSolution()
    {
        // TODO inject this such that no dynamic cast is necessary
        projectSet as VSSolution
    }

    def private generateVcxprojFilters()
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            myProtobufProjectReferences,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateVcxprojFilters()
    }

    def private String generateVcxproj(String project_name)
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            myProtobufProjectReferences,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generate(project_name, project_path).toString
    }

}
