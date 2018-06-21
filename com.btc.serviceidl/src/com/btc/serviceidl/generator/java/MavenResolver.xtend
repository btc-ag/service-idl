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
 * \file       MavenResolver.xtend
 * 
 * \brief      Resolution of Maven dependencies
 */
package com.btc.serviceidl.generator.java

import java.util.Optional
import org.eclipse.emf.ecore.EObject
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.util.Constants

import static extension com.btc.serviceidl.util.Util.*

class MavenResolver
{
    // constants
    public static val DEFAULT_VERSION = "0.0.1"

    static def MavenDependency resolveDependency(EObject element)
    {
        val name = resolvePackage(element, Optional.empty)
        val version = resolveVersion(element.scopeDeterminant)

        return new MavenDependency.Builder().groupId(name).artifactId(name).version(version).build
    }

    static def Optional<MavenDependency> resolveDependency(String class_name)
    {
        switch name : class_name.toLowerCase
        {
            case name.startsWith("com.google.protobuf."):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.google.protobuf").artifactId("protobuf-java").version(
                        DependencyVersions.GOOGLE_PROTOBUF).build)
            case name.startsWith("org.apache.commons.collections4."):
                return Optional.of(
                    new MavenDependency.Builder().groupId("org.apache.commons").artifactId("commons-collections4").
                        version(DependencyVersions.COMMONS_COLLECTIONS).build)
            case name.startsWith("org.junit."):
                return Optional.of(
                    new MavenDependency.Builder().groupId("junit").artifactId("junit").version(
                        DependencyVersions.JUNIT).scope("test").build)
            case name.startsWith("org.apache.log4j."):
                return Optional.of(
                    new MavenDependency.Builder().groupId("log4j").artifactId("log4j").version(
                        DependencyVersions.LOG4J).build)
            case name.startsWith("org.apache.commons.lang3."):
                return Optional.of(
                    new MavenDependency.Builder().groupId("org.apache.commons").artifactId("commons-lang3").version(
                        DependencyVersions.APACHE_COMMONS).build)
            case name.startsWith("com.btc.cab.servicecomm.api"):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.btc.cab.servicecomm").artifactId("api").version(
                        "${servicecomm.version}").build)
            case name.startsWith("com.btc.cab.servicecomm.faulthandling"):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.btc.cab.servicecomm").artifactId("faulthandling").
                        version("${servicecomm.version}").build)
            case name.startsWith("com.btc.cab.servicecomm.singlequeue.core"):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.btc.cab.servicecomm").artifactId("singlequeue.core").
                        version("${servicecomm.version}").build)
            case name.startsWith("com.btc.cab.servicecomm.singlequeue.jeromq"):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.btc.cab.servicecomm").artifactId(
                        "singlequeue.zeromq.jeromq").version("${servicecomm.version}").build)
            case name.startsWith("com.btc.cab.servicecomm.singlequeue.zeromq.jzmq"):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.btc.cab.servicecomm").artifactId(
                        "singlequeue.zeromq.jzmq").version("${servicecomm.version}").build)
            case name.startsWith("com.btc.cab.servicecomm.singlequeue.zeromq"):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.btc.cab.servicecomm").artifactId("singlequeue.zeromq").
                        version("${servicecomm.version}").build)
            case name.startsWith("com.btc.cab.servicecomm.protobuf"):
                return Optional.of(
                    new MavenDependency.Builder().groupId("com.btc.cab.servicecomm").artifactId("protobuf").version(
                        "${servicecomm.version}").build)
            case name.startsWith("org.springframework.context.support."):
                return Optional.of(
                    new MavenDependency.Builder().groupId("org.springframework").artifactId("spring-context-support").
                        version(DependencyVersions.SPRING).build)
            case name.startsWith("org.springframework.context."):
                return Optional.of(
                    new MavenDependency.Builder().groupId("org.springframework").artifactId("spring-context").version(
                        DependencyVersions.SPRING).build)
            default:
                return Optional.empty // no external dependency, e.g. it's Java API
        }
    }

    /**
     * For a given element, which is expected to be either module or interface,
     * returns the appropriate version string (default is 0.0.1)
     */
    static def String resolveVersion(EObject element)
    {
        if (element instanceof InterfaceDeclaration)
        {
            return element.version ?: DEFAULT_VERSION
        }

        return DEFAULT_VERSION
    }

    static def String resolvePackage(EObject element, Optional<ProjectType> project_type)
    {
        val scopeDeterminant = element.scopeDeterminant
        return String.join(Constants.SEPARATOR_PACKAGE, #[
            GeneratorUtil.getTransformedModuleName(ParameterBundle.createBuilder(scopeDeterminant.moduleStack).build,
                ArtifactNature.JAVA, TransformType.PACKAGE)
        ] + (if (scopeDeterminant instanceof InterfaceDeclaration) #[scopeDeterminant.name.toLowerCase] else #[]) +
            if (project_type.present) #[project_type.get.getName.toLowerCase] else #[])
    }
    
    static def getArtifactId(EObject container) {
        resolvePackage(container, Optional.empty)
    }
    
}
