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
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.IProjectSetFactory
import com.btc.serviceidl.generator.dotnet.DotNetConstants
import com.btc.serviceidl.generator.java.JavaConstants
import java.util.HashMap
import java.util.Map
import java.util.Set

class DefaultGenerationSettings implements IGenerationSettings
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
    }

    private static def createSupportedVersionMap()
    {
        val res = new HashMap<String, Set<String>>
        // TODO these should be registered by the respective generator plugins instead
        res.put(CppConstants.SERVICECOMM_VERSION_KIND, CppConstants.SERVICECOMM_VERSIONS)
        res.put(DotNetConstants.SERVICECOMM_VERSION_KIND, DotNetConstants.SERVICECOMM_VERSIONS)
        res.put(JavaConstants.SERVICECOMM_VERSION_KIND, JavaConstants.SERVICECOMM_VERSIONS)
        return res.immutableCopy
    }

    private def createBareVersionMap()
    {
        supportedVersionMap.keySet.toMap([it], [null as String])
    }

    override getLanguages()
    {
        languages
    }

    override getProjectTypes()
    {
        projectTypes
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
