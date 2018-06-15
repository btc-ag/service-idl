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
package com.btc.serviceidl.tests.generator.protobuf

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.generator.AbstractGeneratorTest
import com.btc.serviceidl.tests.testdata.TestData
import com.google.common.collect.ImmutableMap
import java.util.Arrays
import java.util.HashSet
import java.util.Map
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class ProtobufGeneratorTest extends AbstractGeneratorTest
{
    @Test
    def void testBasic()
    {
        val fileCount = 6
        val contents = ImmutableMap.of(ArtifactNature.CPP.label +
            "modules/Infrastructure/ServiceHost/Demo/API/Protobuf/gen/KeyValueStore.proto", '''
            syntax = "proto2";
            package BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf;
            message KeyValueStoreRequest {
            }
            message KeyValueStoreResponse {
            }
        ''')

        checkGenerators(TestData.basic, fileCount, contents)
    }

    @Test
    def void testFull()
    {
        val fileCount = 8

        // TODO the exception message type is probably not used anywhere, and should be removed (if there were custom attributes, something like this might be required) 
        val contents = ImmutableMap.of(ArtifactNature.CPP.label +
            "modules/Infrastructure/ServiceHost/Demo/API/Protobuf/gen/Types.proto", '''
            syntax = "proto2";
            package BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf;
            
            message EntryType
            {
               required bytes id = 1;
               required string name = 2;
            }
            
            message MyException
            {
            }
        ''', ArtifactNature.CPP.label + "modules/Infrastructure/ServiceHost/Demo/API/Protobuf/gen/DemoX.proto", '''
            syntax = "proto2";
            package BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf;
            import "modules/Infrastructure/ServiceHost/Demo/API/Protobuf/gen/Types.proto";
            
            message DemoXRequest
            {
               message AddEntriesRequest
               {
                  repeated BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf.EntryType entries = 1;
               }
            
               optional AddEntriesRequest add_entries_request = 1;
            }
            
            message DemoXResponse
            {
               message AddEntriesResponse
               {
               }
            
               optional AddEntriesResponse add_entries_response = 1;
            }
        ''')

        checkGenerators(TestData.full, fileCount, contents)
    }

    def void checkGenerators(CharSequence input, int fileCount, Map<String, String> contents)
    {
        checkGenerators(input, #[ArtifactNature.CPP].toSet,
            new HashSet<ProjectType>(Arrays.asList(ProjectType.PROTOBUF)), fileCount, contents)
    }
}
