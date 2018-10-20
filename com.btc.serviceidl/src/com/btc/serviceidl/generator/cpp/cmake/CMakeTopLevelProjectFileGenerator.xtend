package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.IGenerationSettings
import com.btc.serviceidl.generator.Maturity
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
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
        val cmakeMacrosVersion = if (serviceCommTargetVersion == ServiceCommVersion.V0_10 ||
                serviceCommTargetVersion == ServiceCommVersion.V0_11) "0.3" else "0.4"
                
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
            
                build_requires = "CMakeMacros/«cmakeMacrosVersion».latest@cab/«dependencyChannel»"
                # TODO instead of "latest", for maturity RELEASE, this should be replaced by a 
                # concrete version at some point (maybe not during generation, but during the build?)
                # in a similar manner as mvn versions:resolve-ranges                
                requires = ( 
                            ("BTC.CAB.Commons/«commonsTargetVersion».latest@cab/«dependencyChannel»"),
                            ("BTC.CAB.IoC/«iocTargetVersion».latest@cab/«dependencyChannel»"),
                            ("BTC.CAB.Logging/«loggingTargetVersion».latest@cab/«dependencyChannel»"),
                            ("BTC.CAB.ServiceComm/«serviceCommTargetVersion.label».latest@cab/«dependencyChannel»"),
                            «IF projectSet.projects.exists[it.projectType == ProjectType.TEST]»
                                ("BTC.CAB.ServiceComm.SQ/«serviceCommTargetVersion.label».latest@cab/«dependencyChannel»"),
                                «IF serviceCommTargetVersion == ServiceCommVersion.V0_11»
                                    ("libzmq/4.2.3@cab/extern", "private"),
                                «ENDIF»
                            «ENDIF»
                            «FOR dependency : generationSettings.dependencies.sortBy[getID(ArtifactNature.CPP)]»
                                ("«dependency.getID(ArtifactNature.CPP)»/«dependency.version»«versionSuffix»@cab/«dependencyChannel»"),
                            «ENDFOR»
                            )
                generators = "cmake"
                short_paths = True

                def generateProtoFiles(self):
                    protofiles = glob.glob(self.source_folder + "/**/gen/*.proto", recursive=True)
                    outdir = self.source_folder
                    
                    self.run('bin\\protoc.exe --proto_path=' + self.source_folder
                        «FOR dependency : generationSettings.dependencies.sortBy[getID(ArtifactNature.CPP)]»
                            + ' --proto_path="' + os.path.normpath(os.path.join(self.deps_cpp_info["«dependency.getID(ArtifactNature.CPP)»"].rootpath, 'proto')) + '"'
                        «ENDFOR»
                        + ' --cpp_out="%s" %s' % (outdir, ' '.join(protofiles)))

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
        // TODO why is find_package(Boost COMPONENTS thread REQUIRED) required? probably because 
        // the BTC.CAB.ServiceComm package BTC.CAB.ServiceCommConfig.cmake file does not properly 
        // specify its own dependency on it
        
        // TODO only generate the find_package calls that are actually required, depending on the 
        // actual dependencies
        
        val serviceCommTargetVersion = ServiceCommVersion.get(generationSettings.getTargetVersion(
            CppConstants.SERVICECOMM_VERSION_KIND))

        '''
            «IF serviceCommTargetVersion == ServiceCommVersion.V0_12»
                cmake_minimum_required(VERSION 3.11)
            «ELSE»
                cmake_minimum_required(VERSION 3.4)
            «ENDIF»
            
            project («projectName» CXX)
            
            include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
            «IF serviceCommTargetVersion == ServiceCommVersion.V0_12»
                set(CAB_RELEASE_UNIT «projectName»)
                conan_basic_setup(TARGETS)
            «ELSE»
                conan_basic_setup()
            «ENDIF»
            
            include(${CONAN_CMAKEMACROS_ROOT}/cmake/cab_globals.cmake)
            
            option(BUILD_TESTS "Build test" ON)
            
            include_directories(${CMAKE_SOURCE_DIR})
            set(CAB_INT_SOURCE_DIR ${CMAKE_SOURCE_DIR})
            set(CAB_EXT_SOURCE_DIR ${CMAKE_SOURCE_DIR}/../)
            
            «IF serviceCommTargetVersion == ServiceCommVersion.V0_12»
                find_package(Protobuf REQUIRED)
                find_package(Boost COMPONENTS thread program_options REQUIRED)
                find_package(BTC.CAB.ServiceComm REQUIRED)
                «IF projectSet.projects.exists[it.projectType == ProjectType.TEST]»
                find_package(BTC.CAB.ServiceComm.SQ REQUIRED)
                «ENDIF»
            «ENDIF»
            «FOR dependency : generationSettings.dependencies.sortBy[getID(ArtifactNature.CPP)]»
                find_package(«dependency.getID(ArtifactNature.CPP)» REQUIRED)
            «ENDFOR»

            «FOR project : projectSet.projects.sortBy[relativePath.toPortableString]»
                «IF module.eResource.URI == project.resourceURI»
                    include(${CMAKE_CURRENT_LIST_DIR}/«project.relativePath.toPortableString»/build/make.cmakeset)
                «ENDIF»
            «ENDFOR»

            «IF serviceCommTargetVersion == ServiceCommVersion.V0_12»
                install(EXPORT ${CAB_RELEASE_UNIT} DESTINATION cmake NAMESPACE CAB::)
            «ENDIF»
        '''
    }

    private def relativePath(ParameterBundle paramBundle)
    {
        generationSettings.moduleStructureStrategy.getProjectDir(paramBundle).makeRelativeTo(modulePath)
    }

}
