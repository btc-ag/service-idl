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
 * \file       LibResolver.xtend
 * 
 * \brief      Resolution of C++ library files
 */
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.ITargetVersionProvider
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(NONE)
class LibResolver
{
    val ITargetVersionProvider targetVersionProvider

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val cabLibMapper = #{
        "Commons/Core" -> "BTC.CAB.Commons.Core",
        "Commons/CoreExtras" -> "BTC.CAB.Commons.CoreExtras",
        "Commons/CoreStd" -> "BTC.CAB.Commons.CoreStd",
        "Commons/CoreYacl" -> "BTC.CAB.Commons.CoreYacl",
        "Commons/FutureUtil" -> "BTC.CAB.Commons.FutureUtil",
        "Commons/TestFW/API/CPP" -> "BTC.CAB.Commons.TestFW.API.CPP",
        "Logging/API" -> "BTC.CAB.Logging.API",
        "Performance/CommonsTestSupport" -> "BTC.CAB.Performance.CommonsTestSupport",
        "ServiceComm/API" -> "BTC.CAB.ServiceComm.API",
        "ServiceComm/Base" -> "BTC.CAB.ServiceComm.Base",
        "ServiceComm/Commons" -> "BTC.CAB.ServiceComm.Commons",
        "ServiceComm/CommonsTestSupport" -> "BTC.CAB.ServiceComm.CommonsTestSupport",
        "ServiceComm/CommonsUtil" -> "BTC.CAB.ServiceComm.CommonsUtil",
        "ServiceComm/Default" -> "BTC.CAB.ServiceComm.Default",
        "ServiceComm/PerformanceBase" -> "BTC.CAB.ServiceComm.PerformanceBase",
        "ServiceComm/ProtobufBase" -> "BTC.CAB.ServiceComm.ProtobufBase",
        "ServiceComm/ProtobufUtil" -> "BTC.CAB.ServiceComm.ProtobufUtil",
        "ServiceComm.SQ/ZeroMQ" -> "BTC.CAB.ServiceComm.SQ.ZeroMQ",
        "ServiceComm.SQ/ZeroMQTestSupport" -> "BTC.CAB.ServiceComm.SQ.ZeroMQTestSupport",
        "ServiceComm/TestBase" -> "BTC.CAB.ServiceComm.TestBase",
        "ServiceComm/Util" -> "BTC.CAB.ServiceComm.Util"
    }

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    // TODO for ServiceComm 0.12, these additional dependencies should no longer be necessary
    static val cabAdditionalDependencies = #{
        "Performance/CommonsTestSupport/include/TestLoggerFactory.h" -> #["BTC.CAB.Logging.API"],
        "ServiceComm/API/include/IClientEndpoint.h" ->
            #["BTC.CAB.ServiceComm.ProtobufUtil", "BTC.CAB.ServiceComm.Commons", "BTC.CAB.ServiceComm.CommonsUtil",
                "BTC.CAB.Commons.FutureUtil"],
        "ServiceComm/Default/include/BaseMessageTypes.h" ->
            #["BTC.CAB.ServiceComm.API", "BTC.CAB.ServiceComm.Protobuf.Common"],
        "ServiceComm/PerformanceBase/include/ServerBase.h" ->
            #["BTC.CAB.IoC.Container", "BTC.CAB.Logging.Default", "BTC.CAB.ServiceComm.TestBase",
                "BTC.CAB.Performance.CommonsUtil", "BTC.CAB.Performance.Framework", "BTC.CAB.Performance.Base"],
        "ServiceComm/ProtobufBase/include/AProtobufServiceDispatcherBase.h" ->
            #["BTC.CAB.ServiceComm.Base", "BTC.CAB.Commons.CoreOS"],
        "ServiceComm/ProtobufBase/include/AProtobufServiceProxyBase.h" ->
            #["BTC.CAB.ServiceComm.Base", "BTC.CAB.Commons.CoreOS", "BTC.CAB.ServiceComm.Commons"],
        "ServiceComm/ProtobufUtil/include/ProtobufMessageDecoder.h" ->
            #["BTC.CAB.ServiceComm.Commons", "BTC.CAB.ServiceComm.Util"],
        "ServiceComm/Util/include/DispatcherAutoRegistration.h" ->
            #["BTC.CAB.Commons.CoreExtras", "BTC.CAB.Commons.FutureUtil", "BTC.CAB.ServiceComm.API",
                "BTC.CAB.ServiceComm.Commons", "BTC.CAB.Commons.CoreOS"],
        "ServiceComm.SQ/ZeroMQTestSupport/include/CZeroMQTestConnection.h" ->
            #["BTC.CAB.ServiceComm.SQ.API", "BTC.CAB.ServiceComm.SQ.ZeroMQ", "BTC.CAB.ServiceComm.SQ.Default",
                "BTC.CAB.ServiceComm.SQ.ImportAPI", "BTC.CAB.ServiceComm.SQ.TestBase"]
    }

    def Iterable<ExternalDependency> getCABLibs(IPath headerFile)
    {
        // remove last 2 component (which are the "include" directory name and the *.h file name)
        val key = headerFile.removeLastSegments(2).toPortableString

        if (cabLibMapper.containsKey(key))
        {
            return #[#[cabLibMapper.get(key)], getAdditionalDependencies(headerFile)].flatten.map [
                new ExternalDependency(it)
            ]

        }

        throw new IllegalArgumentException("Could not find CAB library mapping: " + headerFile)
    }

    def getAdditionalDependencies(IPath headerFile)
    {
        val serviceCommTargetVersion = ServiceCommVersion.get(targetVersionProvider.getTargetVersion(
            CppConstants.SERVICECOMM_VERSION_KIND))

        if (serviceCommTargetVersion == ServiceCommVersion.V0_10 ||
            serviceCommTargetVersion == ServiceCommVersion.V0_11)
            cabAdditionalDependencies.getOrDefault(headerFile.toPortableString, #[])
        else
            #[]
    }

}
