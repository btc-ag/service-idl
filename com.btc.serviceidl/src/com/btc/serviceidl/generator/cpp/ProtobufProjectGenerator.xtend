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
import java.util.HashMap
import java.util.Map
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.util.Extensions.*
import java.util.Collection

@Accessors(PROTECTED_GETTER)
class ProtobufProjectGenerator extends ProjectGeneratorBaseBase
{
    new(Resource resource, IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, VSSolution vsSolution,
        Map<String, HashMap<String, String>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ModuleDeclaration module)
    {
        super(resource, file_system_access, qualified_name_provider, scope_provider, idl, vsSolution,
            protobuf_project_references, smart_pointer_map, ProjectType.PROTOBUF, module)
    }

    def generate()
    {
        val project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE +
            GeneratorUtil.transform(param_bundle.with(TransformType.FILE_SYSTEM).build) + Constants.SEPARATOR_FILE

        // paths
        val include_path = project_path + "include" + Constants.SEPARATOR_FILE
        val source_path = project_path + "source" + Constants.SEPARATOR_FILE

        // file names
        var export_header_file_name = (GeneratorUtil.transform(param_bundle.with(TransformType.EXPORT_HEADER).build) +
            "_export".h).toLowerCase
        val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES + ".cpp"

        // sub-folder "./include"
        file_system_access.generateFile(include_path + export_header_file_name, generateExportHeader())
        header_files.add(export_header_file_name)

        if (module.containsTypes)
        {
            val codec_header_name = GeneratorUtil.getCodecName(module).h
            file_system_access.generateFile(include_path + codec_header_name, generateHCodec(module))
            header_files.add(codec_header_name)
        }
        for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            val codec_header_name = GeneratorUtil.getCodecName(interface_declaration).h
            file_system_access.generateFile(include_path + codec_header_name, generateHCodec(interface_declaration))
            header_files.add(codec_header_name)
        }

        // sub-folder "./source"
        file_system_access.generateFile(source_path + dependency_file_name, generateDependencies)
        dependency_files.add(dependency_file_name)

        // sub-folder "./gen"
        if (module.containsTypes)
        {
            val file_name = Constants.FILE_NAME_TYPES
            protobuf_files.add(file_name)
        }
        for (interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            val file_name = interface_declaration.name
            protobuf_files.add(file_name)
        }

        generateVSProjectFiles(ProjectType.PROTOBUF, project_path,
            vsSolution.getVcxprojName(param_bundle, Optional.empty))
    }

    def private String generateHCodec(EObject owner)
    {
        reinitializeFile
        val file_content = new CodecGenerator(typeResolver, param_bundle, idl).generateHeaderFileBody(owner)
        generateHeader(file_content.toString, Optional.empty)
    }

}
