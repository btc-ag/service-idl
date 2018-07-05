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

import com.btc.serviceidl.generator.DefaultGenerationSettings
import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.ServiceCommVersion
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import com.google.common.collect.ImmutableSet
import com.google.inject.Inject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class DefaultGenerationSettingsProviderTest
{
    @Inject extension ParseHelper<IDLSpecification>

    @Test
    def void testBasic()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        assertEquals(ImmutableSet.of(ArtifactNature.CPP, ArtifactNature.JAVA, ArtifactNature.DOTNET),
            defaultGenerationSettingsProvider.getSettings(TestData.basic.parse.eResource).getLanguages)
    }

    @Test(expected=IllegalArgumentException)
    def void testSetVersionUnknownVersionFails()
    {
        val defaultGenerationSettings = new DefaultGenerationSettings
        defaultGenerationSettings.setVersion(CppConstants.SERVICECOMM_VERSION_KIND, "foo")
    }

    @Test(expected=IllegalArgumentException)
    def void testSetVersionUnknownVersionKindFails()
    {
        val defaultGenerationSettings = new DefaultGenerationSettings
        defaultGenerationSettings.setVersion("foo", "bar")
    }

    @Test
    def void testSetVersionKnownVersion()
    {
        val defaultGenerationSettings = new DefaultGenerationSettings
        for (version : CppConstants.SERVICECOMM_VERSIONS)
            defaultGenerationSettings.setVersion(CppConstants.SERVICECOMM_VERSION_KIND, version)
    }

    @Test
    def void testConfigureVersions()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        defaultGenerationSettingsProvider.configureGenerationSettings(null,
            #{CppConstants.SERVICECOMM_VERSION_KIND -> ServiceCommVersion.V0_10.label}.entrySet, null, null)
        assertEquals(ServiceCommVersion.V0_10.label,
            defaultGenerationSettingsProvider.getSettings(TestData.basic.parse.eResource).getTargetVersion(
                CppConstants.SERVICECOMM_VERSION_KIND))
    }

    @Test(expected=IllegalArgumentException)
    def void testConfigureUnknownProjectSystemFails()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        defaultGenerationSettingsProvider.configureGenerationSettings("foo", null as String, null, null)
        defaultGenerationSettingsProvider.getSettings(TestData.basic.parse.eResource)
    }
}
