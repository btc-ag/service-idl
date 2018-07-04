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

import com.btc.serviceidl.generator.cpp.ExternalDependency
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(NONE)
class DependenciesGenerator
{
    val Iterable<ExternalDependency> externalDependencies

    def generate()
    {
        // TODO why are the #pragma directives encapsulated within CAB header guards? I can't imagine any effect they could have on the directives
        '''
            «FOR lib : externalDependencies.map[libraryName].sort
             BEFORE '''#include "modules/Commons/include/BeginCabInclude.h"  // CAB -->''' + System.lineSeparator 
             AFTER '''#include "modules/Commons/include/EndCabInclude.h"    // CAB <--''' + System.lineSeparator»
                #pragma comment(lib, "«lib».lib")
            «ENDFOR»
        '''

    }
}
