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
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import java.util.Collection
import java.util.Map
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors(PROTECTED_GETTER)
class ServerRunnerProjectGenerator extends ProjectGeneratorBaseBase
{
    new(IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider, IScopeProvider scopeProvider,
        IDLSpecification idl, IProjectSetFactory projectSetFactory, IProjectSet vsSolution,
        IModuleStructureStrategy moduleStructureStrategy, ITargetVersionProvider targetVersionProvider,
        Map<AbstractTypeReference, Collection<AbstractTypeReference>> smartPointerMap, ModuleDeclaration module)
    {
        super(fileSystemAccess, qualifiedNameProvider, scopeProvider, idl, projectSetFactory, vsSolution,
            moduleStructureStrategy, targetVersionProvider, smartPointerMap, ProjectType.SERVER_RUNNER, module)
    }

    def generate()
    {
        // paths
        val includePath = projectPath.append("include")
        val sourcePath = projectPath.append(moduleStructureStrategy.sourceFileDir)
        val etcPath = projectPath.append("etc")

        // include sub-folder
        val exportHeaderFileName = (GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER) + "_export".h).toLowerCase
        fileSystemAccess.generateFile(includePath.append(exportHeaderFileName).toString, ArtifactNature.CPP.label,
            generateExportHeader())
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, exportHeaderFileName)

        // source sub-folder
        val cppFile = GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType, "").cpp
        fileSystemAccess.generateFile(sourcePath.append(cppFile).toString, ArtifactNature.CPP.label,
            generateCppServerRunner(module.moduleComponents.filter(InterfaceDeclaration)))
        projectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, cppFile)

        val projectName = GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.PACKAGE)

        generateProjectFiles(ProjectType.SERVER_RUNNER, projectPath, projectName, projectFileSet)

        // sub-folder "./etc"
        val iocFileName = "ServerFactory".xml
        fileSystemAccess.generateFile(etcPath.append(iocFileName).toString, ArtifactNature.CPP.label,
            generateIoCServerRunner())
    }

    private def String generateCppServerRunner(Iterable<InterfaceDeclaration> interfaceDeclaration)
    {
        val basicCppGenerator = createBasicCppGenerator

        val fileContent = new ServerRunnerGenerator(basicCppGenerator.typeResolver, targetVersionProvider, paramBundle).
            generateImplFileBody(interfaceDeclaration)

        '''
            «basicCppGenerator.generateIncludes(false)»
            «fileContent»
        '''
    }

    private def generateIoCServerRunner()
    {
        // TODO for generating the IoC file, none of the arguments are required
        new ServerRunnerGenerator(createTypeResolver, targetVersionProvider, paramBundle).generateIoC()
    }

}
