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
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import java.util.Map
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.core.runtime.IPath

@Accessors(NONE)
class CMakeGenerator
{
    val ParameterBundle param_bundle
    val CMakeProjectSet cmakeProjectSet
    val Map<String, Set<CMakeProjectSet.ProjectReference>> protobuf_project_references
    val Set<CMakeProjectSet.ProjectReference> project_references

    val ProjectFileSet projectFileSet

    def CharSequence generateCMakeSet(String project_name, IPath project_path)
    {
        // TODO generate OPTIONAL includes for external projects?
        '''
            cab_file_guard()
            cab_add_project(${CMAKE_CURRENT_LIST_DIR})
        '''
    }

    def CharSequence generateCMakeLists(String project_name, IPath project_path)
    {
        // TODO this must be changed, pass the ProjectType to this function, and decide based on that
        val cmakeTargetType = if (project_name.contains(".Protobuf")) "STATIC_LIB" else "SHARED_LIB"
        
        // TODO instead of globbing, this could list files from the projectFileSet explicitly
        '''
            # define target name
            set( TARGET «project_name» )
            
            # TODO the section between BEGIN and END appears to be redundant
            
            #BEGIN
            
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
            #END
            
            # define list of targets which have to be linked
            set( LINK_TARGETS
              «/* TODO use the actual external references */»
              ${BTC}${CAB}Commons.Core
              ${BTC}${CAB}Commons.CoreExtras
              ${BTC}${CAB}Commons.CoreOS
              ${BTC}${CAB}Commons.FutureUtil
              ${BTC}${CAB}Logging.API
              ${BTC}${CAB}ServiceComm.API
              ${BTC}${CAB}ServiceComm.Base
              ${BTC}${CAB}ServiceComm.Commons
              ${BTC}${CAB}ServiceComm.CommonsUtil
              ${BTC}${CAB}ServiceComm.ProtobufBase
              ${BTC}${CAB}ServiceComm.ProtobufUtil
              ${BTC}${CAB}ServiceComm.TestBase
              ${BTC}${CAB}ServiceComm.Util
              libprotobuf
              #TODO BTCCABINF-1257 this is just to make it work. Is * ok here?
              libboost*
              «FOR project : project_references»
              «/* TODO this doesn't seem to be the right place to filter out self-references */»
              «IF project.projectName != project_name»
              «project.projectName»
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
