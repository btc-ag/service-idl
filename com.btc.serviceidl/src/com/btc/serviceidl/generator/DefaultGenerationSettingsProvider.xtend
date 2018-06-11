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
import java.util.Map
import java.util.HashMap
import com.btc.serviceidl.generator.cpp.CppConstants

class DefaultGenerationSettingsProvider implements IGenerationSettingsProvider
{
    public Set<ArtifactNature> languages
    public Set<ProjectType> projectTypes
    public IProjectSetFactory projectSetFactory
    public IModuleStructureStrategy moduleStructureStrategy
    static val Map<String, Set<String>> supportedVersionMap = createSupportedVersionMap
    val Map<String, String> versionMap

    new()
    {
        versionMap = createBareVersionMap
        reset
    }

    private static def createSupportedVersionMap()
    {
        val res = new HashMap<String, Set<String>>
        // TODO these should be registered by the respective generator plugins instead
        res.put(CppConstants.SERVICECOMM_VERSION_KIND, CppConstants.SERVICECOMM_VERSIONS)
        return res.immutableCopy
    }

    private def createBareVersionMap()
    {
        val res = new HashMap<String, String>
        for (versionKind : supportedVersionMap.keySet)
        {
            res.put(versionKind, null)
        }
        return res
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
        setVersion(CppConstants.SERVICECOMM_VERSION_KIND, "0.11")
    }

    def getVersionKinds()
    {
        versionMap.keySet.immutableCopy
    }

    def setVersion(String kind, String version)
    {
        val supportedVersions = supportedVersionMap.get(kind)
        if (supportedVersions === null)
        {
            throw new IllegalArgumentException("Version kind '" + kind + "' is unknown, known values are " +
                supportedVersionMap.keySet.join(", "))
        }
        if (!supportedVersions.contains(version))
        {
            throw new IllegalArgumentException(
                "Version '" + version + "' is not supported for '" + kind + "', supported versions are " +
                    supportedVersions.join(", ")
            )
        }
        versionMap.replace(kind, version)
    }

    override getProjectSetFactory()
    {
        projectSetFactory
    }

    override getModuleStructureStrategy()
    {
        moduleStructureStrategy
    }

    override getTargetVersion(String versionKind)
    {
        versionMap.get(versionKind)
    }

}
