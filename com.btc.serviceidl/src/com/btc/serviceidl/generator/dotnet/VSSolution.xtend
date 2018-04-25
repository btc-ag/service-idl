package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.TransformType
import java.util.UUID
import java.util.HashMap
import com.btc.serviceidl.generator.common.ArtifactNature

class VSSolution
{
    private val vs_projects = new HashMap<String, UUID>

    def public String getCsprojName(ParameterBundle builder)
    {
        val project_name = GeneratorUtil.getTransformedModuleName(builder, ArtifactNature.DOTNET, TransformType.PACKAGE)
        getCsprojGUID(project_name)
        return project_name
    }

    def public String getCsprojGUID(String project_name)
    {
        var UUID guid
        if (vs_projects.containsKey(project_name))
            guid = vs_projects.get(project_name)
        else
        {
            guid = UUID.nameUUIDFromBytes(project_name.bytes)
            vs_projects.put(project_name, guid)
        }
        return guid.toString.toUpperCase
    }

}
