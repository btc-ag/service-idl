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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ProjectType
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class DependenciesGenerator extends BasicCppGenerator
{
    def generate()
    {
        // proxy and dispatcher include a *.impl.h file from the Protobuf project
        // for type-conversion routines; therefore some hidden dependencies
        // exist, which are explicitly resolved here
        if (paramBundle.projectType == ProjectType.PROXY || paramBundle.projectType == ProjectType.DISPATCHER)
        {
            resolveClass("BTC::Commons::FutureUtil::InsertableTraits")
        }

        '''
            «FOR lib : cab_libs.sort BEFORE '''#include "modules/Commons/include/BeginCabInclude.h"  // CAB -->''' + System.lineSeparator AFTER '''#include "modules/Commons/include/EndCabInclude.h"    // CAB <--''' + System.lineSeparator»
                #pragma comment(lib, "«lib»")
            «ENDFOR»
            
            «IF paramBundle.projectType == ProjectType.PROTOBUF
         || paramBundle.projectType == ProjectType.DISPATCHER
         || paramBundle.projectType == ProjectType.PROXY
         || paramBundle.projectType == ProjectType.SERVER_RUNNER
         »
                #pragma comment(lib, "libprotobuf.lib")
            «ENDIF»
        '''

    }
}
