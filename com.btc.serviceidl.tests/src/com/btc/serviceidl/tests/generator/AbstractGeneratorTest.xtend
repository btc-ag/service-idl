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
package com.btc.serviceidl.tests.generator

import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider
import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import java.util.HashSet
import java.util.Map
import java.util.Set
import javax.inject.Inject
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.util.ParseHelper

import static com.btc.serviceidl.tests.TestExtensions.*
import static org.junit.Assert.*

class AbstractGeneratorTest {
	@Inject extension ParseHelper<IDLSpecification>
	@Inject IGenerator2 underTest
	@Inject IGenerationSettingsProvider generationSettingsProvider

	def void checkGenerators(CharSequence input, Set<ArtifactNature> artifactNatures, Set<ProjectType> projectTypes, int fileCount,
		Map<String, String> contents) {
		val spec = input.parse
		val fsa = new InMemoryFileSystemAccess
		val defaultGenerationSettingsProvider = generationSettingsProvider as DefaultGenerationSettingsProvider
		defaultGenerationSettingsProvider.projectTypes = new HashSet<ProjectType>(projectTypes)
		defaultGenerationSettingsProvider.languages = new HashSet<ArtifactNature>(artifactNatures)
		underTest.doGenerate(spec.eResource, fsa, new GeneratorContext)
		println(fsa.textFiles.keySet)
		assertEquals(fileCount, fsa.textFiles.size)
		for (entry : contents.entrySet) {
			checkFile(fsa, entry.key, entry.value)
		}
	}

}
