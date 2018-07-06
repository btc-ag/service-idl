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
package com.btc.serviceidl.tests.generator.cpp

import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.Main
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.generator.AbstractGeneratorTest
import com.btc.serviceidl.tests.testdata.TestData
import com.google.common.collect.ImmutableMap
import java.util.Arrays
import java.util.HashSet
import java.util.Map
import java.util.Set
import javax.inject.Inject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class CppGeneratorTest extends AbstractGeneratorTest
{
    @Inject IGenerationSettingsProvider generationSettingsProvider

    @Test
    def void testBasicServiceApi()
    {
        val fileCount = 6
        val projectTypes = new HashSet<ProjectType>(Arrays.asList(ProjectType.SERVICE_API))
        val directory = ArtifactNature.CPP.label + "modules/Infrastructure/ServiceHost/Demo/API/ServiceAPI/"
        val contents = ImmutableMap.of(directory + "include/IKeyValueStore.h", '''
            #pragma once
            #include "modules/Commons/include/BeginPrinsModulesInclude.h"
            
            #include "btc_prins_infrastructure_servicehost_demo_api_serviceapi_export.h"
            
            #include "modules/Commons/include/BeginCabInclude.h"     // CAB -->
            #include "Commons/Core/include/Object.h"
            #include "Commons/CoreExtras/include/UUID.h"
            #include "ServiceComm/API/include/IServiceFaultHandler.h"
            #include "modules/Commons/include/EndCabInclude.h"       // <-- CAB			
            
            namespace BTC {
            namespace PRINS {
            namespace Infrastructure {
            namespace ServiceHost {
            namespace Demo {
            namespace API {
            namespace ServiceAPI {			   
               class BTC_PRINS_INFRASTRUCTURE_SERVICEHOST_DEMO_API_SERVICEAPI_EXPORT
               IKeyValueStore : virtual public BTC::Commons::Core::Object
               {
               public:
                  /** \return {384E277A-C343-4F37-B910-C2CE6B37FC8E} */
                  static BTC::Commons::CoreExtras::UUID TYPE_GUID();
                  
               };
               void BTC_PRINS_INFRASTRUCTURE_SERVICEHOST_DEMO_API_SERVICEAPI_EXPORT
               RegisterKeyValueStoreServiceFaults(BTC::ServiceComm::API::IServiceFaultHandlerManager& serviceFaultHandlerManager);
            }}}}}}}
            
            #include "modules/Commons/include/EndPrinsModulesInclude.h"
        ''', directory + "source/IKeyValueStore.cpp", '''
            #include "modules/Infrastructure/ServiceHost/Demo/API/ServiceAPI/include/IKeyValueStore.h"
            
            #include "modules/Commons/include/BeginCabInclude.h"     // CAB -->
            #include "Commons/Core/include/InvalidArgumentException.h"
            #include "Commons/Core/include/String.h"
            #include "Commons/Core/include/UnsupportedOperationException.h"
            #include "Commons/CoreExtras/include/UUID.h"
            #include "ServiceComm/API/include/IServiceFaultHandler.h"
            #include "ServiceComm/Base/include/DefaultServiceFaultHandler.h"
            #include "modules/Commons/include/EndCabInclude.h"       // <-- CAB
            
            namespace BTC {
            namespace PRINS {
            namespace Infrastructure {
            namespace ServiceHost {
            namespace Demo {
            namespace API {
            namespace ServiceAPI {			   
               // {384E277A-C343-4F37-B910-C2CE6B37FC8E}
               static const BTC::Commons::CoreExtras::UUID sKeyValueStoreTypeGuid = 
                  BTC::Commons::CoreExtras::UUID::ParseString("384E277A-C343-4F37-B910-C2CE6B37FC8E");
               
               BTC::Commons::CoreExtras::UUID IKeyValueStore::TYPE_GUID()
               {
                  return sKeyValueStoreTypeGuid;
               }
               
               
               void RegisterKeyValueStoreServiceFaults(BTC::ServiceComm::API::IServiceFaultHandlerManager& serviceFaultHandlerManager)
               {
                  
                  // most commonly used exception types
                  BTC::ServiceComm::Base::RegisterServiceFault<BTC::Commons::Core::InvalidArgumentException>(
                     serviceFaultHandlerManager, BTC::Commons::Core::String("BTC.Commons.Core.InvalidArgumentException"));
                  BTC::ServiceComm::Base::RegisterServiceFault<BTC::Commons::Core::UnsupportedOperationException>(
                     serviceFaultHandlerManager, BTC::Commons::Core::String("BTC.Commons.Core.UnsupportedOperationException"));
               }
            }}}}}}}
        ''')

        checkGenerators(TestData.basic, projectTypes, Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_PRINS_VCXPROJ, fileCount,
            contents)
    }

    @Test
    def void testBasicServiceApiCmake()
    {
        val fileCount = 7
        val projectTypes = new HashSet<ProjectType>(Arrays.asList(ProjectType.SERVICE_API))
        val directory = ArtifactNature.CPP.label + "Infrastructure/ServiceHost/Demo/API/ServiceAPI/"

        val contents = ImmutableMap.of(ArtifactNature.CPP.label + "conanfile.py", '''
            from conan_template import *
            
            class Conan(ConanTemplate):
                name = "Test"
                version= version_name("0.1.0-unreleased")
                url = "TODO"
                description = """
                TODO
                """
                
                build_requires = "CMakeMacros/0.3.latest@cab/testing"
                requires = ( 
                            ("BTC.CAB.Commons/1.9.latest@cab/testing"),
                            ("BTC.CAB.IoC/1.8.latest@cab/testing"),
                            ("BTC.CAB.Logging/1.8.latest@cab/testing"),
                            ("BTC.CAB.ServiceComm/0.12.latest@cab/testing")
                            )
                generators = "cmake"
                short_paths = True
        ''', ArtifactNature.CPP.label + "CMakeLists.txt", '''
            cmake_minimum_required(VERSION 3.4)
            
            project (Test CXX)
            
            include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
            conan_basic_setup()
            
            include(${CONAN_CMAKEMACROS_ROOT}/cmake/cab_globals.cmake)
            
            option(BUILD_TESTS "Build test" ON)
            
            include_directories(${CMAKE_SOURCE_DIR})
            set(CAB_INT_SOURCE_DIR ${CMAKE_SOURCE_DIR})
            set(CAB_EXT_SOURCE_DIR ${CMAKE_SOURCE_DIR}/../)
            
            include(${CMAKE_CURRENT_LIST_DIR}/Infrastructure/ServiceHost/Demo/API/ServiceAPI/build/make.cmakeset)           
        ''', directory + "build/CMakeLists.txt", '''
            # define target name
            set( TARGET BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI )
            
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
                  BTC.CAB.Commons.Core
                  BTC.CAB.Commons.CoreExtras
                  BTC.CAB.ServiceComm.API
                  BTC.CAB.ServiceComm.Base
              )
            
            # define list of dependent targets
            set( DEP_TARGETS
              ${LINK_TARGETS}
            )
            
            add_definitions( -DCAB_NO_LEGACY_EXPORT_MACROS )
            
            # define complete target description
            MY_TARGET( SHARED_LIB TARGET FILES DEP_TARGETS LINK_TARGETS WARNING_LEVEL_DEFAULT COMPILE_OPTS_DEFAULT )
            #ENABLE_WARNINGSASERRORS( "${TARGET}" )            
            
            set_target_properties("${TARGET}" PROPERTIES LINKER_LANGUAGE CXX)
        ''', directory + "build/make.cmakeset", '''
            cab_file_guard()            
            cab_add_project(${CMAKE_CURRENT_LIST_DIR})            
        ''')

        // TODO the dependencies on BTC.CAB.ServiceComm should be removed from the ServiceAPI. 
        // I am not sure where they come from.
        checkGenerators(TestData.basic, projectTypes, Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_CMAKE, fileCount, contents)
    }

    @Test
    def void testBasicDispatcherCmake()
    {
        val fileCount = 17
        val projectTypes = new HashSet<ProjectType>(
            #[ProjectType.SERVICE_API, ProjectType.PROTOBUF, ProjectType.DISPATCHER])
        val directory = ArtifactNature.CPP.label + "Infrastructure/ServiceHost/Demo/API/Dispatcher/"

        val contents = ImmutableMap.of(ArtifactNature.CPP.label + "conanfile.py", '''
            from conan_template import *
            
            class Conan(ConanTemplate):
                name = "Test"
                version= version_name("0.1.0-unreleased")
                url = "TODO"
                description = """
                TODO
                """
                
                build_requires = "CMakeMacros/0.3.latest@cab/testing"
                requires = ( 
                            ("BTC.CAB.Commons/1.9.latest@cab/testing"),
                            ("BTC.CAB.IoC/1.8.latest@cab/testing"),
                            ("BTC.CAB.Logging/1.8.latest@cab/testing"),
                            ("BTC.CAB.ServiceComm/0.12.latest@cab/testing")
                            )
                generators = "cmake"
                short_paths = True
        ''', ArtifactNature.CPP.label + "CMakeLists.txt", '''
            cmake_minimum_required(VERSION 3.4)
            
            project (Test CXX)
            
            include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
            conan_basic_setup()
            
            include(${CONAN_CMAKEMACROS_ROOT}/cmake/cab_globals.cmake)
            
            option(BUILD_TESTS "Build test" ON)
            
            include_directories(${CMAKE_SOURCE_DIR})
            set(CAB_INT_SOURCE_DIR ${CMAKE_SOURCE_DIR})
            set(CAB_EXT_SOURCE_DIR ${CMAKE_SOURCE_DIR}/../)
            
            include(${CMAKE_CURRENT_LIST_DIR}/Infrastructure/ServiceHost/Demo/API/Dispatcher/build/make.cmakeset)
            include(${CMAKE_CURRENT_LIST_DIR}/Infrastructure/ServiceHost/Demo/API/Protobuf/build/make.cmakeset)
            include(${CMAKE_CURRENT_LIST_DIR}/Infrastructure/ServiceHost/Demo/API/ServiceAPI/build/make.cmakeset)
            
        ''', directory + "build/CMakeLists.txt", '''
            # define target name
            set( TARGET BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Dispatcher )
            
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
                  BTC.CAB.Commons.Core
                  BTC.CAB.Commons.CoreExtras
                  BTC.CAB.Commons.CoreOS
                  BTC.CAB.Commons.FutureUtil
                  BTC.CAB.Logging.API
                  BTC.CAB.ServiceComm.API
                  BTC.CAB.ServiceComm.Base
                  BTC.CAB.ServiceComm.Commons
                  BTC.CAB.ServiceComm.ProtobufBase
                  BTC.CAB.ServiceComm.ProtobufUtil
                  BTC.CAB.ServiceComm.Util                  
                  libprotobuf
                  BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf 
                  BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI
              )
            
            # define list of dependent targets
            set( DEP_TARGETS
              ${LINK_TARGETS}
            )
            
            add_definitions( -DCAB_NO_LEGACY_EXPORT_MACROS )
            
            # define complete target description
            MY_TARGET( SHARED_LIB TARGET FILES DEP_TARGETS LINK_TARGETS WARNING_LEVEL_DEFAULT COMPILE_OPTS_DEFAULT )
            #ENABLE_WARNINGSASERRORS( "${TARGET}" )            
            
            set_target_properties("${TARGET}" PROPERTIES LINKER_LANGUAGE CXX)
        ''', directory + "build/make.cmakeset", '''
            cab_file_guard()            
            cab_add_project(${CMAKE_CURRENT_LIST_DIR})            
        ''')

        checkGenerators(TestData.basic, projectTypes, Main.OPTION_VALUE_CPP_PROJECT_SYSTEM_CMAKE, fileCount, contents)
    }

    def void checkGenerators(CharSequence input, Set<ProjectType> projectTypes, String projectSystem, int fileCount,
        Map<String, String> contents)
    {
        checkGenerators(input, new HashSet<ArtifactNature>(Arrays.asList(ArtifactNature.CPP)), projectTypes,
            projectSystem, fileCount, contents)
    }
}
