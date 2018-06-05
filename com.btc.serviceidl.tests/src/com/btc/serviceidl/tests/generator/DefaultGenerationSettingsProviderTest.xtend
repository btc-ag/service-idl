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
package com.btc.serviceidl.tests.generator

import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import com.google.inject.Inject
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.*
import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider
import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.google.common.collect.ImmutableSet
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.Main
import java.util.HashMap

class DefaultGenerationSettingsProviderTest
{
    @Test
    def void testBasic()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        assertEquals(ImmutableSet.of(ArtifactNature.CPP, ArtifactNature.JAVA, ArtifactNature.DOTNET),
            defaultGenerationSettingsProvider.getLanguages)
    }

    @Test(expected=IllegalArgumentException)
    def void testSetVersionUnknownVersionFails()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        defaultGenerationSettingsProvider.setVersion(CppConstants.SERVICECOMM_VERSION_KIND, "foo")
    }

    @Test(expected=IllegalArgumentException)
    def void testSetVersionUnknownVersionKindFails()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        defaultGenerationSettingsProvider.setVersion("foo", "bar")
    }

    @Test
    def void testSetVersionKnownVersion()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        for (version : CppConstants.SERVICECOMM_VERSIONS)
            defaultGenerationSettingsProvider.setVersion(CppConstants.SERVICECOMM_VERSION_KIND, version)
    }

    @Test
    def void testConfigureVersions()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        Main.configureGenerationSettings(defaultGenerationSettingsProvider,
            Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_DEFAULT, #{CppConstants.SERVICECOMM_VERSION_KIND -> "0.10"}.entrySet)
        assertEquals("0.10", defaultGenerationSettingsProvider.getTargetVersion(CppConstants.SERVICECOMM_VERSION_KIND))
    }

    @Test(expected=IllegalArgumentException)
    def void testConfigureUnknownProjectSetFails()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        Main.configureGenerationSettings(defaultGenerationSettingsProvider, "foo",
            new HashMap<String, String>().entrySet)
    }
}
