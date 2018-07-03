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
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.prins.OdbConstants
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import java.util.Arrays
import java.util.Collection
import java.util.HashSet
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PROTECTED_GETTER)
class ProjectGeneratorBaseBase
{
    val IFileSystemAccess file_system_access
    val IQualifiedNameProvider qualified_name_provider
    val IScopeProvider scope_provider
    val IDLSpecification idl
    val IProjectSetFactory projectSetFactory
    val extension IProjectSet vsSolution
    val IModuleStructureStrategy moduleStructureStrategy
    val ITargetVersionProvider targetVersionProvider
    val Map<String, Set<IProjectReference>> protobuf_project_references
    val Map<EObject, Collection<EObject>> smart_pointer_map

    var ParameterBundle param_bundle
    val ModuleDeclaration module

    // per-project global variables
    val cab_libs = new HashSet<String>
    val project_references = new HashSet<IProjectReference>
    val projectFileSet = new ProjectFileSet(Arrays.asList(OdbConstants.ODB_FILE_GROUP)) // TODO inject the file groups

    new(IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, IProjectSetFactory projectSetFactory,
        IProjectSet vsSolution, IModuleStructureStrategy moduleStructureStrategy,
        ITargetVersionProvider targetVersionProvider, Map<String, Set<IProjectReference>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ProjectType type, ModuleDeclaration module)
    {
        this.file_system_access = file_system_access
        this.qualified_name_provider = qualified_name_provider
        this.scope_provider = scope_provider
        this.idl = idl
        this.projectSetFactory = projectSetFactory
        this.vsSolution = vsSolution
        this.moduleStructureStrategy = moduleStructureStrategy
        this.targetVersionProvider = targetVersionProvider
        this.protobuf_project_references = protobuf_project_references
        this.smart_pointer_map = smart_pointer_map
        this.module = module

        this.param_bundle = new ParameterBundle.Builder().with(type).with(module.moduleStack).build
    }

    protected def createTypeResolver()
    {
        createTypeResolver(this.param_bundle)
    }

    private def createTypeResolver(ParameterBundle param_bundle)
    {
        new TypeResolver(qualified_name_provider, vsSolution, moduleStructureStrategy, project_references, cab_libs,
            smart_pointer_map)
    }

    protected def createBasicCppGenerator()
    {
        createBasicCppGenerator(this.param_bundle)
    }

    protected def createBasicCppGenerator(ParameterBundle param_bundle)
    {
        new BasicCppGenerator(createTypeResolver(param_bundle), targetVersionProvider, param_bundle)
    }

    protected def void generateProjectFiles(ProjectType project_type, IPath project_path, String project_name,
        ProjectFileSet projectFileSet)
    {
        projectSetFactory.generateProjectFiles(file_system_access, param_bundle, vsSolution,
            protobuf_project_references, project_references, projectFileSet.unmodifiableView, project_type,
            project_path, project_name, [createTypeResolver])
    }

    protected def generateExportHeader()
    {
        new ExportHeaderGenerator(param_bundle).generateExportHeader()
    }

    static def String generateHeader(BasicCppGenerator basicCppGenerator,
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

    static def String generateSource(BasicCppGenerator basicCppGenerator, String file_content,
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

    protected def IPath getProjectPath()
    {
        moduleStructureStrategy.getProjectDir(param_bundle)
    }

}
