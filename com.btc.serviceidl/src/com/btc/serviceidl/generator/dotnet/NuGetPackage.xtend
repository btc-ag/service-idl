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
 * \file       NuGetPackage.xtend
 * 
 * \brief      Representation of a NuGet package
 */

package com.btc.serviceidl.generator.dotnet

import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER, PUBLIC_SETTER) class NuGetPackage
{
   private var String assemblyName
   private var String assemblyPath
   private var String packageID
   private var String packageVersion

   override boolean equals(Object obj)
   {
      if (obj === null)
         return false

      if (!(obj instanceof NuGetPackage))
         return false

      if (obj == this)
         return true

      val nuget_package = obj as NuGetPackage
      return (assemblyName == nuget_package.assemblyName
         && assemblyPath == nuget_package.assemblyPath
         && packageID == nuget_package.packageID
         && packageVersion == nuget_package.packageVersion
      )
   }
   
}
