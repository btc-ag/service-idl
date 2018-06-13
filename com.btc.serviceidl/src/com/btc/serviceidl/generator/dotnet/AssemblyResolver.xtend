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
 * \file       AssemblyResolver.xtend
 * 
 * \brief      Resolution of .NET assemblies
 */
package com.btc.serviceidl.generator.dotnet

class AssemblyResolver
{
    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val assemblies_mapper = #{
        "BTC.CAB.ServiceComm.NET.API.DTO" -> "BTC.CAB.ServiceComm.NET.API",
        "CommandLine.Text" -> "CommandLine",
        "log4net.Config" -> "log4net",
        "Spring.Context" -> "Spring.Core",
        "Spring.Context.Support" -> "Spring.Core"
    }

    static def String resolveReference(String namespace)
    {
        val assembly = assemblies_mapper.get(namespace)

        return assembly ?: namespace
    }
}
