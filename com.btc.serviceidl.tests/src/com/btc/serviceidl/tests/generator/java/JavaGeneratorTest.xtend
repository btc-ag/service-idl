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
package com.btc.serviceidl.tests.generator.java

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.generator.AbstractGeneratorTest
import com.btc.serviceidl.tests.testdata.TestData
import com.google.common.collect.ImmutableMap
import java.util.Arrays
import java.util.HashSet
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Map
import java.util.Set
import com.btc.serviceidl.generator.common.ArtifactNature

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class JavaGeneratorTest extends AbstractGeneratorTest
{
    @Test
    def void testBasicServiceApi()
    {
        val fileCount = 3 // TODO this includes the KeyValueStoreServiceFaultHandlerFactory, which should be generated to a different project, and not with these settings
        val projectTypes = new HashSet<ProjectType>(Arrays.asList(ProjectType.SERVICE_API))
        val directory = IFileSystemAccess::DEFAULT_OUTPUT +
            "java/btc.prins.infrastructure.servicehost.demo.api.keyvaluestore/src/main/java/com/btc/prins/infrastructure/servicehost/demo/api/keyvaluestore/serviceapi/"
        val contents = ImmutableMap.of(directory + "KeyValueStore.java", '''
            package com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore.serviceapi;
            
            import java.util.UUID;
            
            public interface KeyValueStore {
                UUID TypeGuid = UUID.fromString("384E277A-C343-4F37-B910-C2CE6B37FC8E");
            }
        ''')

        checkGenerators(TestData.basic, projectTypes, fileCount, contents)
    }

    def void checkGenerators(CharSequence input, Set<ProjectType> projectTypes, int fileCount,
        Map<String, String> contents)
    {
        checkGenerators(input, new HashSet<ArtifactNature>(Arrays.asList(ArtifactNature.JAVA)), projectTypes, fileCount,
            contents)
    }
}
