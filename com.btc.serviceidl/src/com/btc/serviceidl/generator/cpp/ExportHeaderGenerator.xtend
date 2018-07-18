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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class ExportHeaderGenerator
{
    val ParameterBundle paramBundle 
    
    def generateExportHeader()
    {
        val prefix = GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.EXPORT_HEADER)
        val prefixUpperCase = prefix.toUpperCase

        '''
            #ifndef «prefix»_EXPORT_H
            #define «prefix»_EXPORT_H
            
            #ifndef CAB_NO_LEGACY_EXPORT_MACROS
            #define CAB_NO_LEGACY_EXPORT_MACROS
            #endif
            
            #include <Commons/Core/include/Export.h>
            
            #ifdef «prefixUpperCase»_STATIC_DEFINE
            #  define «prefixUpperCase»_EXPORT
            #  define «prefixUpperCase»_EXTERN
            #  define «prefixUpperCase»_NO_EXPORT
            #else
            #  ifndef «prefixUpperCase»_EXPORT
            #    ifdef «prefix»_EXPORTS
                    /* We are building this library */
            #      define «prefixUpperCase»_EXPORT CAB_EXPORT
            #      define «prefixUpperCase»_EXTERN 
            #    else
                    /* We are using this library */
            #      define «prefixUpperCase»_EXPORT CAB_IMPORT
            #      define «prefixUpperCase»_EXTERN CAB_EXTERN
            #    endif
            #  endif
            
            #  ifndef «prefixUpperCase»_NO_EXPORT
            #    define «prefixUpperCase»_NO_EXPORT CAB_NO_EXPORT
            #  endif
            #endif
            
            #endif
            
        '''

    }
}
