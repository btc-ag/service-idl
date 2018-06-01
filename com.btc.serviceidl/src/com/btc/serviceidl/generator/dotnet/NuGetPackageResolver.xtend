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
package com.btc.serviceidl.generator.dotnet

import java.util.HashSet

class NuGetPackageResolver
{
    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val version_mapper = #{
        "BTC.CAB.Commons" -> "1.8.7",
        "BTC.CAB.Logging" -> "1.7.2",
        "BTC.CAB.ServiceComm.NET" -> "0.6.0",
        "CommandLineParser" -> "1.9.71",
        "Google.ProtocolBuffers" -> "2.4.1.555",
        "log4net" -> "1.2.13",
        "NUnit" -> "2.6.4", // TODO specifying 2.6.5 here generates a dependency conflict, but I don't understand why 
        "Spring.Core" -> "1.3.2",
        "Common.Logging" -> "1.2.0"
    }

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val package_mapper = #{
        "BTC.CAB.Commons.Core.NET" -> #["BTC.CAB.Commons"],
        "BTC.CAB.Logging.API.NET" -> #["BTC.CAB.Logging"],
        "BTC.CAB.Logging.Log4NET" -> #["BTC.CAB.Logging"],
        "BTC.CAB.ServiceComm.NET.API" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.Base" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.Common" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.FaultHandling" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.ProtobufUtil" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.ServerRunner" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.SingleQueue.API" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.SingleQueue.Core" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ" -> #["BTC.CAB.ServiceComm.NET"],
        "BTC.CAB.ServiceComm.NET.Util" -> #["BTC.CAB.ServiceComm.NET"],
        "CommandLine" -> #["CommandLineParser"],
        "Google.ProtocolBuffers" -> #["Google.ProtocolBuffers"],
        "Google.ProtocolBuffers.Serialization" -> #["Google.ProtocolBuffers"],
        "log4net" -> #["log4net"],
        "NUnit.Framework" -> #["NUnit"],
        "Spring.Core" -> #["Spring.Core", "Common.Logging"] // TODO we must specify the dependency to Common.Logging as well, otherwise this yields inconsistent dependencies
    }

    val nuget_packages = new HashSet<NuGetPackage>

    def private static NuGetPackage resolvePackageInternal(String assemblyName)
    {
        val versions = validOrThrow(package_mapper.get(assemblyName), assemblyName, "package ID").map [
            new Pair(it, validOrThrow(version_mapper.get(it),
            it, "package version"))
        ].toList
        // TODO probably, this must be generalized, depending on the .NET version. but is this necessary at all? 
        // isn't the hint path filled by nuget or paket?
        // TODO the assembly path with paket doesn't contain the version number, but it probably does when nu-get is used
        val assemblyPath = versions.get(0).key + "\\lib\\net40\\" + assemblyName + ".dll"
        new NuGetPackage(versions, assemblyName, assemblyPath)

    }

    def private static <T> T validOrThrow(T value, String name, String info)
    {
        if (value === null)
            throw new IllegalArgumentException('''Inconsistent mapping! Not found: «info» of «name»!''')

        return value
    }

    def void resolvePackage(String assemblyName)
    {
        val nuget_package = resolvePackageInternal(assemblyName)
        nuget_packages.add(nuget_package)
    }

    def Iterable<NuGetPackage> getResolvedPackages()
    {
        nuget_packages
    }
}
