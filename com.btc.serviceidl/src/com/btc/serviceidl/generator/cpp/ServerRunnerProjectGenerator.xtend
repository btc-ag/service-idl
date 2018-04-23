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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.HashMap
import java.util.Map
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
        IScopeProvider scope_provider, IDLSpecification idl, VSSolution vsSolution,
        Map<String, HashMap<String, String>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ModuleDeclaration module)
    {
        super(resource, file_system_access, qualified_name_provider, scope_provider, idl, vsSolution,
            protobuf_project_references, smart_pointer_map, ProjectType.SERVER_RUNNER, module)
    }

    def generate()
    {
        param_bundle.reset(com.btc.serviceidl.util.Util.getModuleStack(module))

        // paths
        val include_path = projectPath + "include" + Constants.SEPARATOR_FILE
        val source_path = projectPath + "source" + Constants.SEPARATOR_FILE
        val etc_path = projectPath + "etc" + Constants.SEPARATOR_FILE

        // sub-folder "./include"
        val export_header_file_name = (GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build) +
            "_export".h).toLowerCase
        file_system_access.generateFile(include_path + export_header_file_name, generateExportHeader())
        header_files.add(export_header_file_name)

        // sub-folder "./source"
        for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            val cpp_file = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name).cpp
            file_system_access.generateFile(source_path + cpp_file, generateCppServerRunner(interface_declaration))
            cpp_files.add(cpp_file)
        }

        val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES.cpp
        file_system_access.generateFile(source_path + dependency_file_name, generateDependencies)
        dependency_files.add(dependency_file_name)

        // individual project files for every interface
        for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            cpp_files.clear
            val project_name = GeneratorUtil.transform(param_bundle.with(TransformType.PACKAGE).build) +
                TransformType.PACKAGE.separator + interface_declaration.name
            val cpp_file = GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name).cpp
            cpp_files.add(cpp_file)
            generateVSProjectFiles(ProjectType.SERVER_RUNNER, projectPath, project_name)
        }

        // sub-folder "./etc"
        val ioc_file_name = "ServerFactory".xml
        file_system_access.generateFile(etc_path + ioc_file_name, generateIoCServerRunner())
    }

    def private String generateCppServerRunner(InterfaceDeclaration interface_declaration)
    {
        reinitializeFile

        val file_content = new ServerRunnerGenerator(typeResolver, param_bundle, idl).generateImplFileBody(
            interface_declaration)

        '''
            «basicCppGenerator.generateIncludes(false)»
            «file_content»
        '''
    }

    def private generateIoCServerRunner()
    {
        new ServerRunnerGenerator(typeResolver, param_bundle, idl).generateIoC()
    }

}
