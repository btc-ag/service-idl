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
import com.google.common.collect.ImmutableMap
import com.google.common.collect.ImmutableSet
import com.google.common.collect.Sets
import java.io.InputStream
import java.util.AbstractMap
import java.util.Map
import java.util.Map.Entry
import java.util.Properties
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.URIConverter
import org.eclipse.emf.ecore.resource.impl.ExtensibleURIConverterImpl
import org.eclipse.xtend.lib.annotations.Accessors
import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider.OptionalGenerationSettings
import com.google.common.base.Objects
import com.google.common.base.MoreObjects
import com.btc.serviceidl.generator.common.PackageInfo

class DefaultGenerationSettingsProvider implements IGenerationSettingsProvider
{

    var OptionalGenerationSettings overrides = null

    @Accessors(PUBLIC_SETTER, PUBLIC_GETTER)
    static class OptionalGenerationSettings
    {
        var Set<ArtifactNature> languages = null
        var Set<ProjectType> projectTypes = null
        var String cppProjectSystem = null // TODO change into a enum here
        var Iterable<Map.Entry<String, String>> versions = null
        var Maturity maturity = null
        var Set<PackageInfo> dependencies = null

        override equals(Object other)
        {
            if (other !== null)
                if (other instanceof OptionalGenerationSettings)
                {
                    return ((languages === null && other.languages === null) ||
                        Objects.equal(languages.toSet, other.languages.toSet)) &&
                        ((projectTypes === null && other.projectTypes === null) ||
                            Objects.equal(projectTypes.toSet, other.projectTypes.toSet)) &&
                        Objects.equal(cppProjectSystem, other.cppProjectSystem) &&
                        ((versions === null && other.versions === null) ||
                            Objects.equal(versions.toSet, other.versions.toSet) &&
                        ((dependencies === null && other.dependencies === null) ||
                            Objects.equal(dependencies.toSet, other.dependencies.toSet)
                        ))
                }

            false
        }

        override hashCode()
        {
            java.util.Objects.hash(languages, projectTypes, cppProjectSystem, versions)
        }

        override toString()
        {
            MoreObjects.toStringHelper(this).add("languages", languages).add("projectTypes", projectTypes).add(
                "cppProjectSystem", cppProjectSystem).add("versions", versions)
                .add("import", dependencies).toString
        }

        static def getDefaults()
        {
            val result = new OptionalGenerationSettings
            result.languages = ArtifactNature.values.toSet

            result.projectTypes = ProjectType.values.toSet
            result.cppProjectSystem = Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_PRINS_VCXPROJ
            result.versions = #{CppConstants.SERVICECOMM_VERSION_KIND -> ServiceCommVersion.V0_12.label,
                JavaConstants.SERVICECOMM_VERSION_KIND ->
                    com.btc.serviceidl.generator.java.ServiceCommVersion.V0_5.label,
                DotNetConstants.SERVICECOMM_VERSION_KIND ->
                    com.btc.serviceidl.generator.dotnet.ServiceCommVersion.V0_7.label}.entrySet

            return result
        }

        static def create(String cppProjectSystem, Iterable<Entry<String, String>> versions,
            Iterable<ArtifactNature> languages, Iterable<ProjectType> projectTypes, Maturity maturity, Iterable<PackageInfo> dependencies)
        {
            val settings = new OptionalGenerationSettings()

            if (languages !== null) settings.setLanguages(ImmutableSet.copyOf(languages))
            if (projectTypes !== null) settings.setProjectTypes(ImmutableSet.copyOf(projectTypes))
            if (cppProjectSystem !== null) settings.cppProjectSystem = cppProjectSystem
            if (versions !== null) settings.versions = versions
            settings.maturity = maturity
            if (dependencies !== null) settings.dependencies = ImmutableSet.copyOf(dependencies)

            settings
        }

        static def create(String cppProjectSystem, String versions, Iterable<ArtifactNature> languages,
            String projectSet, Maturity maturity, Iterable<PackageInfo> dependencies)
        {
            create(cppProjectSystem, versions.splitVersions, languages, PROJECT_SET_MAPPING.get(projectSet), maturity, dependencies)
        }

    }

    def configureOverrides(OptionalGenerationSettings generationSettings)
    {
        this.overrides = generationSettings
    }

    override getSettings(Resource resource)
    {
        val settingsFromFile = resource.findConfigurationFiles.map[readConfigurationFile]
        getSettings(settingsFromFile)
    }

    def getSettings(Iterable<OptionalGenerationSettings> settingsFromFile)
    {
        #[#[OptionalGenerationSettings.defaults], settingsFromFile,
            if (overrides !== null) #[overrides] else #[]].flatten.reduce[a, b|merge(a, b)].buildGenerationSettings
    }

    static def OptionalGenerationSettings readConfigurationFile(InputStream configurationFile)
    {
        // val reader = new BufferedReader(new InputStreamReader(configurationFile, StandardCharsets.UTF_8))
        val properties = new Properties
        properties.load(configurationFile)

        val languages = (properties.get("languages") as String)
        OptionalGenerationSettings.create(properties.get("cppProjectSystem") as String,
            properties.get("versions") as String, (languages?.split(",")?.map [ str |
                ArtifactNature.values.filter[it.label == str].single
            ]?.toSet), properties.get("projectSet") as String, null, null)
    }

    private static def <T> single(Iterable<T> iterable)
    {
        if (iterable.size == 1)
            iterable.head
        else
            throw new IllegalArgumentException("iterable is not of length 1")
    }

    public static val CONFIG_FILE_NAME_EXT = "generator"

    static def Iterable<URI> findConfigurationFileURIs(Resource resource, URIConverter handler)
    {
        val folder = resource.URI.trimSegments(1)
        val candidates = #[folder.appendSegment("." + CONFIG_FILE_NAME_EXT),
            resource.URI.appendFileExtension(CONFIG_FILE_NAME_EXT)]
        val files = candidates.filter[handler.exists(it, null)]
        System.out.println("[INFO] Found configuration files: " + if (files.empty) "<none>" else files.join(", "))
        files
    }

    static def Iterable<InputStream> findConfigurationFiles(Resource resource)
    {
        val handler = new ExtensibleURIConverterImpl
        return resource.findConfigurationFileURIs(handler).map[handler.createInputStream(it, null)]
    }

    static def merge(OptionalGenerationSettings base, OptionalGenerationSettings overrides)
    {
        val result = new OptionalGenerationSettings
        result.languages = overrides.languages ?: base.languages
        result.projectTypes = overrides.projectTypes ?: base.projectTypes
        result.cppProjectSystem = overrides.cppProjectSystem ?: base.cppProjectSystem
        result.dependencies = overrides.dependencies ?: base.dependencies
        result.versions = if (overrides.versions !== null)
        {
            val resultVersions = base.versions.toMap([key], [value])
            resultVersions.putAll(overrides.versions.toMap([key], [value]))
            resultVersions.entrySet
        }
        else
            base.versions
        result.maturity = overrides.maturity ?: base.maturity
        result
    }

    static def IGenerationSettings buildGenerationSettings(OptionalGenerationSettings settings)
    {
        val result = new DefaultGenerationSettings()
        result.languages = settings.languages
        result.projectTypes = settings.projectTypes
        result.dependencies = settings.dependencies
        
        switch (settings.cppProjectSystem)
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
                throw new IllegalArgumentException("Unknown project system: " + settings.cppProjectSystem)
            }
        }

        for (Entry<String, String> version : settings.versions)
        {
            result.setVersion(version.getKey(), version.getValue());
        }

        if (settings.maturity !== null)
            result.maturity = settings.maturity

        return result
    }

    def void configureGenerationSettings(String cppProjectSystem, String versions, Iterable<ArtifactNature> languages,
        String projectSet, Maturity maturity, Iterable<PackageInfo> dependencies)
    {
        overrides = OptionalGenerationSettings.create(cppProjectSystem, versions, languages, projectSet, maturity, dependencies)
    }

    def void configureGenerationSettings(String cppProjectSystem, Iterable<Map.Entry<String, String>> versions,
        Iterable<ArtifactNature> languages, Iterable<ProjectType> projectTypes, Maturity maturity, Iterable<PackageInfo> dependencies)
    {
        overrides = OptionalGenerationSettings.create(cppProjectSystem, versions, languages, projectTypes, maturity, dependencies)
    }

    private static def Iterable<Map.Entry<String, String>> splitVersions(String optionValue)
    {
        optionValue?.split(",")?.map [ versionEntry |
            val versionEntryParts = versionEntry.split("=")
            if (versionEntryParts.length != 2)
            {
                throw new IllegalArgumentException(
                    "Invalid version specification '" + versionEntry + "', use kind=version")
            }

            new AbstractMap.SimpleImmutableEntry<String, String>(versionEntryParts.get(0), versionEntryParts.get(1))
        ]
    }

    public static val OPTION_VALUE_PROJECT_SET_API = "api"
    public static val OPTION_VALUE_PROJECT_SET_CLIENT = "client"
    public static val OPTION_VALUE_PROJECT_SET_SERVER = "server"
    public static val OPTION_VALUE_PROJECT_SET_FULL = "full"
    public static val OPTION_VALUE_PROJECT_SET_FULL_WITH_SKELETON = "full-with-skeleton"

    public static val Set<ProjectType> API_PROJECT_SET = ImmutableSet.of(ProjectType.SERVICE_API, ProjectType.COMMON)
    public static val Set<ProjectType> CLIENT_PROJECT_SET = Sets.union(API_PROJECT_SET,
        ImmutableSet.of(ProjectType.PROTOBUF, ProjectType.PROXY, ProjectType.CLIENT_CONSOLE))

    // TODO the SERVER_RUNNER depends on the IMPL project, this must be replaced by using the IoC container
    // to remove the dependency, then the SERVER_RUNNER can be generated again without IMPL
    public static val Set<ProjectType> SERVER_PROJECT_SET = Sets.union(API_PROJECT_SET,
        ImmutableSet.of(ProjectType.PROTOBUF, ProjectType.DISPATCHER /*, ProjectType.SERVER_RUNNER*/ ))
    public static val Set<ProjectType> FULL_PROJECT_SET = Sets.union(CLIENT_PROJECT_SET, SERVER_PROJECT_SET)

    public static val Map<String, Set<ProjectType>> PROJECT_SET_MAPPING = ImmutableMap.of(OPTION_VALUE_PROJECT_SET_API,
        API_PROJECT_SET, OPTION_VALUE_PROJECT_SET_CLIENT, CLIENT_PROJECT_SET, OPTION_VALUE_PROJECT_SET_SERVER,
        SERVER_PROJECT_SET, OPTION_VALUE_PROJECT_SET_FULL, FULL_PROJECT_SET,
        OPTION_VALUE_PROJECT_SET_FULL_WITH_SKELETON, ImmutableSet.copyOf(ProjectType.values()))

    def reset()
    {
        this.overrides = null
    }

}
