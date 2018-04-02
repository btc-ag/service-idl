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
 * \file       ProjectType.java
 * 
 * \brief      Type of generated project (API, Proxy, Dispatcher, etc.)
 */

package com.btc.cab.servicecomm.prodigd.generator.common;

import com.btc.cab.servicecomm.prodigd.generator.common.ArtifactNature;

public enum ProjectType
{
   SERVICE_API(Constants.PROJECT_NAME_SERVICE_API)
   , PROXY(Constants.PROJECT_NAME_PROXY)
   , DISPATCHER(Constants.PROJECT_NAME_DISPATCHER)
   , IMPL(Constants.PROJECT_NAME_IMPL)
   , PROTOBUF(Constants.PROJECT_NAME_PROTOBUF)
   , COMMON(Constants.PROJECT_NAME_COMMON)
   , TEST(Constants.PROJECT_NAME_TEST)
   , SERVER_RUNNER(Constants.PROJECT_NAME_SERVER_RUNNER)
   , CLIENT_CONSOLE(Constants.PROJECT_NAME_CLIENT_CONSOLE)
   , EXTERNAL_DB_IMPL(Constants.PROJECT_NAME_EXTERNAL_DB_IMPL)
   ;
   
   private final String name;
   
   ProjectType(String name)
   {
       this.name = name;
   }
   
   public final String getName() { return name; }
   
   private final String getFilePrefix(ArtifactNature artifact_nature)
   {
      if (name.equals(Constants.PROJECT_NAME_SERVICE_API))
      {
         if (artifact_nature == ArtifactNature.CPP
               || artifact_nature == ArtifactNature.DOTNET)
            return "I";
         else
            return "";
      }
      else if (name.equals(Constants.PROJECT_NAME_PROTOBUF)
            || name.equals(Constants.PROJECT_NAME_COMMON)
            || name.equals(Constants.PROJECT_NAME_TEST)
            || name.equals(Constants.PROJECT_NAME_SERVER_RUNNER)
            || name.equals(Constants.PROJECT_NAME_CLIENT_CONSOLE))
         return "";
      else
      {
         if (artifact_nature == ArtifactNature.CPP)
            return "C";
         else
            return "";
      }
   }
   
   private final String getFileSuffix()
   {
      if (name.equals(Constants.PROJECT_NAME_SERVICE_API) 
            || name.equals(Constants.PROJECT_NAME_PROTOBUF)
            || name.equals(Constants.PROJECT_NAME_COMMON)
            || name.equals(Constants.PROJECT_NAME_CLIENT_CONSOLE))
         return "";
      else if (name.equals(Constants.PROJECT_NAME_EXTERNAL_DB_IMPL))
         return Constants.PROJECT_NAME_IMPL; // special case: same as Impl
      else
         return name;
   }
   
   public final String getClassName(ArtifactNature artifact_nature, String basic_name)
   {
      return getFilePrefix(artifact_nature) + basic_name + getFileSuffix();
   }
   
   public final static ProjectType from(String name)
   {
      for (ProjectType p : ProjectType.values())
      {
         if (p.name.equalsIgnoreCase(name))
            return p;
      }

      throw new IllegalArgumentException("Enum value is unknown: " + name);
   }
}
