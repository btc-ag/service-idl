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
import com.btc.serviceidl.generator.cpp.prins.OdbConstants
import com.btc.serviceidl.generator.cpp.prins.VSProjectFileGenerator
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Arrays
import java.util.Collection
import java.util.HashSet
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.Path
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectFileGenerator
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSet
import com.btc.serviceidl.generator.cpp.prins.VSSolution

@Accessors(PROTECTED_GETTER)
class ProjectGeneratorBaseBase
{
    val Resource resource
    val IFileSystemAccess file_system_access
    val IQualifiedNameProvider qualified_name_provider
    val IScopeProvider scope_provider
    val IDLSpecification idl
    val extension IProjectSet vsSolution
    val IModuleStructureStrategy moduleStructureStrategy
    val Map<String, Set<IProjectReference>> protobuf_project_references
    val Map<EObject, Collection<EObject>> smart_pointer_map

    private var ParameterBundle param_bundle
    val ModuleDeclaration module

    // per-project global variables
    val cab_libs = new HashSet<String>
    val project_references = new HashSet<IProjectReference>
    val projectFileSet = new ProjectFileSet(Arrays.asList(OdbConstants.ODB_FILE_GROUP)) // TODO inject the file groups

    new(Resource resource, IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, IProjectSet vsSolution,
        IModuleStructureStrategy moduleStructureStrategy,
        Map<String, Set<IProjectReference>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ProjectType type, ModuleDeclaration module)
    {
        this.resource = resource
        this.file_system_access = file_system_access
        this.qualified_name_provider = qualified_name_provider
        this.scope_provider = scope_provider
        this.idl = idl
        this.vsSolution = vsSolution
        this.moduleStructureStrategy = moduleStructureStrategy
        this.protobuf_project_references = protobuf_project_references
        this.smart_pointer_map = smart_pointer_map
        this.module = module

        val param_bundle_builder = new ParameterBundle.Builder
        param_bundle_builder.reset(type)
        param_bundle_builder.reset(module.moduleStack)
        this.param_bundle = param_bundle_builder.build
    }

    def protected createTypeResolver()
    {
        createTypeResolver(this.param_bundle)
    }

    def protected createTypeResolver(ParameterBundle param_bundle)
    {
        new TypeResolver(qualified_name_provider, vsSolution, moduleStructureStrategy, project_references, cab_libs,
            smart_pointer_map)
    }

    def protected createBasicCppGenerator()
    {
        createBasicCppGenerator(this.param_bundle)
    }

    def protected createBasicCppGenerator(ParameterBundle param_bundle)
    {
        new BasicCppGenerator(createTypeResolver(param_bundle), param_bundle)
    }

    // TODO move this to com.btc.serviceidl.generator.cpp.prins resp. use a factory for the ProjectFileGenerator implementation
    def protected void generateVSProjectFiles(ProjectType project_type, IPath project_path, String project_name,
        ProjectFileSet projectFileSet)
    {
        if (vsSolution instanceof VSSolution)
        {
            val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES.cpp
            val source_path = projectPath.append("source")

            file_system_access.generateFile(source_path.append(dependency_file_name).toString, generateDependencies)
            projectFileSet.addToGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP, dependency_file_name)

            new VSProjectFileGenerator(file_system_access, param_bundle, vsSolution, protobuf_project_references,
                project_references, projectFileSet.unmodifiableView, project_type, project_path, project_name).
                generate()

        }
        else if (vsSolution instanceof CMakeProjectSet)
        {
            new CMakeProjectFileGenerator(file_system_access, param_bundle, vsSolution, protobuf_project_references,
                project_references, projectFileSet.unmodifiableView, project_type, project_path, project_name).
                generate()

        }
    }

    // TODO move this to com.btc.serviceidl.generator.cpp.prins
    def private generateDependencies()
    {
        new DependenciesGenerator(createTypeResolver, param_bundle).generate()
    }

    def protected generateExportHeader()
    {
        new ExportHeaderGenerator(param_bundle).generateExportHeader()
    }

    def static String generateHeader(BasicCppGenerator basicCppGenerator,
        IModuleStructureStrategy moduleStructureStrategy, String file_content, Optional<String> export_header)
    {
        '''
            #pragma once
            
            «moduleStructureStrategy.encapsulationHeaders.key»
            «IF export_header.present»#include "«export_header.get»"«ENDIF»
            «basicCppGenerator.generateIncludes(true)»
            
            «basicCppGenerator.paramBundle.openNamespaces»
               «file_content»
            «basicCppGenerator.paramBundle.closeNamespaces»
            «moduleStructureStrategy.encapsulationHeaders.value»
        '''
    }

    def static String generateSource(BasicCppGenerator basicCppGenerator, String file_content,
        Optional<String> file_tail)
    {
        '''
            «basicCppGenerator.generateIncludes(false)»
            «basicCppGenerator.paramBundle.openNamespaces»
               «file_content»
            «basicCppGenerator.paramBundle.closeNamespaces»
            «IF file_tail.present»«file_tail.get»«ENDIF»
        '''
    }

    def protected IPath getProjectPath()
    {
        // TODO at least the "modules" part is PRINS-specific and should be determined by PrinsModuleStructureStrategy  
        new Path(ArtifactNature.CPP.label).append("modules").append(
            GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.CPP, TransformType.FILE_SYSTEM))
    }

}
