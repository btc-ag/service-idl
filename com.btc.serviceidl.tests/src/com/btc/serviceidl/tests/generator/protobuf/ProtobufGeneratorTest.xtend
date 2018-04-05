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

import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider
import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
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
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.tests.testdata.TestData

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class ProtobufGeneratorTest {
	@Inject extension ParseHelper<IDLSpecification>
	@Inject IGenerator2 underTest
	@Inject IGenerationSettingsProvider generationSettingsProvider

	@Test
	def void testBasic() {
		val spec = TestData.basic.parse

		val fsa = new InMemoryFileSystemAccess
		val defaultGenerationSettingsProvider = generationSettingsProvider as DefaultGenerationSettingsProvider
		defaultGenerationSettingsProvider.projectTypes = new HashSet<ProjectType>(Arrays.asList(ProjectType.PROTOBUF))
		defaultGenerationSettingsProvider.languages = new HashSet<ArtifactNature>
		underTest.doGenerate(spec.eResource, fsa, new GeneratorContext)
		println(fsa.textFiles.keySet)
		assertEquals(3, fsa.textFiles.size)
		val protobufLocation = IFileSystemAccess::DEFAULT_OUTPUT +
			"cpp/Infrastructure/ServiceHost/Demo/API/Protobuf/gen/KeyValueStore.proto" // TODO why is this generated multiple times for each language?
		assertTrue(fsa.textFiles.containsKey(protobufLocation))

		println(fsa.textFiles.get(protobufLocation))

		checkFile(
			fsa,
			protobufLocation,
			'''
				syntax = "proto2";
				package BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf;
				message KeyValueStore_Request {
				}
				message KeyValueStore_Response {
				}
			'''
		)

	}
}
