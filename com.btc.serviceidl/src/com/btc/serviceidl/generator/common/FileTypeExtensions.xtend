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
 * \file       FileTypeExtensions.xtend
 * 
 * \brief      Static extension methods for different file type
 */
package com.btc.serviceidl.generator.common

class FileTypeExtensions
{

    /**
     * C++ source file extension (*.cpp)
     */
    static def String cpp(String file_name)
    {
        file_name + ".cpp"
    }

    /**
     * C++ header file extension (*.h)
     */
    static def String h(String file_name)
    {
        file_name + ".h"
    }

    /**
     * Visual Studio C++ project file extension (*.vcxproj)
     */
    static def String vcxproj(String file_name)
    {
        file_name + ".vcxproj"
    }

    /**
     * Visual Studio project filter file extension (*.filters)
     */
    static def String filters(String file_name)
    {
        file_name + ".filters"
    }

    /**
     * Visual Studio user setting file extension (*.user)
     */
    static def String user(String file_name)
    {
        file_name + ".user"
    }

    /**
     * C# source file (*.cs)
     */
    static def String cs(String file_name)
    {
        file_name + ".cs"
    }

    /**
     * Visual Studio C# project file extension (*.csproj)
     */
    static def String csproj(String file_name)
    {
        file_name + ".csproj"
    }

    /**
     * Visual Studio configuration file extension (*.config)
     */
    static def String config(String file_name)
    {
        file_name + ".config"
    }

    /**
     * XML file (*.xml)
     */
    static def String xml(String file_name)
    {
        file_name + ".xml"
    }

    /**
     * ODB header file (*.hxx)
     */
    static def String hxx(String file_name)
    {
        file_name + ".hxx"
    }

    /**
     * ODB generated inline header file (*.ixx)
     */
    static def String ixx(String file_name)
    {
        file_name + ".ixx"
    }

    /**
     * ODB generated source file (*.cxx)
     */
    static def String cxx(String file_name)
    {
        file_name + ".cxx"
    }

    /**
     * Protobuf file (*.proto)
     */
    static def String proto(String file_name)
    {
        file_name + ".proto"
    }

    /**
     * Apache Maven Project Object Model file (*.pom)
     */
    static def String pom(String file_name)
    {
        file_name + ".pom"
    }

    /**
     * Java source file (*.java)
     */
    static def String java(String file_name)
    {
        file_name + ".java"
    }

    /**
     * Properties file (*.properties)
     */
    static def String properties(String file_name)
    {
        file_name + ".properties"
    }

    /**
     * Protoc-generated artifact (*.pb.XX)
     */
    static def String pb(String file_name)
    {
        file_name + ".pb"
    }
}
