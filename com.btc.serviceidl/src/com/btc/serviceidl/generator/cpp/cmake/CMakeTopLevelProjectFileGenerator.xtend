package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.IGenerationSettings
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.ServiceCommVersion
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.core.runtime.Path
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension com.btc.serviceidl.generator.common.GeneratorUtil.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.generator.Maturity

@Accessors(NONE)
class CMakeTopLevelProjectFileGenerator
{
    val IFileSystemAccess fileSystemAccess
    val IGenerationSettings generationSettings
    val CMakeProjectSet projectSet
    val ModuleDeclaration module

    new(IFileSystemAccess fileSystemAccess, IGenerationSettings generationSettings, IProjectSet projectSet,
        ModuleDeclaration module)
    {
        this.fileSystemAccess = fileSystemAccess
        this.generationSettings = generationSettings
        this.projectSet = projectSet as CMakeProjectSet
        this.module = module
    }

    def generate()
    {
        // TODO this depends on the implementation of ProjectGeneratorBaseBase.getProjectPath
        val topLevelPath = modulePath
        fileSystemAccess.generateFile(
            topLevelPath.append("conanfile.py").toString,
            ArtifactNature.CPP.label,
            generateConanfile().toString
        )

        fileSystemAccess.generateFile(
            topLevelPath.append("CMakeLists.txt").toString,
            ArtifactNature.CPP.label,
            generateCMakeLists().toString
        )

        fileSystemAccess.generateFile(
            topLevelPath.append("res").append("sharedVersion.h").toString,
            ArtifactNature.CPP.label,
            generateSharedVersionHeader().toString
        )
    }

    private def getProjectName()
    {
        this.module.getParent(IDLSpecification).getReleaseUnitName(ArtifactNature.CPP)
    }

    private def modulePath()
    {
        // TODO the commented-out version worked only when the moduleStack was empty. Something is inconsistent here        
        // GeneratorUtil.asPath(new ParameterBundle.Builder().reset(module.moduleStack).build, ArtifactNature.CPP)
        Path.fromOSString("")
    }

    def generateConanfile()
    {
        val serviceCommTargetVersion = ServiceCommVersion.get(generationSettings.getTargetVersion(
            CppConstants.SERVICECOMM_VERSION_KIND))
        val commonsTargetVersion = if (serviceCommTargetVersion == ServiceCommVersion.V0_10 ||
                serviceCommTargetVersion == ServiceCommVersion.V0_11) "1.8" else "1.9"
        val iocTargetVersion = if (serviceCommTargetVersion == ServiceCommVersion.V0_10 ||
                serviceCommTargetVersion == ServiceCommVersion.V0_11) "1.7" else "1.8"
        val loggingTargetVersion = if (serviceCommTargetVersion == ServiceCommVersion.V0_10 ||
                serviceCommTargetVersion == ServiceCommVersion.V0_11) "1.7" else "1.8"
                
        val versionSuffix = if (generationSettings.maturity == Maturity.SNAPSHOT) "-unreleased" else ""
        val dependencyChannel = if (generationSettings.maturity == Maturity.SNAPSHOT) "testing" else "stable"

        // TODO the transitive dependencies do not need to be specified here
        '''
            from conan_template import *
            
            class Conan(ConanTemplate):
                name = "«projectName»"
                version = version_name("«module.resolveVersion»«versionSuffix»")
                url = "TODO"
                description = """
                TODO
                """
            
                build_requires = "CMakeMacros/0.3.latest@cab/«dependencyChannel»"
                # TODO instead of "latest", for maturity RELEASE, this should be replaced by a 
                # concrete version at some point (maybe not during generation, but during the build?)
                # in a similar manner as mvn versions:resolve-ranges                
                requires = ( 
                            ("BTC.CAB.Commons/«commonsTargetVersion».latest@cab/«dependencyChannel»"),
                            ("BTC.CAB.IoC/«iocTargetVersion».latest@cab/«dependencyChannel»"),
                            ("BTC.CAB.Logging/«loggingTargetVersion».latest@cab/«dependencyChannel»"),
                            ("BTC.CAB.ServiceComm/«serviceCommTargetVersion.label».latest@cab/«dependencyChannel»")
                            )
                generators = "cmake"
                short_paths = True

                def generateProtoFiles(self):
                    protofiles = glob.glob(self.source_folder + "/**/gen/*.proto", recursive=True)
                    outdir = self.source_folder
                    
                    self.run('bin\\protoc.exe --proto_path=' + self.source_folder + ' --cpp_out="%s" %s' % (outdir, ' '.join(protofiles)))

                def build(self):
                    self.generateProtoFiles()
                    ConanTemplate.build(self)

                def package(self):
                    ConanTemplate.package(self)
                    self.copy("**/*.proto", dst="proto", keep_path=True)
            
                def imports(self):
                    self.copy("protoc.exe", "bin", "bin")
        '''
    }

    def generateSharedVersionHeader()
    {
        val versionString = this.module.resolveVersion
        val versionParts = versionString.split("[.]")
        
        '''
            // ==================================
            // version information
            // ==================================
            // define version numbers
            #define VER_MAJOR «versionParts.get(0)»
            #define VER_MINOR «versionParts.get(1)»
            #define VER_BUILD «versionParts.get(2)»
            #define VER_BUILD_ID 0
            #define VER_REVISION_INFO ""
            #define VER_SUFFIX ""
            
            // build default file and product version
            #define FILE_VER VER_MAJOR,VER_MINOR,VER_BUILD,VER_BUILD_ID
            #define PROD_VER FILE_VER
            
            // special macros that convert numerical version tokens into string tokens
            // can't use actual int and string types because they won't work in the RC files
            #define STRINGIZE2(x) #x
            #define STRINGIZE(x) STRINGIZE2(x)
            
            // build file and product version as string
            #define STR_FILE_VER STRINGIZE(VER_MAJOR) "." STRINGIZE(VER_MINOR) "." STRINGIZE(VER_BUILD) "." STRINGIZE(VER_BUILD_ID) VER_SUFFIX "+" VER_REVISION_INFO
            #define STR_PROD_VER STR_FILE_VER
            
            // ==================================
            // company information
            // ==================================
            #define STR_COMPANY             "BTC Business Technology Consulting AG"
            
            // ==================================
            // copyright information
            // ==================================
            #define STR_COPYRIGHT_INFO      "Copyright (C) BTC Business Technology Consulting AG 2018"        
        '''
    }

    def generateCMakeLists()
    {
        // TODO defining BTC_CAB_COMMONS_FUTUREUTIL_STATIC_DEFINE is only a temporary addition
        // which can be removed again when changing this to the new cmake-export style
        val serviceCommTargetVersion = ServiceCommVersion.get(generationSettings.getTargetVersion(
            CppConstants.SERVICECOMM_VERSION_KIND))

        '''
            cmake_minimum_required(VERSION 3.4)
            
            project («projectName» CXX)
            
            include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
            conan_basic_setup()
            
            include(${CONAN_CMAKEMACROS_ROOT}/cmake/cab_globals.cmake)
            
            option(BUILD_TESTS "Build test" ON)
            
            include_directories(${CMAKE_SOURCE_DIR})
            set(CAB_INT_SOURCE_DIR ${CMAKE_SOURCE_DIR})
            set(CAB_EXT_SOURCE_DIR ${CMAKE_SOURCE_DIR}/../)
            
            «IF serviceCommTargetVersion == ServiceCommVersion.V0_12»
                add_definitions(-DBTC_CAB_COMMONS_FUTUREUTIL_STATIC_DEFINE)
            «ENDIF»

            «FOR projectPath : projectSet.projects.map[relativePath.toPortableString].sort»
                include(${CMAKE_CURRENT_LIST_DIR}/«projectPath»/build/make.cmakeset)
            «ENDFOR»
        '''
    }

    private def relativePath(ParameterBundle paramBundle)
    {
        generationSettings.moduleStructureStrategy.getProjectDir(paramBundle).makeRelativeTo(modulePath)
    }

}
