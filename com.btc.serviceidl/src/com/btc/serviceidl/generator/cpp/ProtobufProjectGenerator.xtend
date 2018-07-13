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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.Map
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(PROTECTED_GETTER)
class ProtobufProjectGenerator extends ProjectGeneratorBaseBase
{
    val Iterable<IProjectReference> protobufProjectReferences

    new(IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IScopeProvider scopeProvider, IDLSpecification idl, IProjectSetFactory projectSetFactory,
        IProjectSet vsSolution, IModuleStructureStrategy moduleStructureStrategy,
        ITargetVersionProvider targetVersionProvider, Iterable<IProjectReference> protobufProjectReferences,
        Map<AbstractTypeReference, Collection<AbstractTypeReference>> smartPointerMap, ModuleDeclaration module)
    {
        super(fileSystemAccess, qualifiedNameProvider, scopeProvider, idl, projectSetFactory, vsSolution,
            moduleStructureStrategy, targetVersionProvider, smartPointerMap, ProjectType.PROTOBUF, module)

        this.protobufProjectReferences = protobufProjectReferences
    }

    def generate()
    {
        // paths
        val includePath = projectPath.append("include")

        // file names
        val exportHeaderFileName = (GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER) + "_export".h).toLowerCase

        // sub-folder "./include"
        fileSystemAccess.generateFile(includePath.append(exportHeaderFileName).toString, ArtifactNature.CPP.label,
            generateExportHeader())
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, exportHeaderFileName)

        if (module.containsTypes)
        {
            val codecHeaderName = GeneratorUtil.getCodecName(module).h
            fileSystemAccess.generateFile(includePath.append(codecHeaderName).toString, ArtifactNature.CPP.label,
                generateHCodec(module))
            projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, codecHeaderName)
        }
        for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            val codecHeaderName = GeneratorUtil.getCodecName(interfaceDeclaration).h
            fileSystemAccess.generateFile(includePath.append(codecHeaderName).toString, ArtifactNature.CPP.label,
                generateHCodec(interfaceDeclaration))
            projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, codecHeaderName)
        }

        // sub-folder "./gen"
        if (module.containsTypes)
        {
            val fileName = Constants.FILE_NAME_TYPES
            projectFileSet.addToGroup(ProjectFileSet.PROTOBUF_FILE_GROUP, fileName)
        }
        for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            val fileName = interfaceDeclaration.name
            projectFileSet.addToGroup(ProjectFileSet.PROTOBUF_FILE_GROUP, fileName)
        }

        generateProjectFiles(ProjectType.PROTOBUF, projectPath, vsSolution.getVcxprojName(paramBundle), projectFileSet)
    }

    private def String generateHCodec(AbstractContainerDeclaration owner)
    {
        val basicCppGenerator = createBasicCppGenerator
        val fileContent = new CodecGenerator(basicCppGenerator.typeResolver, targetVersionProvider, paramBundle).
            generateHeaderFileBody(owner)
        generateHeader(basicCppGenerator, moduleStructureStrategy, fileContent.toString, Optional.empty)
    }

    override Iterable<IProjectReference> getAdditionalProjectReferences()
    { return protobufProjectReferences ?: #[] }
}
