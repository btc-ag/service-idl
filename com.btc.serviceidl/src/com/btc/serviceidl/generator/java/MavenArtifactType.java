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
 * \file       MavenArtifactType.java
 *
 * \brief      Artifact type for common Maven directory layout;
 *             \see https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html
 *             for more details.
 */

package com.btc.serviceidl.generator.java;

public enum MavenArtifactType {
    MAIN_JAVA,
    MAIN_RESOURCES,
    TEST_JAVA,
    TEST_RESOURCES;

    public final String getDirectoryLayout() {
        switch (this) {
        case MAIN_JAVA:
            return "src/main/java";
        case MAIN_RESOURCES:
            return "src/main/resources";
        case TEST_JAVA:
            return "src/test/java";
        case TEST_RESOURCES:
            return "src/test/resources";
        default:
            throw new AssertionError("Unsupported enumeration type: " + this);
        }
    }
}
