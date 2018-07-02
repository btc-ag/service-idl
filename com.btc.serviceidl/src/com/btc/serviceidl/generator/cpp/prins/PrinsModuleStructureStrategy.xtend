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
package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.HeaderType
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.core.runtime.Path

import static extension com.btc.serviceidl.generator.cpp.Util.*

class PrinsModuleStructureStrategy implements IModuleStructureStrategy
{

    // TODO it is not correct here to distinguish based on the ProjectType, the Codec is also in the PROTOBUF project!
    override getIncludeFilePath(Iterable<ModuleDeclaration> module_stack, ProjectType project_type, String baseName,
        HeaderType headerType)
    {
        getProjectDir(new ParameterBundle(module_stack, project_type)).append(headerType.includeDirectoryName).append(
            baseName).addFileExtension(headerType.fileExtension)
    }

    override getEncapsulationHeaders()
    {
        new Pair('#include "modules/Commons/include/BeginPrinsModulesInclude.h"',
            '#include "modules/Commons/include/EndPrinsModulesInclude.h"')
    }

    override createHeaderResolver()
    {
        PrinsHeaderResolver.create
    }

    override getProjectDir(ParameterBundle paramBundle)
    {
        new Path(ReferenceResolver.MODULES_HEADER_PATH_PREFIX).append(
            GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.FILE_SYSTEM))
    }

}
