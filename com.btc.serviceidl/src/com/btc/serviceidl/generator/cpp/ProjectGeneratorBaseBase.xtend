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
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.google.common.collect.Sets
import java.util.Arrays
import java.util.Collection
import java.util.HashSet
import java.util.Map
import java.util.Optional
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PROTECTED_GETTER)
class ProjectGeneratorBaseBase
{
    val IFileSystemAccess fileSystemAccess
    val IQualifiedNameProvider qualifiedNameProvider
    val IScopeProvider scopeProvider
    val IDLSpecification idl
    val IProjectSetFactory projectSetFactory
    val extension IProjectSet vsSolution
    val IModuleStructureStrategy moduleStructureStrategy
    val ITargetVersionProvider targetVersionProvider
    val Map<AbstractTypeReference, Collection<AbstractTypeReference>> smartPointerMap

    val ParameterBundle paramBundle
    val ModuleDeclaration module

    // per-project global variables
    val cabLibs = new HashSet<ExternalDependency>
    val projectReferences = new HashSet<IProjectReference>
    val projectFileSet = new ProjectFileSet(Arrays.asList(OdbConstants.ODB_FILE_GROUP)) // TODO inject the file groups

    new(IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider, IScopeProvider scopeProvider,
        IDLSpecification idl, IProjectSetFactory projectSetFactory, IProjectSet vsSolution,
        IModuleStructureStrategy moduleStructureStrategy, ITargetVersionProvider targetVersionProvider,
        Map<AbstractTypeReference, Collection<AbstractTypeReference>> smartPointerMap, ProjectType type,
        ModuleDeclaration module)
    {
        this.fileSystemAccess = fileSystemAccess
        this.qualifiedNameProvider = qualifiedNameProvider
        this.scopeProvider = scopeProvider
        this.idl = idl
        this.projectSetFactory = projectSetFactory
        this.vsSolution = vsSolution
        this.moduleStructureStrategy = moduleStructureStrategy
        this.targetVersionProvider = targetVersionProvider
        this.smartPointerMap = smartPointerMap
        this.module = module

        this.paramBundle = new ParameterBundle.Builder().with(type).with(module.moduleStack).build
    }

    protected def createTypeResolver()
    {
        createTypeResolver(this.paramBundle)
    }

    private def createTypeResolver(ParameterBundle paramBundle)
    {
        new TypeResolver(qualifiedNameProvider, vsSolution, moduleStructureStrategy, projectReferences, cabLibs,
            smartPointerMap)
    }

    protected def createBasicCppGenerator()
    {
        createBasicCppGenerator(this.paramBundle)
    }

    protected def createBasicCppGenerator(ParameterBundle paramBundle)
    {
        new BasicCppGenerator(createTypeResolver(paramBundle), targetVersionProvider, paramBundle)
    }

    def Iterable<IProjectReference> getAdditionalProjectReferences()
    { return #[] }

    protected def void generateProjectFiles(ProjectType projectType, IPath projectPath, String projectName,
        ProjectFileSet projectFileSet)
    {
        // TODO maybe find a better place to handle these extra resolutions
        // proxy and dispatcher include a *.impl.h file from the Protobuf project
        // for type-conversion routines; therefore some hidden dependencies
        // exist, which are explicitly resolved here
        if (paramBundle.projectType == ProjectType.PROXY || paramBundle.projectType == ProjectType.DISPATCHER)
        {
            cabLibs.add(new ExternalDependency("BTC.CAB.Commons.FutureUtil"))
        }

        // TODO This should be done differently, the PROTOBUF project should have a resolved
        // dependency on libprotobuf, and should export this dependency to its dependents
        if (paramBundle.projectType == ProjectType.PROTOBUF || paramBundle.projectType == ProjectType.DISPATCHER ||
            paramBundle.projectType == ProjectType.PROXY || paramBundle.projectType == ProjectType.SERVER_RUNNER)
        {
            cabLibs.add(new ExternalDependency("libprotobuf"))
        }

        projectSetFactory.generateProjectFiles(fileSystemAccess, targetVersionProvider, paramBundle,
            cabLibs.unmodifiableView, vsSolution, Sets.union(projectReferences, additionalProjectReferences.toSet),
            projectFileSet.unmodifiableView, projectType, projectPath, projectName)
    }

    protected def generateExportHeader()
    {
        new ExportHeaderGenerator(paramBundle).generateExportHeader()
    }

    static def String generateHeader(BasicCppGenerator basicCppGenerator,
        IModuleStructureStrategy moduleStructureStrategy, String fileContent, Optional<String> exportHeader)
    {
        '''
            #pragma once
            
            «moduleStructureStrategy.encapsulationHeaders.key»
            «IF exportHeader.present»#include "«exportHeader.get»"«ENDIF»
            «basicCppGenerator.generateIncludes(true)»
            
            «basicCppGenerator.paramBundle.openNamespaces»
               «fileContent»
            «basicCppGenerator.paramBundle.closeNamespaces»
            «moduleStructureStrategy.encapsulationHeaders.value»
        '''
    }

    static def String generateSource(BasicCppGenerator basicCppGenerator, String fileContent, Optional<String> fileTail)
    {
        '''
            «basicCppGenerator.generateIncludes(false)»
            «basicCppGenerator.paramBundle.openNamespaces»
               «fileContent»
            «basicCppGenerator.paramBundle.closeNamespaces»
            «IF fileTail.present»«fileTail.get»«ENDIF»
        '''
    }

    protected def IPath getProjectPath()
    {
        moduleStructureStrategy.getProjectDir(paramBundle)
    }

}
