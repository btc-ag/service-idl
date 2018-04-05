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
 * \file       VSProjectInfo.xtend
 * 
 * \brief      Represents some Visual Studio related project information,
 *             e.g. project GUID, name, etc.
 */

package com.btc.serviceidl.generator.common

import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER) class VSProjectInfo
{
   private var String project_name
   private var String project_guid
   private var String project_path
   
   static class Builder
   {
      private var String project_name
      private var String project_guid
      private var String project_path
      
      def Builder setName(String s)
      {
         project_name = s
         return this
      }
      
      def Builder setGUID(String s)
      {
         project_guid = s
         return this
      }
      
      def Builder setPath(String s)
      {
         project_path = s
         return this
      }
      
      def VSProjectInfo build()
      {
         return new VSProjectInfo(this)
      }
   }
   
   private new(Builder builder)
   {
      project_name = builder.project_name
      project_guid = builder.project_guid
      project_path = builder.project_path
   }
}
