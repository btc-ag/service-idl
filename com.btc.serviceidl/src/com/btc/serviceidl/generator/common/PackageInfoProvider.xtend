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

import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.util.Constants
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.naming.QualifiedName

class PackageInfoProvider
{
    def static getVersion(Resource resource)
    {
        resource.allContents.filter(IDLSpecification).map[version ?: Constants.DEFAULT_VERSION].head
    }

    def static getPackageInfo(Resource resource)
    {
        val idl = resource.allContents.filter(IDLSpecification).head
        val packageIDs = #{
            makeID(ArtifactNature.CPP, idl),
            makeID(ArtifactNature.DOTNET, idl),
            makeID(ArtifactNature.JAVA, idl)
        }
        new PackageInfo(packageIDs, resource.version)
    }
    
    def private static makeID(ArtifactNature artifactNature, IDLSpecification idl)
    {
        artifactNature -> GeneratorUtil.getReleaseUnitName(idl, artifactNature)
    }
    
    /**
     * Get package ID out of a project identifier, which may be a fully
     * qualified project name or a path
     * 
     * TODO we should enhance the project dependency resolution mechanism in the
     * generator to solve this topic in a clean way; now it's more like a heuristic
     */
    def static String getID(String projectIdentifier)
    {
        val components = QualifiedName.create(projectIdentifier.split("\\W"))
        if (components == QualifiedName.EMPTY)
            throw new IllegalArgumentException("Cannot create ID for given project identifier")

        if (ProjectType.values.map[getName].contains(components.lastSegment))
        {
            return components.skipLast(1).toString
        }
        
        // try to handle special cases e.g. for types nested inside interfaces etc.
        getID(components.skipLast(1).toString)
    }
}
