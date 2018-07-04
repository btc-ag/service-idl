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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.ExternalDependency
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

@Accessors(NONE)
class CMakeProjectFileGenerator
{
    val IFileSystemAccess fileSystemAccess
    val ParameterBundle parameterBundle
    val Iterable<ExternalDependency> externalDependencies
    val Map<IProjectReference, Set<IProjectReference>> protobufProjectReferences
    val Iterable<IProjectReference> projectReferences

    val ProjectFileSet projectFileSet

    val ProjectType projectType
    val IPath projectPath
    val String projectName

    def generate()
    {
        fileSystemAccess.generateFile(
            projectPath.append("build").append("make.cmakeset").toString,
            ArtifactNature.CPP.label,
            generateCMakeSet().toString
        )
        fileSystemAccess.generateFile(
            projectPath.append("build").append("CMakeLists.txt").toString,
            ArtifactNature.CPP.label,
            generateCMakeLists().toString
        )
    }

    private def getMyProtobufProjectReferences()
    {
        protobufProjectReferences?.entrySet.toMap([it.key as CMakeProjectSet.ProjectReference], [it.value.downcast])
    }

    private def getMyProjectReferences()
    {
        projectReferences.downcast
    }

    static def private downcast(extension Iterable<IProjectReference> set)
    {
        set.map[it as CMakeProjectSet.ProjectReference].toSet
    }

    private def generateCMakeLists()
    {
        new CMakeGenerator(
            parameterBundle,
            externalDependencies,
            myProtobufProjectReferences,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateCMakeLists(projectName, projectPath, projectType)
    }

    private def generateCMakeSet()
    {
        new CMakeGenerator(
            parameterBundle,
            externalDependencies,
            myProtobufProjectReferences,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateCMakeSet(projectName, projectPath)
    }

}
