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

import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider
import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import com.google.inject.Inject
import java.util.Arrays
import java.util.HashSet
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static com.btc.serviceidl.tests.TestExtensions.*
import static org.junit.Assert.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class JavaGeneratorTest {
	@Inject extension ParseHelper<IDLSpecification>
	@Inject IGenerator2 underTest
	@Inject IGenerationSettingsProvider generationSettingsProvider

	@Test
	def void testBasicServiceApi() {
		val spec = TestData.basic.parse

		val fsa = new InMemoryFileSystemAccess
		val defaultGenerationSettingsProvider = generationSettingsProvider as DefaultGenerationSettingsProvider
		defaultGenerationSettingsProvider.projectTypes = new HashSet<ProjectType>(
			Arrays.asList(ProjectType.SERVICE_API))
		defaultGenerationSettingsProvider.languages = new HashSet<ArtifactNature>(Arrays.asList(ArtifactNature.JAVA))
		underTest.doGenerate(spec.eResource, fsa, new GeneratorContext)
		println(fsa.textFiles.keySet)
		assertEquals(3, fsa.textFiles.size) // TODO this includes the KeyValueStoreServiceFaultHandlerFactory, which should be generated to a different project, and not with these settings
		val directory = IFileSystemAccess::DEFAULT_OUTPUT +
			"java/btc.prins.infrastructure.servicehost.demo.api.keyvaluestore/src/main/java/com/btc/prins/infrastructure/servicehost/demo/api/keyvaluestore/serviceapi/"
		checkFile(fsa, directory + "KeyValueStore.java", '''
			package com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore.serviceapi;
			
			import java.util.UUID;
			
			public interface KeyValueStore {
			   UUID TypeGuid = UUID.fromString("384E277A-C343-4F37-B910-C2CE6B37FC8E");
			}
		''')

	}

}
