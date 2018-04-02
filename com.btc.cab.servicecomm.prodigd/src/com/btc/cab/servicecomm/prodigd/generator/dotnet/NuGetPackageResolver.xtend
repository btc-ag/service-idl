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
 * \file       NuGetPackageResolver.xtend
 * 
 * \brief      Resolution of NuGet packages
 */

package com.btc.cab.servicecomm.prodigd.generator.dotnet

class NuGetPackageResolver
{
   // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
   private static val version_mapper = #{
      "CommandLineParser"                                -> "1.9.71"
      , "Google.ProtocolBuffers"                         -> "2.4.1.555"
   }
   
   // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
   private static val package_mapper = #{
      "CommandLine"                                      -> "CommandLineParser"
      , "Google.ProtocolBuffers"                         -> "Google.ProtocolBuffers"
      , "Google.ProtocolBuffers.Serialization"           -> "Google.ProtocolBuffers"
   }
   
   // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
   private static val assembly_mapper = #{
      "CommandLine"                                      -> '''CommandLineParser.1.9.71\lib\net40\CommandLine.dll'''
      , "Google.ProtocolBuffers"                         -> '''Google.ProtocolBuffers.2.4.1.555\lib\net40\Google.ProtocolBuffers.dll'''
      , "Google.ProtocolBuffers.Serialization"           -> '''Google.ProtocolBuffers.2.4.1.555\lib\net40\Google.ProtocolBuffers.Serialization.dll'''
   }
   
   def static NuGetPackage resolvePackage(String name)
   {
      val nuget_package = new NuGetPackage
      
      nuget_package.assemblyName = name
      nuget_package.assemblyPath = validOrThrow(assembly_mapper.get(nuget_package.assemblyName), nuget_package.assemblyName, "assembly path")
      nuget_package.packageID = validOrThrow(package_mapper.get(nuget_package.assemblyName), nuget_package.assemblyName, "package ID")
      nuget_package.packageVersion = validOrThrow(version_mapper.get(nuget_package.packageID), nuget_package.packageID, "package version")
      
      return nuget_package 
   }
   
   def private static String validOrThrow(String value, String name, String info)
   {
      if (value === null)
         throw new IllegalArgumentException('''Inconsistent mapping! Not found: «info» of «name»!''' )
      
      return value
   }
}
