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
package com.btc.serviceidl.generator

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.ServiceCommVersion
import com.btc.serviceidl.generator.cpp.cab.CABModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSetFactory
import com.btc.serviceidl.generator.cpp.prins.PrinsModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.prins.VSSolutionFactory
import com.btc.serviceidl.generator.dotnet.DotNetConstants
import com.btc.serviceidl.generator.java.JavaConstants
import com.google.common.collect.ImmutableSet
import com.google.common.collect.Sets
import java.util.AbstractMap
import java.util.Map
import java.util.Map.Entry
import java.util.Set
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors

class DefaultGenerationSettingsProvider implements IGenerationSettingsProvider
{

    var OptionalGenerationSettings overrides = null

    @Accessors(PUBLIC_SETTER)
    static class OptionalGenerationSettings
    {
        var Set<ArtifactNature> languages = null
        var Set<ProjectType> projectTypes = null
        var String projectSystem = null
        var Iterable<Map.Entry<String, String>> versions = null

        static def getDefaults()
        {
            val result = new OptionalGenerationSettings
            result.languages = ArtifactNature.values.toSet

            result.projectTypes = ProjectType.values.toSet
            result.projectSystem = Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_PRINS_VCXPROJ
            result.versions = #{CppConstants.SERVICECOMM_VERSION_KIND -> ServiceCommVersion.V0_12.label,
                JavaConstants.SERVICECOMM_VERSION_KIND ->
                    com.btc.serviceidl.generator.java.ServiceCommVersion.V0_5.label,
                DotNetConstants.SERVICECOMM_VERSION_KIND ->
                    com.btc.serviceidl.generator.dotnet.ServiceCommVersion.V0_6.label}.entrySet

            return result
        }
    }

    def configureOverrides(OptionalGenerationSettings generationSettings)
    {
        this.overrides = generationSettings
    }

    override getSettings(Resource resource)
    {
        // TODO read base from configuration file
        OptionalGenerationSettings.defaults.merge(overrides ?: new OptionalGenerationSettings).buildGenerationSettings
    }

    static def merge(OptionalGenerationSettings base, OptionalGenerationSettings overrides)
    {
        val result = new OptionalGenerationSettings
        result.languages = overrides.languages ?: base.languages
        result.projectTypes = overrides.projectTypes ?: base.projectTypes
        result.projectSystem = overrides.projectSystem ?: base.projectSystem
        result.versions = overrides.versions ?: base.versions
        result
    }

    static def IGenerationSettings buildGenerationSettings(OptionalGenerationSettings settings)
    {
        val result = new DefaultGenerationSettings()
        result.languages = settings.languages
        result.projectTypes = settings.projectTypes

        switch (settings.projectSystem)
        {
            case Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_CMAKE:
            {
                result.projectSetFactory = new CMakeProjectSetFactory();

                // TODO instead of printing on System.out, use some event mechanism here
                System.out.println("Disabling ODB generation, this is unsupported with CMake project system");
                result.projectTypes = Sets.difference(result.projectTypes,
                    ImmutableSet.of(ProjectType.EXTERNAL_DB_IMPL));
                result.moduleStructureStrategy = new CABModuleStructureStrategy();

            }
            case Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_PRINS_VCXPROJ:
            {
                result.projectSetFactory = new VSSolutionFactory();
                result.moduleStructureStrategy = new PrinsModuleStructureStrategy();
            }
            default:
            {
                throw new IllegalArgumentException("Unknown project system: " + settings.projectSystem)
            }
        }

        for (Entry<String, String> version : settings.versions)
        {
            result.setVersion(version.getKey(), version.getValue());
        }

        return result
    }

    def void configureGenerationSettings(String projectSystem, String versions, Iterable<ArtifactNature> languages,
        Iterable<ProjectType> projectSet)
    {
        configureGenerationSettings(projectSystem, versions.splitVersions, languages, projectSet)
    }

    def void configureGenerationSettings(String projectSystem, Iterable<Map.Entry<String, String>> versions,
        Iterable<ArtifactNature> languages, Iterable<ProjectType> projectSet)
    {
        overrides = new OptionalGenerationSettings();

        if (languages !== null) overrides.setLanguages(ImmutableSet.copyOf(languages));
        if (projectSet !== null) overrides.setProjectTypes(ImmutableSet.copyOf(projectSet));
        if (projectSystem !== null) overrides.projectSystem = projectSystem
        if (versions !== null) overrides.versions = versions
    }

    private static def Iterable<Map.Entry<String, String>> splitVersions(String optionValue)
    {
        optionValue.split(",").map [ versionEntry |
            val versionEntryParts = versionEntry.split("=")
            if (versionEntryParts.length != 2)
            {
                throw new IllegalArgumentException(
                    "Invalid version specification '" + versionEntry + "', use kind=version")
            }

            new AbstractMap.SimpleImmutableEntry<String, String>(versionEntryParts.get(0), versionEntryParts.get(1))
        ]
    }

    def reset()
    {
        this.overrides = null
    }

}
