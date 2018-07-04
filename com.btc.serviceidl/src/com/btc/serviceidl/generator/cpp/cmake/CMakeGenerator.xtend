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

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.ExternalDependency
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(NONE)
class CMakeGenerator
{
    val ParameterBundle parameterBundle
    val Iterable<ExternalDependency> externalDependencies
    val Map<CMakeProjectSet.ProjectReference, Set<CMakeProjectSet.ProjectReference>> protobufProjectReferences
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
        val cmakeTargetType = if (projectType == ProjectType.PROTOBUF) "STATIC_LIB" else "SHARED_LIB"
        
        // TODO instead of globbing, this could list files from the projectFileSet explicitly
        '''
            # define target name
            set( TARGET «projectName» )
            
            # Components include dirs
            file( GLOB INCS ../include/*.h* ../include/**/*.h* )
            
            # Components source files
            file( GLOB SRCS ../source/*.cpp ../gen/*.cc )
            
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
              «FOR referencedProjectName : projectReferences.map[it.projectName].sort»
              «/* TODO this doesn't seem to be the right place to filter out self-references */»
              «IF referencedProjectName != projectName»
              «referencedProjectName»
              «ENDIF»
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

}
