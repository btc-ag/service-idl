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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(NONE)
class ModuleProjectGenerator extends BasicProjectGenerator
{
    val ModuleDeclaration module

    def generate()
    {
        if (projectTypes.contains(ProjectType.COMMON))
        {
            generateCommon(
                makeProjectSourcePath(module, ProjectType.COMMON, MavenArtifactType.MAIN_JAVA, PathType.FULL), module)

            generatePOM(module, ProjectType.COMMON)
        }

        if (projectTypes.contains(ProjectType.PROTOBUF))
        {
            generateProtobuf(
                makeProjectSourcePath(module, ProjectType.PROTOBUF, MavenArtifactType.MAIN_JAVA, PathType.FULL), module)

            generatePOM(module, ProjectType.PROTOBUF)
        }
    }
}
