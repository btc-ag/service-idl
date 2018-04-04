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

package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.VSProjectInfo
import com.btc.serviceidl.util.Constants

class ReferenceResolver
{
   // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
   private static val vs_projects_mapper = #{
      "BTC.PRINS.Commons"
         -> new VSProjectInfo.Builder()
            .setName("BTC.PRINS.Commons")
            .setGUID("68E95AE7-BBFA-412B-8F65-026108BD8B28")
            .setPath('''$(SolutionDir)\Commons\BTC.PRINS.Commons''')
            .build
      ,"BTC.PRINS.Commons.Utilities"
         -> new VSProjectInfo.Builder()
            .setName("BTC.PRINS.Commons.Utilities")
            .setGUID("F34EA1D9-B1A7-47AD-B083-2AB267117D45")
            .setPath('''$(SolutionDir)\Commons\Utilities\BTC.PRINS.Commons.Utilities''')
            .build
   }
   
   def static VSProjectInfo getProjectReference(String class_name)
   {
      // remove last component (which is the class name), leave only namespace
      var key = class_name.substring(0, class_name.lastIndexOf(Constants.SEPARATOR_NAMESPACE))
      key = key.replaceAll(Constants.SEPARATOR_NAMESPACE, Constants.SEPARATOR_PACKAGE)
      
      val project_reference = vs_projects_mapper.get(key)
      
      if (project_reference !== null) return project_reference
      
      throw new IllegalArgumentException("Could not find project reference mapping: " + key)
   }
}
