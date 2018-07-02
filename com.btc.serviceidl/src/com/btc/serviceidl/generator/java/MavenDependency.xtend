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
 * \file       MavenDependency.xtend
 * 
 * \brief      Data structure to represent a Maven project dependency.
 */
package com.btc.serviceidl.generator.java

import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(PUBLIC_GETTER)
class MavenDependency
{
    val String groupId
    val String artifactId
    val String version
    val String scope

    private new(Builder builder)
    {
        groupId = builder.groupId
        artifactId = builder.artifactId
        version = builder.version
        scope = builder.scope
    }

    override String toString()
    {
        val string_builder = new StringBuilder
        string_builder.append("groupId:")
        string_builder.append(groupId)
        string_builder.append(",artifactId:")
        string_builder.append(artifactId)
        string_builder.append(",version:")
        string_builder.append(version)
        if (scope !== null)
        {
            string_builder.append(",scope:")
            string_builder.append(scope)
        }
        string_builder.toString
    }

    override boolean equals(Object e)
    {
        if (e !== null && e instanceof MavenDependency)
        {
            return e.toString.equals(this.toString)
        }

        return false
    }

    override int hashCode()
    {
        return toString.hashCode
    }

    @Accessors(PUBLIC_GETTER)
    static class Builder
    {
        var String groupId
        var String artifactId
        var String version
        var String scope

        def Builder groupId(String value)
        {
            groupId = value;
            return this
        }

        def Builder artifactId(String value)
        {
            artifactId = value
            return this
        }

        def Builder version(String value)
        {
            version = value
            return this
        }

        def Builder scope(String value)
        {
            scope = value
            return this
        }

        def MavenDependency build()
        {
            new MavenDependency(this)
        }
    }
}
