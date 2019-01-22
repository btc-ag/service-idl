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
package com.btc.serviceidl.generator;

import java.util.Set;

import com.btc.serviceidl.generator.common.ArtifactNature;
import com.btc.serviceidl.generator.common.PackageInfo;
import com.btc.serviceidl.generator.common.ProjectType;
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy;
import com.btc.serviceidl.generator.cpp.IProjectSetFactory;

public interface IGenerationSettings extends ITargetVersionProvider {
    Set<ArtifactNature> getLanguages();

    Set<ProjectType> getProjectTypes();

    IProjectSetFactory getProjectSetFactory();

    IModuleStructureStrategy getModuleStructureStrategy();

    Maturity getMaturity();

    Set<PackageInfo> getDependencies();

    boolean hasGeneratorOption(String key);

    String getGeneratorOption(String key);
}
