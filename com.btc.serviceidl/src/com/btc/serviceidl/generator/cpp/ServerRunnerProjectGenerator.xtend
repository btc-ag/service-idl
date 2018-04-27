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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.prins.OdbConstants
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Arrays
import java.util.Collection
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors(PROTECTED_GETTER)
class ServerRunnerProjectGenerator extends ProjectGeneratorBaseBase
{
    new(Resource resource, IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, IProjectSet vsSolution,
        Map<String, Set<IProjectReference>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ModuleDeclaration module)
    {
        super(resource, file_system_access, qualified_name_provider, scope_provider, idl, vsSolution,
            protobuf_project_references, smart_pointer_map, ProjectType.SERVER_RUNNER, module)
    }

    def generate()
    {
        // paths
        val include_path = projectPath.append("include")
        val source_path = projectPath.append("source")
        val etc_path = projectPath.append("etc")

        // sub-folder "./include"
        val export_header_file_name = (GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER) + "_export".h).toLowerCase
        file_system_access.generateFile(include_path.append(export_header_file_name).toString, generateExportHeader())
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, export_header_file_name)

        // sub-folder "./source"
        for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            val cpp_file = GeneratorUtil.getClassName(ArtifactNature.CPP, param_bundle.projectType,
                interface_declaration.name).cpp
            file_system_access.generateFile(source_path.append(cpp_file).toString,
                generateCppServerRunner(interface_declaration))
            projectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, cpp_file)
        }

        val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES.cpp
        file_system_access.generateFile(source_path.append(dependency_file_name).toString, generateDependencies)
        projectFileSet.addToGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP, dependency_file_name)

        // individual project files for every interface
        for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            // TODO remove reference to OdbConstants here, it is PRINS-specific
            val localProjectFileSet = new ProjectFileSet(Arrays.asList(OdbConstants.ODB_FILE_GROUP))
            val project_name = GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.CPP,
                TransformType.PACKAGE) + TransformType.PACKAGE.separator + interface_declaration.name
            val cpp_file = GeneratorUtil.getClassName(ArtifactNature.CPP, param_bundle.projectType,
                interface_declaration.name).cpp
            localProjectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, cpp_file)

            // TODO this is wrong somehow... all files must be generated separately for each interface if they are separate projects
            projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP).forEach [
                localProjectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, it)
            ]
            projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP).forEach [
                localProjectFileSet.addToGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP, it)
            ]

            generateVSProjectFiles(ProjectType.SERVER_RUNNER, projectPath, project_name, localProjectFileSet)
        }

        // sub-folder "./etc"
        val ioc_file_name = "ServerFactory".xml
        file_system_access.generateFile(etc_path.append(ioc_file_name).toString, generateIoCServerRunner())
    }

    def private String generateCppServerRunner(InterfaceDeclaration interface_declaration)
    {
        val basicCppGenerator = createBasicCppGenerator

        val file_content = new ServerRunnerGenerator(basicCppGenerator.typeResolver, param_bundle).generateImplFileBody(
            interface_declaration)

        '''
            «basicCppGenerator.generateIncludes(false)»
            «file_content»
        '''
    }

    def private generateIoCServerRunner()
    {
        // TODO for generating the IoC file, none of the arguments are required
        new ServerRunnerGenerator(createTypeResolver, param_bundle).generateIoC()
    }

}
