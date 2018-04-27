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
 * \file       HeaderResolver.xtend
 * 
 * \brief      Resolution of C++ header files
 */
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.TypeResolver.IncludeGroup
import java.util.ArrayList
import java.util.Arrays
import java.util.HashMap
import java.util.Map
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.Path
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data

class HeaderResolver
{
    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    private static val stl_header_mapper = #{
        "assert" -> "cassert",
        "int8_t" -> "cstdint",
        "int16_t" -> "cstdint",
        "int32_t" -> "cstdint",
        "int64_t" -> "cstdint",
        "std::array" -> "array",
        "std::begin" -> "iterator",
        "std::bind" -> "functional",
        "std::call_once" -> "mutex",
        "std::copy" -> "algorithm",
        "std::end" -> "iterator",
        "std::find_if" -> "algorithm",
        "std::for_each" -> "algorithm",
        "std::function" -> "functional",
        "std::make_shared" -> "memory",
        "std::map" -> "map",
        "std::memcpy" -> "cstring",
        "std::move" -> "utility",
        "std::once_flag" -> "mutex",
        "std::pair" -> "utility",
        "std::shared_ptr" -> "memory",
        "std::string" -> "string",
        "std::tuple" -> "tuple",
        "std::unique_ptr" -> "memory",
        "std::vector" -> "vector"
    }

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    private static val cab_header_mapper = #{
        "BTC::Commons::Core::AutoPtr" -> "Commons/Core/include/AutoPtr.h",
        "BTC::Commons::Core::BlockStackTraceSettings" -> "Commons/Core/include/Exception.h",
        "BTC::Commons::Core::Context" -> "Commons/Core/include/Context.h",
        "BTC::Commons::Core::CreateAuto" -> "Commons/Core/include/AutoPtr.h",
        "BTC::Commons::Core::CreateUnique" -> "Commons/Core/include/UniquePtr.h",
        "BTC::Commons::Core::DelException" -> "Commons/Core/include/Exception.h",
        "BTC::Commons::Core::Disposable" -> "Commons/Core/include/Disposable.h",
        "BTC::Commons::Core::Exception" -> "Commons/Core/include/Exception.h",
        "BTC::Commons::Core::ForwardConstIterator" -> "Commons/Core/include/Iterator.h",
        "BTC::Commons::Core::InvalidArgumentException" -> "Commons/Core/include/InvalidArgumentException.h",
        "BTC::Commons::Core::MakeAuto" -> "Commons/Core/include/AutoPtr.h",
        "BTC::Commons::Core::NotImplementedException" -> "Commons/Core/include/NotImplementedException.h",
        "BTC::Commons::Core::Object" -> "Commons/Core/include/Object.h",
        "BTC::Commons::Core::String" -> "Commons/Core/include/String.h",
        "BTC::Commons::Core::UInt8" -> "Commons/Core/include/StdTypes.h",
        "BTC::Commons::Core::UInt16" -> "Commons/Core/include/StdTypes.h",
        "BTC::Commons::Core::UInt32" -> "Commons/Core/include/StdTypes.h",
        "BTC::Commons::Core::UniquePtr" -> "Commons/Core/include/UniquePtr.h",
        "BTC::Commons::Core::UnsupportedOperationException" -> "Commons/Core/include/UnsupportedOperationException.h",
        "BTC::Commons::Core::Vector" -> "Commons/Core/include/Vector.h",
        "BTC::Commons::CoreExtras::CDefaultObservable" -> "Commons/CoreExtras/include/CDefaultObservable.h",
        "BTC::Commons::CoreExtras::FailableHandle" -> "Commons/CoreExtras/include/FailableHandle.h",
        "BTC::Commons::CoreExtras::Future" -> "Commons/CoreExtras/include/Future.h",
        "BTC::Commons::CoreExtras::InsertableTraits" -> "Commons/CoreExtras/include/IAsyncInsertable.h",
        "BTC::Commons::CoreExtras::IObservableRegistration" -> "Commons/CoreExtras/include/IObservableRegistration.h",
        "BTC::Commons::CoreExtras::IObserver" -> "Commons/CoreExtras/include/IObserver.h",
        "BTC::Commons::CoreExtras::Optional" -> "Commons/CoreExtras/include/Optional.h",
        "BTC::Commons::CoreExtras::MakeOwningForwardConstIterator" ->
            "Commons/CoreExtras/include/OwningForwardConstIterator.h",
        "BTC::Commons::CoreExtras::ReflectedClass" -> "Commons/CoreExtras/include/ReflectedClass.h",
        "BTC::Commons::CoreExtras::StringBuilder" -> "Commons/CoreExtras/include/StringBuilder.h",
        "BTC::Commons::CoreExtras::UUID" -> "Commons/CoreExtras/include/UUID.h",
        "BTC::Commons::CoreYacl::Context" -> "Commons/CoreYacl/include/Context.h",
        "BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable" -> "Commons/FutureUtil/include/AsyncInsertable.h",
        "BTC::Commons::FutureUtil::GetOrCreateDefaultInsertable" -> "Commons/FutureUtil/include/AsyncInsertable.h",
        "BTC::Commons::FutureUtil::InsertableTraits" -> "Commons/FutureUtil/include/AsyncInsertable.h",
        "BTC::Logging::API::Logger" -> "Logging/API/include/Logger.h",
        "BTC::Logging::API::LoggerAware" -> "Logging/API/include/LoggerAware.h",
        "BTC::Logging::API::LoggerFactory" -> "Logging/API/include/LoggerFactory.h",
        "BTC::Performance::CommonsTestSupport::GetTestLoggerFactory" ->
            "Performance/CommonsTestSupport/include/TestLoggerFactory.h",
        "BTC::ServiceComm::API::EventKind" -> "ServiceComm/API/include/IEventRegistry.h",
        "BTC::ServiceComm::API::IClientEndpoint" -> "ServiceComm/API/include/IClientEndpoint.h",
        "BTC::ServiceComm::API::IEventSubscriberManager" -> "ServiceComm/API/include/IEventRegistry.h",
        "BTC::ServiceComm::API::InvalidMessageReceivedException" -> "ServiceComm/API/include/ServiceHostException.h",
        "BTC::ServiceComm::API::InvalidRequestReceivedException" -> "ServiceComm/API/include/ServiceHostException.h",
        "BTC::ServiceComm::API::IServerEndpoint" -> "ServiceComm/API/include/IServerEndpoint.h",
        "BTC::ServiceComm::API::IServiceFaultHandlerManager" -> "ServiceComm/API/include/IServiceFaultHandler.h",
        "BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory" -> "ServiceComm/API/include/IServiceFaultHandler.h",
        "BTC::ServiceComm::Base::RegisterServiceFault" -> "ServiceComm/Base/include/DefaultServiceFaultHandler.h",
        "BTC::ServiceComm::Commons::CMessage" -> "ServiceComm/Commons/include/CMessage.h",
        "BTC::ServiceComm::Commons::CMessagePartPool" -> "ServiceComm/Commons/include/MessagePools.h",
        "BTC::ServiceComm::Commons::ConstMessagePartPtr" -> "ServiceComm/Commons/include/IMessagePart.h",
        "BTC::ServiceComm::Commons::ConstSharedMessageSharedPtr" -> "ServiceComm/Commons/include/CSharedMessage.h",
        "BTC::ServiceComm::Commons::IMessagePartPool" -> "ServiceComm/Commons/include/IMessagePartPool.h",
        "BTC::ServiceComm::Commons::MessageMovingPtr" -> "ServiceComm/Commons/include/CMessage.h",
        "BTC::ServiceComm::Commons::MessagePtr" -> "ServiceComm/Commons/include/CMessage.h",
        "BTC::ServiceComm::CommonsUtil::MakeSinglePartMessage" -> "ServiceComm/CommonsUtil/include/MessageUtil.h",
        "BTC::ServiceComm::Default::ProtobufErrorAdapter" -> "ServiceComm/Default/include/ProtobufErrorAdapter.h",
        "BTC::ServiceComm::Default::RegisterBaseMessageTypes" -> "ServiceComm/Default/include/BaseMessageTypes.h",
        "BTC::ServiceComm::PerformanceBase::PerformanceTestServer" ->
            "ServiceComm/PerformanceBase/include/ServerBase.h",
        "BTC::ServiceComm::PerformanceBase::PerformanceTestServerBase" ->
            "ServiceComm/PerformanceBase/include/ServerBase.h",
        "BTC::ServiceComm::ProtobufBase::AProtobufServiceDispatcherBaseTemplate" ->
            "ServiceComm/ProtobufBase/include/AProtobufServiceDispatcherBase.h",
        "BTC::ServiceComm::ProtobufBase::AProtobufServiceProxyBaseTemplate" ->
            "ServiceComm/ProtobufBase/include/AProtobufServiceProxyBase.h",
        "BTC::ServiceComm::ProtobufUtil::Convert" -> "ServiceComm/ProtobufUtil/include/UUIDHelper.h",
        "BTC::ServiceComm::ProtobufUtil::ExportDescriptors" ->
            "ServiceComm/ProtobufUtil/include/ProtobufMessageDecoder.h",
        "BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder" ->
            "ServiceComm/ProtobufUtil/include/ProtobufMessageDecoder.h",
        "BTC::ServiceComm::ProtobufUtil::ProtobufSupport" -> "ServiceComm/ProtobufUtil/include/ProtobufSupport.h",
        "BTC::ServiceComm::SQ::ZeroMQ::ConnectionOptionsBuilder" -> "ServiceComm.SQ/ZeroMQ/include/ConnectionOptions.h",
        "BTC::ServiceComm::SQ::ZeroMQTestSupport::ZeroMQTestConnection" ->
            "ServiceComm.SQ/ZeroMQTestSupport/include/CZeroMQTestConnection.h",
        "BTC::ServiceComm::SQ::ZeroMQTestSupport::ConnectionDirection" ->
            "ServiceComm.SQ/ZeroMQTestSupport/include/CZeroMQTestConnection.h",
        "BTC::ServiceComm::TestBase::ITestConnection" -> "ServiceComm/TestBase/include/TestConnection.h",
        "BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy" ->
            "ServiceComm/Util/include/CDefaultObservableRegistrationProxy.h",
        "BTC::ServiceComm::Util::CDispatcherAutoRegistrationFactory" ->
            "ServiceComm/Util/include/DispatcherAutoRegistrationFactory.h",
        "BTC::ServiceComm::Util::DefaultCreateDispatcherWithContext" ->
            "ServiceComm/Util/include/DispatcherAutoRegistration.h",
        "BTC::ServiceComm::Util::DefaultCreateDispatcherWithContextAndEndpoint" ->
            "ServiceComm/Util/include/DispatcherAutoRegistration.h",
        "BTC::ServiceComm::Util::DispatcherAutoRegistration" -> "ServiceComm/Util/include/DispatcherAutoRegistration.h",
        "BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory" ->
            "ServiceComm/Util/include/DispatcherAutoRegistrationFactory.h",
        "BTC_CAB_LOGGING_API_INIT_LOGGERAWARE" -> "Logging/API/include/LoggerName.h",
        "CABLOG_DEBUG" -> "Logging/API/include/Logging.h",
        "CABLOG_ERROR" -> "Logging/API/include/Logging.h",
        "CABLOG_FATAL" -> "Logging/API/include/Logging.h",
        "CABLOG_INFO" -> "Logging/API/include/Logging.h",
        "CABLOG_TRACE" -> "Logging/API/include/Logging.h",
        "CABLOG_WARNING" -> "Logging/API/include/Logging.h",
        "CCLOG_DEBUG" -> "Logging/API/include/Logging.h",
        "CCLOG_ERROR" -> "Logging/API/include/Logging.h",
        "CCLOG_FATAL" -> "Logging/API/include/Logging.h",
        "CCLOG_INFO" -> "Logging/API/include/Logging.h",
        "CCLOG_TRACE" -> "Logging/API/include/Logging.h",
        "CCLOG_WARNING" -> "Logging/API/include/Logging.h",
        "CAB_SIMPLE_EXCEPTION_DEFINITION" -> "Commons/Core/include/Exception.h",
        "CAB_SIMPLE_EXCEPTION_IMPLEMENTATION" -> "Commons/Core/include/Exception.h",
        "CABTHROW_V2" -> "Commons/Core/include/Exception.h",
        "CABTYPENAME" -> "Commons/Core/include/TypeInfo.h",
        "TEST" -> "Commons/TestFW/API/CPP/include/Test.h",
        "UTAREEQUAL" -> "Commons/TestFW/API/CPP/include/AssertionMacros.h",
        "UTDOESNOTTHROW" -> "Commons/TestFW/API/CPP/include/AssertionMacros.h",
        "UTTHROWS" -> "Commons/TestFW/API/CPP/include/AssertionMacros.h"
    }

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    private static val cab_impl_header_mapper = #{
        "BTC::Commons::CoreExtras::Optional" -> "Commons/CoreExtras/include/OptionalImpl.h",
        "BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy" ->
            "ServiceComm/Util/include/CDefaultObservableRegistrationProxy.impl.h"
    }

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    private static val boost_header_mapper = #{
        "boost::bimap" -> "boost/bimap.hpp"
    }

    private val Map<String, GroupedHeader> headerMap
    private val Map<String, GroupedHeader> implementationHeaderMap

    @Accessors private val Iterable<OutputConfigurationItem> outputConfiguration

    private new(Map<String, GroupedHeader> headerMap, Map<String, GroupedHeader> implementationHeaderMap,
        Iterable<OutputConfigurationItem> outputConfiguration)
    {
        this.headerMap = headerMap.immutableCopy
        this.implementationHeaderMap = implementationHeaderMap.immutableCopy
        this.outputConfiguration = outputConfiguration.sortBy[precedence].immutableCopy
    }

    @Data
    static class OutputConfigurationItem
    {
        Iterable<TypeResolver.IncludeGroup> includeGroups
        int precedence
        String prefix
        String suffix
        boolean systemIncludeStyle
    }

    static class Builder
    {
        private val headerMap = new HashMap<String, GroupedHeader>
        private val implementationHeaderMap = new HashMap<String, GroupedHeader>
        private val outputConfiguration = new ArrayList<OutputConfigurationItem>

        def withGroup(Map<String, String> classToHeaderMap, IncludeGroup group)
        {
            withGroup(headerMap, classToHeaderMap, group)
            this
        }

        private static def withGroup(Map<String, GroupedHeader> headerMap, Map<String, String> classToHeaderMap,
            IncludeGroup group)
        {
            headerMap.putAll(transformHeaderMap(classToHeaderMap, group).toMap([it.key], [it.value]))
        // TODO check for conflicts?            
        }

        def withImplementationGroup(Map<String, String> classToHeaderMap, IncludeGroup group)
        {
            withGroup(implementationHeaderMap, classToHeaderMap, group)
            this
        }

        def build()
        {
            new HeaderResolver(headerMap, implementationHeaderMap, outputConfiguration)
        }

        def static withBasicGroups(Builder builder)
        {
            builder.withGroup(stl_header_mapper, TypeResolver.STL_INCLUDE_GROUP).withGroup(boost_header_mapper,
                TypeResolver.BOOST_INCLUDE_GROUP).withGroup(cab_header_mapper, TypeResolver.CAB_INCLUDE_GROUP).
                withImplementationGroup(cab_impl_header_mapper, TypeResolver.CAB_INCLUDE_GROUP)
        }

        def configureGroup(Iterable<TypeResolver.IncludeGroup> includeGroups, int precedence, String prefix,
            String suffix, boolean systemIncludeStyle)
        {
            outputConfiguration.add(
                new OutputConfigurationItem(includeGroups.toList.immutableCopy, precedence, prefix, suffix,
                    systemIncludeStyle))
            this
        }

        def configureGroup(TypeResolver.IncludeGroup includeGroup, int precedence, String prefix, String suffix,
            boolean systemIncludeStyle)
        {
            configureGroup(Arrays.asList(includeGroup), precedence, prefix, suffix, systemIncludeStyle)
            this
        }

    }

    def static Iterable<Pair<String, GroupedHeader>> transformHeaderMap(Map<String, String> map, IncludeGroup group)
    {
        map.entrySet.map[new Pair(it.key, new GroupedHeader(group, new Path(it.value)))]
    }

    @Data
    static class GroupedHeader
    {
        IncludeGroup includeGroup
        IPath path
    }

    def GroupedHeader getHeader(String className)
    {
        val res = headerMap.get(className)
        if (res === null)
            throw new IllegalArgumentException("Could not find *.h mapping: " + className)
        else
            res
    }

    def GroupedHeader getImplementationHeader(String className)
    {
        val res = implementationHeaderMap.get(className)
        if (res === null)
            getHeader(className)
        else
            res
    }

    @Deprecated
    def boolean isCAB(String class_name)
    {
        val key = GeneratorUtil.switchSeparator(class_name, TransformType.PACKAGE, TransformType.NAMESPACE)

        if (cab_header_mapper.containsKey(key))
            return true

        if (cab_impl_header_mapper.containsKey(key))
            return true

        return false
    }

    @Deprecated
    def boolean isBoost(String class_name)
    {
        return class_name.startsWith("boost")
    }
}
