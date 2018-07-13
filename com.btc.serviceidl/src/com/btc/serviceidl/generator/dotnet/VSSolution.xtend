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

    val vsProjects = new HashMap<String, Entry>

    def String getCsprojName(ParameterBundle parameterBundle)
    {
        return registerCsprojGUID(
            parameterBundle
        )
    }

    private def registerCsprojGUID(ParameterBundle parameterBundle)
    {
        val projectName = GeneratorUtil.getTransformedModuleName(parameterBundle, ArtifactNature.DOTNET,
            TransformType.PACKAGE)
        vsProjects.computeIfAbsent(projectName, [
            new Entry(UUID.nameUUIDFromBytes(projectName.bytes),
                GeneratorUtil.asPath(parameterBundle, ArtifactNature.DOTNET))
        ])
        return projectName
    }

    def String getCsprojGUID(ParameterBundle parameterBundle)
    {
        // TODO this is used to reference other projects. Make registration & referencing explicit, 
        // and check at the end of generation that all forward references have been resolved.
        vsProjects.get(registerCsprojGUID(parameterBundle)).uuid.toString.toUpperCase
    }

    def getAllProjects()
    {
        return vsProjects.entrySet.immutableCopy
    }

}
