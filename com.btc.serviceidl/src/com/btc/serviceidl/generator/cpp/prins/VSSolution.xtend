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
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import java.util.HashMap
import java.util.UUID
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Data

class VSSolution implements IProjectSet
{
// it is important for this container to be static! if an *.IDL file contains
// "import" references to external *.IDL files, each file will be generated separately
// but we need consistent project GUIDs in order to create valid project references!
    static val vs_projects = new HashMap<String, Entry>

    @Data
    private static class Entry
    {
        UUID uuid
        IPath path
    }

    override String getVcxprojName(ParameterBundle paramBundle)
    {
        var project_name = GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP,
            TransformType.PACKAGE)
        val projectPath = makeProjectPath(paramBundle, project_name)
        ensureEntryExists(project_name, projectPath)
        return project_name
    }

    protected def ensureEntryExists(String project_name, IPath projectPath)
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

    @Deprecated
    def resolve(String projectName, IPath projectPath)
    {
        // TODO this depends on the implementation of ProjectGeneratorBaseBase.getProjectPath
        // TODO check if the else branch is valid
        var effectiveProjectPath = if (projectPath.segment(0) ==
                PrinsModuleStructureStrategy.MODULES_HEADER_PATH_PREFIX)
                projectPath.removeFirstSegments(1)
            else
                projectPath
        ensureEntryExists(projectName, makeProjectPath(effectiveProjectPath, projectName))
        new ProjectReference(projectName)
    }

    override ProjectReference resolve(ParameterBundle paramBundle)
    {
        new ProjectReference(getVcxprojName(paramBundle))
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

    private static def IPath makeProjectPath(ParameterBundle paramBundle, String project_name)
    {
        makeProjectPath(GeneratorUtil.asPath(paramBundle, ArtifactNature.CPP), project_name)
    }

    private static def IPath makeProjectPath(IPath projectPath, String project_name)
    {
        projectPath.append(project_name)
    }
}
