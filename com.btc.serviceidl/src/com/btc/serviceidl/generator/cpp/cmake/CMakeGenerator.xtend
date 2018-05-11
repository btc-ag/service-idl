/**
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import java.util.Map
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.core.runtime.IPath

@Accessors
class CMakeGenerator {
    val ParameterBundle param_bundle
    val CMakeProjectSet cmakeProjectSet
    val Map<String, Set<CMakeProjectSet.ProjectReference>> protobuf_project_references
    val Set<CMakeProjectSet.ProjectReference> project_references

    val ProjectFileSet projectFileSet
    
    def CharSequence generateCMakeSet(String string, IPath path) {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
    def CharSequence generateCMakeLists(String string, org.eclipse.core.runtime.IPath path) {
        throw new UnsupportedOperationException("TODO: auto-generated method stub")
    }
    
}