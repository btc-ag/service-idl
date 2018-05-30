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
 * \file       Constants.java
 *
 * \brief      Constants and enumerations
 */

package com.btc.serviceidl.util;

import org.eclipse.core.runtime.IPath;

public interface Constants {

    // diverse separators, e.g. for paths, packages, namespaces
    public static final String SEPARATOR_FILE       = String.valueOf(IPath.SEPARATOR);
    public static final String SEPARATOR_PACKAGE    = ".";
    public static final String SEPARATOR_NAMESPACE  = "::";
    public static final String SEPARATOR_CPP_HEADER = "_";

    // used e.g. for compatibility reasons in path declarations within MS VS project
    // files
    public static final String SEPARATOR_BACKSLASH = "\\";

    // common project names
    public static final String PROJECT_NAME_SERVICE_API      = "ServiceAPI";
    public static final String PROJECT_NAME_PROXY            = "Proxy";
    public static final String PROJECT_NAME_DISPATCHER       = "Dispatcher";
    public static final String PROJECT_NAME_IMPL             = "Impl";
    public static final String PROJECT_NAME_PROTOBUF         = "Protobuf";
    public static final String PROJECT_NAME_COMMON           = "Common";
    public static final String PROJECT_NAME_TEST             = "Test";
    public static final String PROJECT_NAME_SERVER_RUNNER    = "ServerRunner";
    public static final String PROJECT_NAME_CLIENT_CONSOLE   = "ClientConsole";
    public static final String PROJECT_NAME_EXTERNAL_DB_IMPL = "ExternalDBImpl";

    // Protobuf message names
    public static final String PROTOBUF_REQUEST  = "Request";
    public static final String PROTOBUF_RESPONSE = "Response";

    // File names
    public static final String FILE_NAME_DEPENDENCIES  = "Dependencies";
    public static final String FILE_NAME_TYPES         = "Types";
    public static final String FILE_NAME_CODEC         = "Codec";
    public static final String FILE_NAME_ASSEMBLY_INFO = "AssemblyInfo";
    public static final String FILE_NAME_ODB_COMMON    = "common";
    public static final String FILE_NAME_ODB_TRAITS    = "traits";

    // GUID for default exception registration thrown by not implemented methods
    public static final String UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER = "BTC.Commons.Core.UnsupportedOperationException";

    public static final String INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER = "BTC.Commons.Core.InvalidArgumentException";

    public static final int DEFAULT_PORT = 5555;

    public static final String AUTO_GENERATED_METHOD_STUB_MESSAGE = "Auto-generated method stub is not implemented!";

    public static final String ZMQ_SERVER_PRIVATE_KEY = "d{pnP/0xVmQY}DCV2BS)8Y9fw9kB/jq^id4Qp}la";
    public static final String ZMQ_SERVER_PUBLIC_KEY  = "Qr5^/{Rc{V%ji//usp(^m^{(qxC3*j.vsF+Q{XJt";
    public static final String ZMQ_CLIENT_PRIVATE_KEY = "9L9K[bCFp7a]/:gJL2x{PoV}wnaAb.Zt}[qj)z/!";
    public static final String ZMQ_CLIENT_PUBLIC_KEY  = "=ayKwMDx1YB]TK9hj4:II%8W2p4:Ue((iEkh30:@";

    public static final String PROTOBUF_GENERATION_DIRECTORY_NAME = "gen";
}
