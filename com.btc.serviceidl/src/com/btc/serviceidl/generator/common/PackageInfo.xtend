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
package com.btc.serviceidl.generator.common

import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.lib.annotations.Accessors

/**
 * Simple class to contain information for external package dependencies
 * for conan, paket, maven, etc.
 */
class PackageInfo
{
    @Accessors(NONE) val Map<ArtifactNature, String> packageIDs
    @Accessors(PUBLIC_GETTER) val String version
    @Accessors(PUBLIC_GETTER) val URI resourceURI
    
    new(Map<ArtifactNature, String> packageIDs, String version, URI resourceURI)
    {
        this.packageIDs = packageIDs
        this.version = version
        this.resourceURI = resourceURI
    }

    def getID(ArtifactNature artifactNature)
    {
        packageIDs.get(artifactNature)
    }
}
