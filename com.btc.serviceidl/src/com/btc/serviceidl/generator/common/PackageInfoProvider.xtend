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

import org.eclipse.emf.ecore.resource.Resource
import com.google.common.io.Files
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.util.Constants
import org.eclipse.xtext.naming.QualifiedName

class PackageInfoProvider
{

    def static getName(Resource resource)
    {
        Files.getNameWithoutExtension(resource.URI.path)
    }

    def static getVersion(Resource resource)
    {
        resource.allContents.filter(IDLSpecification).map[version ?: Constants.DEFAULT_VERSION].head
    }

    def static getPackageInfo(Resource resource)
    {
        new PackageInfo(resource.name, resource.version)
    }
    
    /**
     * Get package name out of a project identifier, which may be a fully
     * qualified project name or a path
     */
    def static getName(String projectIdentifier)
    {
        QualifiedName.create(projectIdentifier.split("\\W")).skipLast(1).toString
    }
}
