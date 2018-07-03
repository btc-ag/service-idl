/**
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import java.util.HashSet
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data

@Accessors(PACKAGE_GETTER)
class CMakeProjectSet implements IProjectSet
{
    val projects = new HashSet<ParameterBundle>
    
    @Data
    static class ProjectReference implements IProjectReference
    {
        val String projectName
    }

    override getVcxprojName(ParameterBundle paramBundle)
    {
        GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.PACKAGE)
    }

    override resolve(ParameterBundle paramBundle)
    {
        projects.add(paramBundle)
        new ProjectReference(getVcxprojName(paramBundle))        
    }

}
