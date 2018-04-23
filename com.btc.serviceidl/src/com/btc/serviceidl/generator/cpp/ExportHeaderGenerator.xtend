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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class ExportHeaderGenerator
{
    private val ParameterBundle param_bundle 
    
    def generateExportHeader()
    {
        val prefix = GeneratorUtil.transform(param_bundle, TransformType.EXPORT_HEADER).toUpperCase

        '''
            #ifndef «prefix»_EXPORT_H
            #define «prefix»_EXPORT_H
            
            #ifndef CAB_NO_LEGACY_EXPORT_MACROS
            #define CAB_NO_LEGACY_EXPORT_MACROS
            #endif
            
            #include <modules/Commons/include/Export.h>
            
            #ifdef «prefix»_STATIC_DEFINE
            #  define «prefix»_EXPORT
            #  define «prefix»_EXTERN
            #  define «prefix»_NO_EXPORT
            #else
            #  ifndef «prefix»_EXPORT
            #    ifdef «prefix»_EXPORTS
                    /* We are building this library */
            #      define «prefix»_EXPORT CAB_EXPORT
            #      define «prefix»_EXTERN 
            #    else
                    /* We are using this library */
            #      define «prefix»_EXPORT CAB_IMPORT
            #      define «prefix»_EXTERN CAB_EXTERN
            #    endif
            #  endif
            
            #  ifndef «prefix»_NO_EXPORT
            #    define «prefix»_NO_EXPORT CAB_NO_EXPORT
            #  endif
            #endif
            
            #endif
            
        '''

    }
}
