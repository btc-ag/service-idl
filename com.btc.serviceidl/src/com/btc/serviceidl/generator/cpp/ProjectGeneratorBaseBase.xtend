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
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
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
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PROTECTED_GETTER)
class ProjectGeneratorBaseBase
{
    private val Resource resource
    private val IFileSystemAccess file_system_access
    private val IQualifiedNameProvider qualified_name_provider
    private val IScopeProvider scope_provider
    private val IDLSpecification idl
    private val extension VSSolution vsSolution
    private val Map<String, HashMap<String, String>> protobuf_project_references
    private val Map<EObject, Collection<EObject>> smart_pointer_map

    // TODO change this to ParameterBundle
    val ParameterBundle.Builder param_bundle
    val ModuleDeclaration module

    // per-project global variables
    private val cab_libs = new HashSet<String>
    private val cpp_files = new HashSet<String>
    private val header_files = new HashSet<String>
    private val dependency_files = new HashSet<String>
    private val protobuf_files = new HashSet<String>
    private val odb_files = new HashSet<String>
    private val project_references = new HashMap<String, String>

    new(Resource resource, IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, VSSolution vsSolution,
        Map<String, HashMap<String, String>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ProjectType type, ModuleDeclaration module)
    {
        this.resource = resource
        this.file_system_access = file_system_access
        this.qualified_name_provider = qualified_name_provider
        this.scope_provider = scope_provider
        this.idl = idl
        this.vsSolution = vsSolution
        this.protobuf_project_references = protobuf_project_references
        this.smart_pointer_map = smart_pointer_map
        this.module = module

        this.param_bundle = new ParameterBundle.Builder
        this.param_bundle.reset(ArtifactNature.CPP)
        this.param_bundle.reset(type)
        this.param_bundle.reset(module.moduleStack)
    }

    // per-file variables
    protected var TypeResolver typeResolver = null
    protected var BasicCppGenerator basicCppGenerator = null

    def protected void reinitializeFile()
    {
        typeResolver = new TypeResolver(qualified_name_provider, param_bundle, vsSolution, project_references, cab_libs,
            smart_pointer_map)
        basicCppGenerator = new BasicCppGenerator(typeResolver, param_bundle, idl)
    }

    def protected void generateVSProjectFiles(ProjectType project_type, String project_path, String project_name)
    {
        // root folder of the project
        file_system_access.generateFile(
            project_path + Constants.SEPARATOR_FILE + project_name.vcxproj,
            generateVcxproj(project_name)
        )
        file_system_access.generateFile(
            project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.filters,
            generateVcxprojFilters()
        )
        // *.vcxproj.user file for executable projects
        if (project_type == ProjectType.TEST || project_type == ProjectType.SERVER_RUNNER)
        {
            file_system_access.generateFile(
                project_path + Constants.SEPARATOR_FILE + project_name.vcxproj.user,
                generateVcxprojUser(project_type)
            )
        }
    }

    def private generateVcxprojUser(ProjectType project_type)
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            protobuf_project_references,
            project_references,
            cpp_files,
            header_files,
            dependency_files,
            protobuf_files,
            odb_files
        ).generateVcxprojUser(project_type)
    }

    def private generateVcxprojFilters()
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            protobuf_project_references,
            project_references,
            cpp_files,
            header_files,
            dependency_files,
            protobuf_files,
            odb_files
        ).generateVcxprojFilters()
    }

    def private String generateVcxproj(String project_name)
    {
        new VcxProjGenerator(
            param_bundle,
            vsSolution,
            protobuf_project_references,
            project_references,
            cpp_files,
            header_files,
            dependency_files,
            protobuf_files,
            odb_files
        ).generate(project_name).toString
    }

    def protected generateDependencies()
    {
        new DependenciesGenerator(typeResolver, param_bundle, idl).generate()
    }

    def protected generateExportHeader()
    {
        new ExportHeaderGenerator(param_bundle.build).generateExportHeader()
    }

    def protected String generateHeader(String file_content, Optional<String> export_header)
    {
        '''
            #pragma once
            #include "modules/Commons/include/BeginPrinsModulesInclude.h"
            
            «IF export_header.present»#include "«export_header.get»"«ENDIF»
            «basicCppGenerator.generateIncludes(true)»
            
            «param_bundle.build.openNamespaces»
               «file_content»
            «param_bundle.build.closeNamespaces»
            #include "modules/Commons/include/EndPrinsModulesInclude.h"
        '''
    }

    def protected String generateSource(String file_content, Optional<String> file_tail)
    {
        '''
            «basicCppGenerator.generateIncludes(false)»
            «param_bundle.build.openNamespaces»
               «file_content»
            «param_bundle.build.closeNamespaces»
            «IF file_tail.present»«file_tail.get»«ENDIF»
        '''
    }

    def protected getProjectPath()
    {
        param_bundle.artifactNature.label + Constants.SEPARATOR_FILE +
            GeneratorUtil.transform(param_bundle.build, TransformType.FILE_SYSTEM) + Constants.SEPARATOR_FILE
    }
}
