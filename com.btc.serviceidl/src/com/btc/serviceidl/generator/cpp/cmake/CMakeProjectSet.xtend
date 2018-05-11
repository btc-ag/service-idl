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

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.cpp.HeaderResolver.GroupedHeader
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import org.eclipse.xtend.lib.annotations.Data

class CMakeProjectSet implements IProjectSet
{
    @Data
    static class ProjectReference implements IProjectReference
    {
        val String projectName
    }

    override getVcxprojName(ParameterBundle builder)
    {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }

    override resolve(ParameterBundle paramBundle)
    {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }

    override resolveHeader(GroupedHeader header)
    {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }

}
