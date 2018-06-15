package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.core.runtime.Path
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class CMakeTopLevelProjectFileGenerator
{
    val IFileSystemAccess file_system_access
    val IGenerationSettingsProvider generationSettingsProvider
    val CMakeProjectSet projectSet
    val ModuleDeclaration module

    new(IFileSystemAccess file_system_access, IGenerationSettingsProvider generationSettingsProvider,
        IProjectSet projectSet, ModuleDeclaration module)
    {
        this.file_system_access = file_system_access
        this.generationSettingsProvider = generationSettingsProvider
        this.projectSet = projectSet as CMakeProjectSet
        this.module = module
    }

    def generate()
    {
        // TODO this depends on the implementation of ProjectGeneratorBaseBase.getProjectPath
        val topLevelPath = modulePath
        file_system_access.generateFile(
            topLevelPath.append("conanfile.py").toString,
            ArtifactNature.CPP.label,
            generateConanfile().toString
        )

        file_system_access.generateFile(
            topLevelPath.append("CMakeLists.txt").toString,
            ArtifactNature.CPP.label,
            generateCMakeLists().toString
        )
    }

    private def getProjectName()
    {
        // TODO this should be specified somewhere, maybe on the command line
        "Test"
    }

    private def modulePath()
    {
        // TODO the commented-out version worked only when the moduleStack was empty. Something is inconsistent here        
        // GeneratorUtil.asPath(new ParameterBundle.Builder().reset(module.moduleStack).build, ArtifactNature.CPP)
        Path.fromOSString("")
    }

    def generateConanfile()
    {
        val serviceCommTargetVersion = generationSettingsProvider.getTargetVersion(
            CppConstants.SERVICECOMM_VERSION_KIND)
        val commonsTargetVersion = if (serviceCommTargetVersion == "0.10" ||
                serviceCommTargetVersion == "0.11") "1.8" else "1.9"
        val iocTargetVersion = if (serviceCommTargetVersion == "0.10" ||
                serviceCommTargetVersion == "0.11") "1.7" else "1.8"
        val loggingTargetVersion = if (serviceCommTargetVersion == "0.10" ||
                serviceCommTargetVersion == "0.11") "1.7" else "1.8"
        '''
            from conan_template import *
            
            class Conan(ConanTemplate):
                name = "«projectName»"
                version= version_name("0.1.0-unreleased")
                url = "TODO"
                description = """
                TODO
                """
            
                build_requires = "CMakeMacros/0.3.latest@cab/testing"
                requires = ( 
                            ("BTC.CAB.Commons/«commonsTargetVersion».latest@cab/testing"),
                            ("BTC.CAB.IoC/«iocTargetVersion».latest@cab/testing"),
                            ("BTC.CAB.Logging/«loggingTargetVersion».latest@cab/testing"),
                            ("BTC.CAB.ServiceComm/«serviceCommTargetVersion».latest@cab/testing")
                            )
                generators = "cmake"
                short_paths = True
        '''
    }

    def generateCMakeLists()
    {
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
            
            «FOR project : projectSet.projects»
                include(${CMAKE_CURRENT_LIST_DIR}/«relativePath(project)»/build/make.cmakeset)
            «ENDFOR»
        '''
    }

    private def relativePath(ParameterBundle paramBundle)
    {
        // TODO this depends on the implementation of ProjectGeneratorBaseBase.getProjectPath
        val projectDir = new Path("modules").append(
            GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.FILE_SYSTEM))
        projectDir.makeRelativeTo(modulePath)
    }

}
