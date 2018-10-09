/**
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.CppConstants
import com.btc.serviceidl.generator.cpp.ExternalDependency
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import com.btc.serviceidl.generator.cpp.ServiceCommVersion
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import org.eclipse.core.runtime.Path
import com.btc.serviceidl.generator.common.PackageInfoProvider

@Accessors(NONE)
class CMakeGenerator
{
    val IModuleStructureStrategy moduleStructureStrategy
    val ITargetVersionProvider targetVersionProvider
    val Iterable<ExternalDependency> externalDependencies
    val Set<CMakeProjectSet.ProjectReference> projectReferences

    val ProjectFileSet projectFileSet

    def CharSequence generateCMakeSet(String projectName, IPath projectPath)
    {
        // TODO generate OPTIONAL includes for external projects?
        '''
            cab_file_guard()
            cab_add_project(${CMAKE_CURRENT_LIST_DIR})
        '''
    }

    def CharSequence generateCMakeLists(String projectName, IPath projectPath, ProjectType projectType)
    {
        val serviceCommTargetVersion = ServiceCommVersion.get(targetVersionProvider.getTargetVersion(
            CppConstants.SERVICECOMM_VERSION_KIND))

        if (serviceCommTargetVersion == ServiceCommVersion.V0_12)
            generateCMakeListsNewStyle(projectName, projectPath, projectType)
        else
            generateCMakeListsOldStyle(projectName, projectPath, projectType)
    }

    private def CharSequence generateCMakeListsNewStyle(String projectName, IPath projectPath, ProjectType projectType)
    {
        val cmakeTargetType = projectType.cmakeTargetType

        if (moduleStructureStrategy.sourceFileDir != Path.fromPortableString("src"))
        {
            throw new IllegalArgumentException(
                "A module structure strategy specifying sourceFileDir != src is not currently supported by the CMakeGenerator " +
                    "(since cab_default_grouped_sources assumes this directory)")
        }

        // TODO properly distinguish between PUBLIC and PRIVATE dependencies
        '''
            set(TARGET «projectName»)
            
            cab_create_target(«cmakeTargetType» ${TARGET})
            «IF projectType != ProjectType.PROTOBUF»
                cab_default_grouped_sources(${TARGET})
            «ENDIF»
            target_compile_definitions( ${TARGET}
                PRIVATE -DCAB_NO_LEGACY_EXPORT_MACROS
            )
            target_link_libraries(${TARGET}
                PUBLIC
                  «FOR lib : externalDependencies.map[libraryName].sort»
                      «getCmakeTargetName(lib)»
                  «ENDFOR»
                  «FOR referencedProjectName : getSortedInternalDependencies(projectName)»
                      «getCmakeReferenceName(projectName, referencedProjectName)»
                  «ENDFOR»              
            )
            
            «IF projectType == ProjectType.PROTOBUF»
                file(GLOB PROTOBUF_SRCS «protobufSourceFilesGlob»)
                target_sources(${TARGET} PRIVATE ${PROTOBUF_SRCS}) 
            «ENDIF»
            
            «/* set linker_language explicitly to allow for modules without source files (headers only) */»
            set_target_properties("${TARGET}" PROPERTIES LINKER_LANGUAGE CXX)
        '''
    }

    def getCmakeTargetName(String libName)
    {
        if (libName.startsWith("BTC.CAB."))
            libName.CABLibPrefix
        else if (libName == "libprotobuf")
            "protobuf::libprotobuf"
        else
            throw new IllegalArgumentException(
                "Don't know how to map library to a cmake target: " + libName
            )
    }
    
    private def getCmakeReferenceName(String currentProject, String referencedProject)
    {
        val projectName = PackageInfoProvider.getName(currentProject)
        val referenceName = PackageInfoProvider.getName(referencedProject)
        if (projectName == referenceName)
            referencedProject
        else
            referencedProject.CABLibPrefix
    }
    
    private def static getCABLibPrefix(String libName)
    {
        '''CAB::«libName»'''
    }
    
    def getSortedInternalDependencies(String projectName)
    {
        /* TODO this doesn't seem to be the right place to filter out self-references */
        projectReferences.map[it.projectName].sort.filter[it != projectName]
    }
    
    private def CharSequence generateCMakeListsOldStyle(String projectName, IPath projectPath,
        ProjectType projectType)
    {
        val cmakeTargetType = projectType.cmakeTargetType
    
        // TODO instead of globbing, this could list files from the projectFileSet explicitly
        '''
            # define target name
            set( TARGET «projectName» )
            
            # Components include dirs
            file( GLOB INCS ../include/*.h* ../include/**/*.h* )
            
            # Components source files
            file( GLOB SRCS «Path.fromPortableString("..").append(moduleStructureStrategy.sourceFileDir).append("*.cpp").toPortableString» «protobufSourceFilesGlob» )
            
            if( MSVC )
                # other resources
                file( GLOB RESOURCE ../res/*.rc )
                file( GLOB RESOURCE_H ../res/*.h )
            endif()
            
            # summerize files
            set( FILES ${INCS} ${SRCS} ${RESOURCE} ${RESOURCE_H} )
            source_group( "Resources" FILES ${RESOURCE} ${RESOURCE_H} )
            
            # define list of targets which have to be linked
            set( LINK_TARGETS
              «FOR lib : externalDependencies.map[libraryName].sort»
                  «lib»
              «ENDFOR»
              «FOR referencedProjectName : getSortedInternalDependencies(projectName)»
                  «getCmakeReferenceName(projectName, referencedProjectName)»
              «ENDFOR»              
            )
            
            # define list of dependent targets
            set( DEP_TARGETS
              ${LINK_TARGETS}
            )
            
            add_definitions( -DCAB_NO_LEGACY_EXPORT_MACROS )
            
            # define complete target description
            MY_TARGET( «cmakeTargetType» TARGET FILES DEP_TARGETS LINK_TARGETS WARNING_LEVEL_DEFAULT COMPILE_OPTS_DEFAULT )
            #ENABLE_WARNINGSASERRORS( "${TARGET}" )
            
            «/* set linker_language explicitly to allow for modules without source files (headers only) */»
            set_target_properties("${TARGET}" PROPERTIES LINKER_LANGUAGE CXX)
        '''
    }

    def getProtobufSourceFilesGlob() 
    {
        Path.fromPortableString("..").append("gen").append("*.cc").toPortableString
    }

    static def getCmakeTargetType(ProjectType projectType)
    {
        if (projectType == ProjectType.PROTOBUF) "STATIC_LIB" else "SHARED_LIB"
    }

}
