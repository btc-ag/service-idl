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

import org.eclipse.core.runtime.IPath

class LibResolver
{
    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val cab_lib_mapper = #{
        "Commons/Core" -> "BTC.CAB.Commons.Core.lib",
        "Commons/CoreExtras" -> "BTC.CAB.Commons.CoreExtras.lib",
        "Commons/CoreStd" -> "BTC.CAB.Commons.CoreStd.lib",
        "Commons/CoreYacl" -> "BTC.CAB.Commons.CoreYacl.lib",
        "Commons/FutureUtil" -> "BTC.CAB.Commons.FutureUtil.lib",
        "Commons/TestFW/API/CPP" -> "BTC.CAB.Commons.TestFW.API.CPP.lib",
        "Logging/API" -> "BTC.CAB.Logging.API.lib",
        "Performance/CommonsTestSupport" -> "BTC.CAB.Performance.CommonsTestSupport.lib",
        "ServiceComm/API" -> "BTC.CAB.ServiceComm.API.lib",
        "ServiceComm/Base" -> "BTC.CAB.ServiceComm.Base.lib",
        "ServiceComm/Commons" -> "BTC.CAB.ServiceComm.Commons.lib",
        "ServiceComm/CommonsTestSupport" -> "BTC.CAB.ServiceComm.CommonsTestSupport.lib",
        "ServiceComm/CommonsUtil" -> "BTC.CAB.ServiceComm.CommonsUtil.lib",
        "ServiceComm/Default" -> "BTC.CAB.ServiceComm.Default.lib",
        "ServiceComm/PerformanceBase" -> "BTC.CAB.ServiceComm.PerformanceBase.lib",
        "ServiceComm/ProtobufBase" -> "BTC.CAB.ServiceComm.ProtobufBase.lib",
        "ServiceComm/ProtobufUtil" -> "BTC.CAB.ServiceComm.ProtobufUtil.lib",
        "ServiceComm.SQ/ZeroMQ" -> "BTC.CAB.ServiceComm.SQ.ZeroMQ.lib",
        "ServiceComm.SQ/ZeroMQTestSupport" -> "BTC.CAB.ServiceComm.SQ.ZeroMQTestSupport.lib",
        "ServiceComm/TestBase" -> "BTC.CAB.ServiceComm.TestBase.lib",
        "ServiceComm/Util" -> "BTC.CAB.ServiceComm.Util.lib"
    }

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val cab_additional_dependencies = #{
        "Performance/CommonsTestSupport/include/TestLoggerFactory.h" -> #["BTC.CAB.Logging.API.lib"],
        "ServiceComm/API/include/IClientEndpoint.h" ->
            #["BTC.CAB.ServiceComm.ProtobufUtil.lib", "BTC.CAB.ServiceComm.Commons.lib",
                "BTC.CAB.ServiceComm.CommonsUtil.lib", "BTC.CAB.Commons.FutureUtil.lib"],
        "ServiceComm/Default/include/BaseMessageTypes.h" ->
            #["BTC.CAB.ServiceComm.API.lib", "BTC.CAB.ServiceComm.Protobuf.Common.lib"],
        "ServiceComm/PerformanceBase/include/ServerBase.h" ->
            #["BTC.CAB.IoC.Container.lib", "BTC.CAB.Logging.Default.lib", "BTC.CAB.ServiceComm.TestBase.lib",
                "BTC.CAB.Performance.CommonsUtil.lib", "BTC.CAB.Performance.Framework.lib",
                "BTC.CAB.Performance.Base.lib"],
        "ServiceComm/ProtobufBase/include/AProtobufServiceDispatcherBase.h" ->
            #["BTC.CAB.ServiceComm.Base.lib", "BTC.CAB.Commons.CoreOS.lib"],
        "ServiceComm/ProtobufBase/include/AProtobufServiceProxyBase.h" ->
            #["BTC.CAB.ServiceComm.Base.lib", "BTC.CAB.Commons.CoreOS.lib", "BTC.CAB.ServiceComm.Commons.lib"],
        "ServiceComm/ProtobufUtil/include/ProtobufMessageDecoder.h" ->
            #["BTC.CAB.ServiceComm.Commons.lib", "BTC.CAB.ServiceComm.Util.lib"],
        "ServiceComm/Util/include/DispatcherAutoRegistration.h" ->
            #["BTC.CAB.Commons.CoreExtras.lib", "BTC.CAB.Commons.FutureUtil.lib", "BTC.CAB.ServiceComm.API.lib",
                "BTC.CAB.ServiceComm.Commons.lib", "BTC.CAB.Commons.CoreOS.lib"],
        "ServiceComm.SQ/ZeroMQTestSupport/include/CZeroMQTestConnection.h" ->
            #["BTC.CAB.ServiceComm.SQ.API.lib", "BTC.CAB.ServiceComm.SQ.ZeroMQ.lib",
                "BTC.CAB.ServiceComm.SQ.Default.lib", "BTC.CAB.ServiceComm.SQ.ImportAPI.lib"]
    }

    static def Iterable<String> getCABLibs(IPath header_file)
    {
        // remove last 2 component (which are the "include" directory name and the *.h file name)
        var key = header_file.removeLastSegments(2)

        if (cab_lib_mapper.containsKey(key.toString))
        {
            return #[#[cab_lib_mapper.get(key.toString)],
                cab_additional_dependencies.getOrDefault(header_file, #[])].flatten
        }

        throw new IllegalArgumentException("Could not find CAB *.lib mapping: " + header_file)
    }
}
