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
package com.btc.serviceidl.generator.protobuf

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.generator.java.MavenResolver
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import com.google.common.base.CaseFormat
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.Path
import org.eclipse.emf.ecore.EObject

import static com.btc.serviceidl.generator.common.GeneratorUtil.*

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.util.Util.*

class ProtobufGeneratorUtil
{
    static def getModuleName(EObject objectRoot, ArtifactNature artifactNature)
    {
        if (artifactNature != ArtifactNature.JAVA)
            GeneratorUtil.getTransformedModuleName(ParameterBundle.createBuilder(objectRoot.moduleStack).with(
                ProjectType.PROTOBUF).build, artifactNature, TransformType.PACKAGE)
        else
            MavenResolver.makePackageId(objectRoot, ProjectType.PROTOBUF)
    }

    // TODO remove remaining calls to this method by calls based on model elements rather than String
    static def asProtoFileAttributeName(String name)
    {
        asProtobufName(name, CaseFormat.LOWER_UNDERSCORE)
    }

    static def protoFileAttributeName(FunctionDeclaration element)
    {
        asProtoFileAttributeName(element.name)
    }

    static def protoFileAttributeName(ParameterElement element)
    {
        asProtoFileAttributeName(element.paramName)
    }

    static def protoFileAttributeName(MemberElementWrapper element)
    {
        // TODO why is toLowerCase required here? Probably it can be removed
        asProtoFileAttributeName(element.name).toLowerCase
    }

    static def IPath makeProtobufPath(EObject container, String fileName, ArtifactNature artifact_nature,
        IModuleStructureStrategy moduleStructureStrategy)
    {
        makeProtobufModulePath(container, artifact_nature, moduleStructureStrategy).append(fileName.proto)
    }

    static def IPath makeProtobufModulePath(EObject container, ArtifactNature artifactNature,
        IModuleStructureStrategy moduleStructureStrategy)
    {
        // TODO unify this across target technologies
        if (artifactNature == ArtifactNature.JAVA)
        {
            Path.fromPortableString(MavenResolver.makePackageId(container, ProjectType.PROTOBUF)).append("src").append(
                "main").append("proto")
        }
        else
        {
            val containerParameterBundle = ParameterBundle.createBuilder(container.moduleStack).with(
                ProjectType.PROTOBUF).build()

            (if (artifactNature == ArtifactNature.CPP)
                moduleStructureStrategy.getProjectDir(containerParameterBundle)
            else
                GeneratorUtil.asPath(containerParameterBundle, artifactNature)).append(
                Constants.PROTOBUF_GENERATION_DIRECTORY_NAME)
        }
    }

}
