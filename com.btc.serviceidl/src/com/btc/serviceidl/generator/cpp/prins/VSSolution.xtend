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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.prins.VSSolution.Entry
import com.btc.serviceidl.util.Constants
import java.util.HashMap
import java.util.UUID
import org.eclipse.xtend.lib.annotations.Data
import com.btc.serviceidl.generator.common.ArtifactNature

class VSSolution implements IProjectSet
{
// it is important for this container to be static! if an *.IDL file contains
// "import" references to external *.IDL files, each file will be generated separately
// but we need consistent project GUIDs in order to create valid project references!
    private static val vs_projects = new HashMap<String, Entry>

    @Data
    private static class Entry
    {
        UUID uuid
        String path
    }

    override String getVcxprojName(ParameterBundle paramBundle)
    {
        var project_name = GeneratorUtil.transform(paramBundle, ArtifactNature.CPP, TransformType.PACKAGE)
        val projectPath = makeProjectPath(paramBundle, project_name)
        ensureEntryExists(project_name, projectPath)
        return project_name
    }

    protected def ensureEntryExists(String project_name, String projectPath)
    {
        if (!vs_projects.containsKey(project_name))
        {
            val guid = UUID.nameUUIDFromBytes(project_name.bytes)
            vs_projects.put(project_name, new Entry(guid, projectPath))
        }
        else
        {
            val entry = vs_projects.get(project_name)
            if (!entry.path.equals(projectPath))
            {
                throw new IllegalArgumentException(
                    "Project path inconsistency: existing entry has " + entry.path + ", new value is " + projectPath)
            }
        }
    }

    def String getVcxprojGUID(ProjectReference projectReference)
    {
        return vs_projects.get(projectReference.projectName).uuid.toString.toUpperCase
    }

    override ProjectReference resolveClass(String className)
    {
        val project_reference = ReferenceResolver.getProjectReference(className)
        add(project_reference.project_name, UUID.fromString(project_reference.project_guid),
            project_reference.project_path)
    }

    @Deprecated
    def resolve(String projectName, String projectPath)
    {
        var effectiveProjectPath = projectPath.replace("cpp/", "")
        effectiveProjectPath = if (effectiveProjectPath.endsWith("/")) effectiveProjectPath.substring(0,
            effectiveProjectPath.length - 1) else effectiveProjectPath
        ensureEntryExists(projectName, makeProjectPath(effectiveProjectPath, projectName))
        new ProjectReference(projectName)
    }

    override ProjectReference resolve(ParameterBundle paramBundle)
    {
        new ProjectReference(getVcxprojName(paramBundle))
    }

    private def add(String name, UUID uuid, String project_path)
    {
        vs_projects.put(name, new Entry(uuid, project_path))
        new ProjectReference(name)
    }

    @Data
    static class ProjectReference implements IProjectReference
    {
        val String projectName
    }

    def getVcxProjPath(ProjectReference project_name)
    {
        vs_projects.get(project_name.projectName).path
    }

    private static def String makeProjectPath(ParameterBundle paramBundle, String project_name)
    {
        makeProjectPath(GeneratorUtil.transform(paramBundle, ArtifactNature.CPP, TransformType.FILE_SYSTEM), project_name)
    }

    private static def String makeProjectPath(String projectPath, String project_name)
    {
        '''$(SolutionDir)\«projectPath.replace(Constants.SEPARATOR_FILE, Constants.SEPARATOR_BACKSLASH)»\«project_name»'''
    }
}
