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
package com.btc.serviceidl.generator

import java.util.HashSet
import com.btc.serviceidl.generator.common.ArtifactNature
import java.util.Arrays
import com.btc.serviceidl.generator.common.ProjectType

class DefaultGenerationSettingsProvider implements IGenerationSettingsProvider {

	public var languages = new HashSet<ArtifactNature>(
		Arrays.asList(ArtifactNature.CPP, ArtifactNature.JAVA, ArtifactNature.DOTNET));
	public var projectTypes = new HashSet<ProjectType>(
		Arrays.asList(ProjectType.SERVICE_API, ProjectType.PROXY, ProjectType.DISPATCHER, ProjectType.IMPL,
			ProjectType.PROTOBUF, ProjectType.COMMON, ProjectType.TEST, ProjectType.SERVER_RUNNER,
			ProjectType.CLIENT_CONSOLE, ProjectType.EXTERNAL_DB_IMPL));

	override getLanguages() {
		return languages;
	}

	override getProjectTypes() {
		return projectTypes;
	}

}
