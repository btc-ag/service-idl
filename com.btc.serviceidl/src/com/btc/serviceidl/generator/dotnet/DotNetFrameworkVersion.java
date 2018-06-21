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
 * \file       DotNetFrameworkVersion.java
 *
 * \brief      Enum to represent a specific version of the Microsoft .NET framework
 */

package com.btc.serviceidl.generator.dotnet;

public enum DotNetFrameworkVersion {
    NET46
    ;
    
    @Override
    public String toString()
    {
       switch(this)
       {
       case NET46:
          return "4.6";
       default:
          throw new UnsupportedOperationException("Method is not implemented for enum value " + this.name());
       }
    }
}
