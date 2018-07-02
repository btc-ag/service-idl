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
package com.btc.serviceidl.generator.cpp.cab

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.HeaderResolver
import com.btc.serviceidl.generator.cpp.HeaderType
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.TypeResolver
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.core.runtime.Path

import static extension com.btc.serviceidl.generator.cpp.HeaderResolver.Builder.*
import static extension com.btc.serviceidl.generator.cpp.Util.*

class CABModuleStructureStrategy implements IModuleStructureStrategy
{

    override getIncludeFilePath(Iterable<ModuleDeclaration> module_stack, ProjectType project_type, String baseName,
        HeaderType headerType)
    {
        getProjectDir(new ParameterBundle(module_stack, project_type)).append(headerType.includeDirectoryName).append(
            baseName).addFileExtension(headerType.fileExtension)
    }

    override getEncapsulationHeaders()
    {
        new Pair('#include <Commons/Core/include/BeginCABHeader.h>', '#include <Commons/Core/include/EndCABHeader.h>')
    }

    override createHeaderResolver()
    {
        new HeaderResolver.Builder().withBasicGroups.configureGroup(TypeResolver.TARGET_INCLUDE_GROUP, 10, "", "",
            false).configureGroup(TypeResolver.CAB_INCLUDE_GROUP, 20, "", "", true).configureGroup(
            TypeResolver.STL_INCLUDE_GROUP, 30, "", "", true).build
    }

    override getProjectDir(ParameterBundle paramBundle)
    {
        Path.fromPortableString(
            GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.FILE_SYSTEM))
    }
}
