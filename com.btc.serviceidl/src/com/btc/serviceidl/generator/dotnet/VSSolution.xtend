package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import java.util.HashMap
import java.util.UUID
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.core.runtime.IPath

class VSSolution
{
    @Data
    static class Entry
    {
        UUID uuid
        IPath path
    }

    val vs_projects = new HashMap<String, Entry>

    def public String getCsprojName(ParameterBundle parameterBundle)
    {
        return registerCsprojGUID(
            parameterBundle
        )
    }

    private def registerCsprojGUID(ParameterBundle parameterBundle)
    {
        val projectName = GeneratorUtil.getTransformedModuleName(parameterBundle, ArtifactNature.DOTNET,
            TransformType.PACKAGE)
        if (!vs_projects.containsKey(projectName))
        {
            vs_projects.put(projectName,
                new Entry(UUID.nameUUIDFromBytes(projectName.bytes),
                    GeneratorUtil.asPath(parameterBundle, ArtifactNature.DOTNET)))
        }
        return projectName
    }

    def public String getCsprojGUID(String projectName)
    {
        return vs_projects.get(projectName).uuid.toString.toUpperCase
    }

    def getAllProjects()
    {
        return vs_projects.entrySet.immutableCopy
    }

}
