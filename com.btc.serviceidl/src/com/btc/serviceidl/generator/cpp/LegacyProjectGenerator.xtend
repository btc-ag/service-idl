/*********************************************************************
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import java.util.Collection
import java.util.Map
import java.util.Optional
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

class LegacyProjectGenerator extends ProjectGeneratorBase
{
    new(IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IScopeProvider scopeProvider, IDLSpecification idl, IProjectSetFactory projectSetFactory,
        IProjectSet vsSolution, IModuleStructureStrategy moduleStructureStrategy,
        ITargetVersionProvider targetVersionProvider, Map<AbstractTypeReference, Collection<AbstractTypeReference>> smartPointerMap,
        ProjectType type, ModuleDeclaration module)
    {
        super(fileSystemAccess, qualifiedNameProvider, scopeProvider, idl, projectSetFactory, vsSolution,
            moduleStructureStrategy, targetVersionProvider, smartPointerMap, type, module,            
            new SourceGenerationStrategy)
    }

    private static class SourceGenerationStrategy implements ISourceGenerationStrategy
    {

        override String generateProjectSource(BasicCppGenerator basicCppGenerator,
            InterfaceDeclaration interfaceDeclaration)
        {
            val projectType = basicCppGenerator.paramBundle.projectType

            val fileContent = switch (projectType)
            {
                case SERVICE_API:
                    generateCppServiceAPI(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                case DISPATCHER:
                    generateCppDispatcher(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                case IMPL:
                    generateCppImpl(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                case PROXY:
                    generateCppProxy(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                case TEST:
                    generateCppTest(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                // TODO check that this is generated otherwise
//            case SERVER_RUNNER:
//                generateCppServerRunner(interfaceDeclaration)
                default:
                    /* nothing to do for other project types */
                    throw new IllegalArgumentException("Inapplicable project type:" + projectType)
            }

            val fileTail = '''
                «IF projectType == ProjectType.PROXY || projectType == ProjectType.DISPATCHER || projectType == ProjectType.IMPL»
                    «generateCppReflection(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider, basicCppGenerator.paramBundle, interfaceDeclaration)»
                «ENDIF»
            '''

            generateSource(basicCppGenerator, fileContent.toString,
                if (fileTail.trim.empty) Optional.empty else Optional.of(fileTail))
        }

        override String generateProjectHeader(BasicCppGenerator basicCppGenerator,
            IModuleStructureStrategy moduleStructureStrategy, InterfaceDeclaration interfaceDeclaration,
            String exportHeader)
        {
            val fileContent = switch (basicCppGenerator.paramBundle.projectType)
            {
                case SERVICE_API:
                    generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                case DISPATCHER:
                    generateHFileDispatcher(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                case IMPL:
                    generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                case PROXY:
                    generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider,
                        basicCppGenerator.paramBundle, interfaceDeclaration)
                default:
                    /* nothing to do for other project types */
                    throw new IllegalArgumentException("Inapplicable project type:" +
                        basicCppGenerator.paramBundle.projectType)
            }

            generateHeader(basicCppGenerator, moduleStructureStrategy, fileContent.toString,
                Optional.of(exportHeader))
        }

        private def generateCppServiceAPI(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
            ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
        {
            new ServiceAPIGenerator(typeResolver, targetVersionProvider, paramBundle).generateImplFileBody(
                interfaceDeclaration)
        }

        private def generateCppProxy(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
            ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
        {
            new ProxyGenerator(typeResolver, targetVersionProvider, paramBundle).
                generateImplementationFileBody(interfaceDeclaration)
        }

        private def generateCppTest(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
            ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
        {
            new TestGenerator(typeResolver, targetVersionProvider, paramBundle).generateCppTest(interfaceDeclaration)
        }

        private def generateCppDispatcher(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
            ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
        {
            new DispatcherGenerator(typeResolver, targetVersionProvider, paramBundle).
                generateImplementationFileBody(interfaceDeclaration)
        }

        private def generateHFileDispatcher(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
            ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
        {
            new DispatcherGenerator(typeResolver, targetVersionProvider, paramBundle).
                generateHeaderFileBody(interfaceDeclaration)
        }

        private def generateCppReflection(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
            ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
        {
            new ReflectionGenerator(typeResolver, targetVersionProvider, paramBundle).generateImplFileBody(
                interfaceDeclaration)
        }
    }

}
