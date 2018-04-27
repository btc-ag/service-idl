package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.prins.VSProjectFileGenerator
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.HashSet
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

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
    private val extension IProjectSet vsSolution
    private val Map<String, Set<IProjectReference>> protobuf_project_references
    private val Map<EObject, Collection<EObject>> smart_pointer_map

    private var ParameterBundle param_bundle
    private val ModuleDeclaration module

    // per-project global variables
    private val cab_libs = new HashSet<String>
    private val cpp_files = new HashSet<String>
    private val header_files = new HashSet<String>
    private val dependency_files = new HashSet<String>
    private val protobuf_files = new HashSet<String>
    private val odb_files = new HashSet<String>
    private val project_references = new HashSet<IProjectReference>

    new(Resource resource, IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, IProjectSet vsSolution,
        Map<String, Set<IProjectReference>> protobuf_project_references,
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
        new TypeResolver(qualified_name_provider, vsSolution, project_references, cab_libs, smart_pointer_map)
    }

    def protected createBasicCppGenerator()
    {
        createBasicCppGenerator(this.param_bundle)
    }

    def protected createBasicCppGenerator(ParameterBundle param_bundle)
    {
        new BasicCppGenerator(createTypeResolver(param_bundle), param_bundle, idl)
    }

    def protected void generateVSProjectFiles(ProjectType project_type, String project_path, String project_name)
    {
        new VSProjectFileGenerator(file_system_access, param_bundle, vsSolution, protobuf_project_references,
            project_references, cpp_files, header_files, dependency_files, protobuf_files, odb_files, project_type,
            project_path, project_name).generate()
    }

    def protected generateDependencies()
    {
        new DependenciesGenerator(createTypeResolver, param_bundle).generate()
    }

    def protected generateExportHeader()
    {
        new ExportHeaderGenerator(param_bundle).generateExportHeader()
    }

    def static String generateHeader(BasicCppGenerator basicCppGenerator, String file_content,
        Optional<String> export_header)
    {
        '''
            #pragma once
            #include "modules/Commons/include/BeginPrinsModulesInclude.h"
            
            «IF export_header.present»#include "«export_header.get»"«ENDIF»
            «basicCppGenerator.generateIncludes(true)»
            
            «basicCppGenerator.paramBundle.openNamespaces»
               «file_content»
            «basicCppGenerator.paramBundle.closeNamespaces»
            #include "modules/Commons/include/EndPrinsModulesInclude.h"
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

    def protected getProjectPath()
    {
        ArtifactNature.CPP.label + Constants.SEPARATOR_FILE +
            GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.CPP, TransformType.FILE_SYSTEM) +
            Constants.SEPARATOR_FILE
    }

}
