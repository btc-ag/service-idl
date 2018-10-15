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
import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider.OptionalGenerationSettings
import com.btc.serviceidl.generator.Main
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.PackageInfo
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.ServiceCommVersion
import com.btc.serviceidl.generator.cpp.prins.PrinsModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.prins.VSSolutionFactory
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import com.google.common.collect.ImmutableSet
import com.google.inject.Inject
import java.io.InputStream
import java.util.Map
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.impl.ExtensibleURIConverterImpl
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.util.StringInputStream
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
            #{CppConstants.SERVICECOMM_VERSION_KIND -> ServiceCommVersion.V0_10.label}.entrySet, null, null, null, null)
        assertEquals(ServiceCommVersion.V0_10.label,
            defaultGenerationSettingsProvider.getSettings(TestData.basic.parse.eResource).getTargetVersion(
                CppConstants.SERVICECOMM_VERSION_KIND))
    }

    @Test
    def testImportDependencies()
    {
        val expected = #[new PackageInfo(#{ArtifactNature.CPP -> "foo"}, "0.0.1"), new PackageInfo(#{ArtifactNature.CPP -> "bar"}, "0.5.0")]
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        defaultGenerationSettingsProvider.configureGenerationSettings(null, null as String, null, null, null, expected)
        val result = defaultGenerationSettingsProvider.getSettings(TestData.basic.parse.eResource).dependencies
        assertNotNull(result)
        assertFalse(result.empty)
        assertEquals(2, result.size)
        assertEquals(expected.toList, result.toList)
    }

    @Test(expected=IllegalArgumentException)
    def void testConfigureUnknownProjectSystemFails()
    {
        val defaultGenerationSettingsProvider = new DefaultGenerationSettingsProvider
        defaultGenerationSettingsProvider.configureGenerationSettings("foo", null as String, null, null, null, null)
        defaultGenerationSettingsProvider.getSettings(TestData.basic.parse.eResource)
    }

    @Test
    def void testFindConfigurationFileGeneric()
    {
        val fileSystemAccess = new InMemoryFileSystemAccess
        fileSystemAccess.generateFile("/foo.idl", "")
        fileSystemAccess.generateFile("/.generator", "")
        val rs = new ResourceSetImpl()
        val resource = rs.createResource(fileSystemAccess.getURI("/foo.idl"))
        assertEquals(#[fileSystemAccess.getURI("/.generator")].toList,
            DefaultGenerationSettingsProvider.findConfigurationFileURIs(resource,
                new InMemoryURIConverter(fileSystemAccess)).toList)
    }

    @Test
    def void testFindConfigurationFileSpecific()
    {
        val fileSystemAccess = new InMemoryFileSystemAccess
        fileSystemAccess.generateFile("/foo.idl", "")
        fileSystemAccess.generateFile("/foo.idl.generator", "")
        val rs = new ResourceSetImpl()
        val resource = rs.createResource(fileSystemAccess.getURI("/foo.idl"))

        assertEquals(#[fileSystemAccess.getURI("/foo.idl.generator")].toList,
            DefaultGenerationSettingsProvider.findConfigurationFileURIs(resource,
                new InMemoryURIConverter(fileSystemAccess)).toList)
    }

    @Test
    def void testReadConfigurationFile()
    {
        val generationSettings = DefaultGenerationSettingsProvider.readConfigurationFile(new StringInputStream('''languages = java,cpp
            cppProjectSystem = cmake
            projectSet = full
            versions = cpp.servicecomm=0.10
            '''))
        val expected = new OptionalGenerationSettings
        expected.languages = #{ArtifactNature.JAVA, ArtifactNature.CPP}
        expected.cppProjectSystem = Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_CMAKE
        expected.projectTypes = DefaultGenerationSettingsProvider.FULL_PROJECT_SET
        expected.versions = #{"cpp.servicecomm" -> "0.10"}.entrySet

        assertEquals(expected, generationSettings)
    }

    @Test
    def void testReadPartialConfigurationFile()
    {
        val generationSettings = DefaultGenerationSettingsProvider.readConfigurationFile(new StringInputStream('''languages = java,cpp
            cppProjectSystem = cmake
            '''))
        val expected = new OptionalGenerationSettings
        expected.languages = #{ArtifactNature.JAVA, ArtifactNature.CPP}
        expected.cppProjectSystem = Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_CMAKE

        assertEquals(expected, generationSettings)
    }

    @Test
    def void testReadEmptyConfigurationFile()
    {
        val generationSettings = DefaultGenerationSettingsProvider.readConfigurationFile(new StringInputStream(""))
        val expected = new OptionalGenerationSettings

        assertEquals(expected, generationSettings)
    }

    @Test
    def void testGetSettingsEmpty()
    {
        val generationSettings = new DefaultGenerationSettingsProvider().getSettings(#[])
        val defaults = OptionalGenerationSettings.defaults

        assertEquals(defaults.languages, generationSettings.languages)
        assertTrue(generationSettings.moduleStructureStrategy instanceof PrinsModuleStructureStrategy)
        assertTrue(generationSettings.projectSetFactory instanceof VSSolutionFactory)
        for (versionEntry : defaults.versions)
        {
            assertEquals(versionEntry.value, generationSettings.getTargetVersion(versionEntry.key))
        }

        assertEquals(defaults.projectTypes, generationSettings.projectTypes)
    }

    @Test
    def void testGetSettingsPartialVersionOverride()
    {
        val partialOverrides = new OptionalGenerationSettings
        partialOverrides.versions = #{"cpp.servicecomm" -> "0.10"}.entrySet

        val generationSettings = new DefaultGenerationSettingsProvider().getSettings(#[partialOverrides])
        val defaults = OptionalGenerationSettings.defaults

        assertEquals(defaults.languages, generationSettings.languages)
        assertTrue(generationSettings.moduleStructureStrategy instanceof PrinsModuleStructureStrategy)
        assertTrue(generationSettings.projectSetFactory instanceof VSSolutionFactory)
        for (versionEntry : defaults.versions)
        {
            val override = partialOverrides.versions.filter[it.key == versionEntry.key].toList

            assertEquals(if (override.empty) versionEntry.value else override.get(0).value,
                generationSettings.getTargetVersion(versionEntry.key))
        }

        assertEquals(defaults.projectTypes, generationSettings.projectTypes)
    }
}

@Accessors(NONE)
class InMemoryURIConverter extends ExtensibleURIConverterImpl
{
    val InMemoryFileSystemAccess fileSystemAccess

    override boolean exists(URI uri, Map<?, ?> options)
    {
        fileSystemAccess.isFile(uri.convert)
    }

    override InputStream createInputStream(URI uri, Map<?, ?> options)
    {
        fileSystemAccess.readBinaryFile(uri.convert)

    }

    def String convert(URI uri)
    {
        val path = Path.fromPortableString(uri.path)
        if (uri.scheme == "memory" && path.segment(0) == "DEFAULT_OUTPUT")
            "/" + path.removeFirstSegments(1).toPortableString
        else
            throw new IllegalArgumentException("Bad URI for InMemoryURIConverter: " + uri)
    }
}
