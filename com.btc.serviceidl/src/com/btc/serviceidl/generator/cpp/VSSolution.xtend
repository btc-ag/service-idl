package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import java.util.HashMap
import java.util.Optional
import java.util.UUID

class VSSolution
{
    // it is important for this container to be static! if an *.IDL file contains
    // "import" references to external *.IDL files, each file will be generated separately
    // but we need consistent project GUIDs in order to create valid project references!
    private static val vs_projects = new HashMap<String, UUID>

    def String getVcxprojName(ParameterBundle builder, Optional<String> extra_name)
    {
        var project_name = GeneratorUtil.transform(builder, TransformType.PACKAGE)
        getVcxprojGUID(project_name)
        return project_name
    }

    def String getVcxprojGUID(String project_name)
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

    def add(String name, java.util.UUID uuid)
    {
        vs_projects.put(name, uuid)
    }

}
