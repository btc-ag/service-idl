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

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class LegacyProjectGenerator extends ProjectGeneratorBase
{
    def override String generateProjectSource(InterfaceDeclaration interface_declaration)
    {
        reinitializeFile
        val project_type = param_bundle.projectType.get

        val file_content = switch (project_type)
        {
            case SERVICE_API:
                generateCppServiceAPI(interface_declaration)
            case DISPATCHER:
                generateCppDispatcher(interface_declaration)
            case IMPL:
                generateCppImpl(interface_declaration)
            case PROXY:
                generateCppProxy(interface_declaration)
            case TEST:
                generateCppTest(interface_declaration)
            // TODO check that this is generated otherwise
//            case SERVER_RUNNER:
//                generateCppServerRunner(interface_declaration)
            default:
                /* nothing to do for other project types */
                throw new IllegalArgumentException("Inapplicable project type:" + project_type)
        }

        val file_tail = '''
            «IF project_type == ProjectType.PROXY || project_type == ProjectType.DISPATCHER || project_type == ProjectType.IMPL»
                «generateCppReflection(interface_declaration)»
            «ENDIF»
        '''

        generateSource(file_content.toString, if (file_tail.trim.empty) Optional.empty else Optional.of(file_tail))
    }

    def override String generateProjectHeader(String export_header, InterfaceDeclaration interface_declaration)
    {
        reinitializeFile

        val file_content = switch (param_bundle.projectType.get)
        {
            case SERVICE_API:
                generateInterface(interface_declaration)
            case DISPATCHER:
                generateHFileDispatcher(interface_declaration)
            case IMPL:
                generateInterface(interface_declaration)
            case PROXY:
                generateInterface(interface_declaration)
            default:
                /* nothing to do for other project types */
                throw new IllegalArgumentException("Inapplicable project type:" + param_bundle.projectType)
        }

        generateHeader(file_content.toString, Optional.of(export_header))
    }

    def private generateCppServiceAPI(InterfaceDeclaration interface_declaration)
    {
        new ServiceAPIGenerator(typeResolver, param_bundle, idl).generateImplFileBody(interface_declaration)
    }

    def private String generateCppProxy(InterfaceDeclaration interface_declaration)
    {
        new ProxyGenerator(typeResolver, param_bundle, idl).generateImplementationFileBody(interface_declaration).
            toString
    }

    def private generateCppTest(InterfaceDeclaration interface_declaration)
    {
        new TestGenerator(typeResolver, param_bundle, idl).generateCppTest(interface_declaration)
    }

    def private generateCppDispatcher(InterfaceDeclaration interface_declaration)
    {
        new DispatcherGenerator(typeResolver, param_bundle, idl).generateImplementationFileBody(interface_declaration)
    }

    def private generateHFileDispatcher(InterfaceDeclaration interface_declaration)
    {
        new DispatcherGenerator(typeResolver, param_bundle, idl).generateHeaderFileBody(interface_declaration)
    }

    def private generateCppReflection(InterfaceDeclaration interface_declaration)
    {
        new ReflectionGenerator(typeResolver, param_bundle, idl).generateImplFileBody(interface_declaration)
    }

}
