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

package com.btc.serviceidl.generator.common;

import com.btc.serviceidl.util.Constants;

public enum ProjectType {
    SERVICE_API(Constants.PROJECT_NAME_SERVICE_API),
    PROXY(Constants.PROJECT_NAME_PROXY),
    DISPATCHER(Constants.PROJECT_NAME_DISPATCHER),
    IMPL(Constants.PROJECT_NAME_IMPL),
    PROTOBUF(Constants.PROJECT_NAME_PROTOBUF),
    COMMON(Constants.PROJECT_NAME_COMMON),
    TEST(Constants.PROJECT_NAME_TEST),
    SERVER_RUNNER(Constants.PROJECT_NAME_SERVER_RUNNER),
    CLIENT_CONSOLE(Constants.PROJECT_NAME_CLIENT_CONSOLE),
    EXTERNAL_DB_IMPL(Constants.PROJECT_NAME_EXTERNAL_DB_IMPL);

    public final static ProjectType from(final String name) {
        for (final ProjectType p : ProjectType.values()) {
            if (p.name.equalsIgnoreCase(name)) {
                return p;
            }
        }

        throw new IllegalArgumentException("Enum value is unknown: " + name);
    }

    private final String name;

    ProjectType(final String name) {
        this.name = name;
    }

    public final String getClassName(final ArtifactNature artifact_nature, final String basic_name) {
        return getFilePrefix(artifact_nature) + basic_name + getFileSuffix();
    }

    // TODO the name of this method is confusing, as it does not only determine the
    // file name
    private final String getFilePrefix(final ArtifactNature artifact_nature) {
        if (name.equals(Constants.PROJECT_NAME_SERVICE_API)) {
            // TODO this naming convention should be configurable
            return "I";
        } else if (name.equals(Constants.PROJECT_NAME_PROTOBUF) || name.equals(Constants.PROJECT_NAME_COMMON)
                || name.equals(Constants.PROJECT_NAME_TEST) || name.equals(Constants.PROJECT_NAME_SERVER_RUNNER)
                || name.equals(Constants.PROJECT_NAME_CLIENT_CONSOLE)) {
            return "";
        } else {
            if (artifact_nature == ArtifactNature.CPP) {
                return "C";
            } else {
                return "";
            }
        }
    }

    private final String getFileSuffix() {
        if (name.equals(Constants.PROJECT_NAME_SERVICE_API) || name.equals(Constants.PROJECT_NAME_PROTOBUF)
                || name.equals(Constants.PROJECT_NAME_COMMON) || name.equals(Constants.PROJECT_NAME_CLIENT_CONSOLE)) {
            return "";
        } else if (name.equals(Constants.PROJECT_NAME_EXTERNAL_DB_IMPL)) {
            return Constants.PROJECT_NAME_IMPL; // special case: same as Impl
        } else {
            return name;
        }
    }

    public final String getName() {
        return name;
    }
}
