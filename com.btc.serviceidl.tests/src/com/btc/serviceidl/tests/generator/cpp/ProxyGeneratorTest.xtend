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
package com.btc.serviceidl.tests.generator.cpp

import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider
import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider.OptionalGenerationSettings
import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.Main
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.ProxyGenerator
import com.btc.serviceidl.generator.cpp.ServiceCommVersion
import com.btc.serviceidl.generator.cpp.TypeResolver
import com.btc.serviceidl.generator.cpp.cab.CABModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSet
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.generator.AbstractGeneratorTest
import com.btc.serviceidl.tests.testdata.TestData
import javax.inject.Inject
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class ProxyGeneratorTest extends AbstractGeneratorTest
{
    @Inject extension ParseHelper<IDLSpecification>

    private def testWithSettings(OptionalGenerationSettings additionalSettings)
    {
        val qualifiedNameProvider = new DefaultDeclarativeQualifiedNameProvider
        val projectSet = new CMakeProjectSet
        val moduleStructureStrategy = new CABModuleStructureStrategy
        val generationSettings = new DefaultGenerationSettingsProvider().getSettings(#[additionalSettings])
        val projectReferences = newArrayList
        val cabLibs = newArrayList
        val smartPointerMap = newHashMap
        val input = TestData.basic.parse
        val mainModule = input.effectiveMainModule
        val paramBundle = new ParameterBundle(mainModule.moduleStack, ProjectType.PROXY)
        val proxyGenerator = new ProxyGenerator(
            new TypeResolver(qualifiedNameProvider, projectSet, moduleStructureStrategy, generationSettings,
                projectReferences, cabLibs, smartPointerMap), generationSettings, paramBundle)

        val contents = proxyGenerator.generateImplementationFileBody(
            mainModule.moduleComponents.filter(InterfaceDeclaration).head)

    // TODO currently this is only a smoke test
    }

    @Test
    def void testWithTimeoutOverride()
    {
        val additionalSettings = new OptionalGenerationSettings()
        additionalSettings.generatorOptions = #{Main.OPTION_GENERATOR_OPTION_CPP_PROXY_TIMEOUT_SECONDS -> "42"}.entrySet

        testWithSettings(additionalSettings)
    }

    @Test
    def void testWithTimeoutOverride_V0_10()
    {
        val additionalSettings = new OptionalGenerationSettings()
        additionalSettings.generatorOptions = #{Main.OPTION_GENERATOR_OPTION_CPP_PROXY_TIMEOUT_SECONDS -> "42"}.entrySet
        additionalSettings.versions = #{CppConstants.SERVICECOMM_VERSION_KIND -> ServiceCommVersion.V0_10.label}.
            entrySet

        testWithSettings(additionalSettings)
    }
}
