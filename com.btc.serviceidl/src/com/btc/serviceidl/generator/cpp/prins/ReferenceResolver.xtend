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
/**
 * \file       ReferenceResolver.xtend
 * 
 * \brief      Resolution of C++ project references
 */
package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.HeaderResolver
import org.eclipse.core.runtime.IPath

import static extension com.btc.serviceidl.generator.common.GeneratorUtil.*

class ReferenceResolver
{
    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val vs_projects_mapper = #{
        "BTC.PRINS.Commons" ->
            new VSProjectInfo.Builder().setName("BTC.PRINS.Commons").setGUID("68E95AE7-BBFA-412B-8F65-026108BD8B28").
                setPath('''$(SolutionDir)\Commons\BTC.PRINS.Commons''').build,
        "BTC.PRINS.Commons.Utilities" ->
            new VSProjectInfo.Builder().setName("BTC.PRINS.Commons.Utilities").setGUID(
                "F34EA1D9-B1A7-47AD-B083-2AB267117D45").
                setPath('''$(SolutionDir)\Commons\Utilities\BTC.PRINS.Commons.Utilities''').build
    }

    public static val MODULES_HEADER_PATH_PREFIX = "modules"
    static val MODULES_HEADER_INCLUDE_SEGMENT = "include"
    static val MODULES_MODULE_NAME_PREFIX = "BTC.PRINS."

    static def VSProjectInfo getProjectReference(HeaderResolver.GroupedHeader header)
    {
        throw new IllegalArgumentException("Could not find project reference mapping for header: " + header.toString)
    }

    static def String modulesHeaderPathToModuleName(IPath headerPath)
    {
        if (headerPath.segment(0) != MODULES_HEADER_PATH_PREFIX)
            throw new IllegalArgumentException(
            '''Modules header path must start with '«MODULES_HEADER_PATH_PREFIX»': «headerPath»''')

        val includePosition = headerPath.segments.indexOf(MODULES_HEADER_INCLUDE_SEGMENT)
        if (includePosition == -1)
            throw new IllegalArgumentException(
            '''Modules header path must contain '«MODULES_HEADER_INCLUDE_SEGMENT»': «headerPath»''')

        MODULES_MODULE_NAME_PREFIX +
            headerPath.uptoSegment(includePosition).removeFirstSegments(1).toString.switchSeparator(
                TransformType.FILE_SYSTEM, TransformType.PACKAGE)
    }
}
