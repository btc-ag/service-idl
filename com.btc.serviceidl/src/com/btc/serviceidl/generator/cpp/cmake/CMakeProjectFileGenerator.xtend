/**
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import java.util.HashMap
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

@Accessors(NONE)
class CMakeProjectFileGenerator
{
    val IFileSystemAccess file_system_access
    val ParameterBundle param_bundle
    val IProjectSet projectSet
    val Map<String, Set<IProjectReference>> protobuf_project_references
    val Iterable<IProjectReference> project_references

    val ProjectFileSet projectFileSet

    val ProjectType project_type
    val IPath project_path
    val String project_name

    def generate()
    {
        file_system_access.generateFile(
            project_path.append("build").append("make.cmakeset").toString,
            generateCMakeSet().toString
        )
        file_system_access.generateFile(
            project_path.append("build").append("CMakeLists.txt").toString,
            generateCMakeLists().toString
        )
    }

    private def getMyProtobufProjectReferences()
    {
        if (protobuf_project_references === null) return null

        // TODO this should be possible to be simplified
        val res = new HashMap<String, Set<CMakeProjectSet.ProjectReference>>
        for (entry : protobuf_project_references.entrySet)
        {
            res.put(entry.key, entry.value.downcast)
        }
        return res
    }

    private def getMyProjectReferences()
    {
        project_references.downcast
    }

    def static private downcast(extension Iterable<IProjectReference> set)
    {
        set.map[it as CMakeProjectSet.ProjectReference].toSet
    }

    def getCMakeProjectSet()
    {
        // TODO inject this such that no dynamic cast is necessary
        projectSet as CMakeProjectSet
    }

    def private generateCMakeLists()
    {
        new CMakeGenerator(
            param_bundle,
            getCMakeProjectSet,
            myProtobufProjectReferences,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateCMakeLists(project_name, project_path)
    }

    def private generateCMakeSet()
    {
        new CMakeGenerator(
            param_bundle,
            getCMakeProjectSet,
            myProtobufProjectReferences,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateCMakeSet(project_name, project_path)
    }

}
