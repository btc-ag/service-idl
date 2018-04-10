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
    def static String cpp(String file_name)
    {
        file_name + ".cpp"
    }

    /**
     * C++ header file extension (*.h)
     */
    def static String h(String file_name)
    {
        file_name + ".h"
    }

    /**
     * Visual Studio C++ project file extension (*.vcxproj)
     */
    def static String vcxproj(String file_name)
    {
        file_name + ".vcxproj"
    }

    /**
     * Visual Studio project filter file extension (*.filters)
     */
    def static String filters(String file_name)
    {
        file_name + ".filters"
    }

    /**
     * Visual Studio user setting file extension (*.user)
     */
    def static String user(String file_name)
    {
        file_name + ".user"
    }

    /**
     * C# source file (*.cs)
     */
    def static String cs(String file_name)
    {
        file_name + ".cs"
    }

    /**
     * Visual Studio C# project file extension (*.csproj)
     */
    def static String csproj(String file_name)
    {
        file_name + ".csproj"
    }

    /**
     * Visual Studio configuration file extension (*.config)
     */
    def static String config(String file_name)
    {
        file_name + ".config"
    }

    /**
     * XML file (*.xml)
     */
    def static String xml(String file_name)
    {
        file_name + ".xml"
    }

    /**
     * ODB header file (*.hxx)
     */
    def static String hxx(String file_name)
    {
        file_name + ".hxx"
    }

    /**
     * ODB generated inline header file (*.ixx)
     */
    def static String ixx(String file_name)
    {
        file_name + ".ixx"
    }

    /**
     * ODB generated source file (*.cxx)
     */
    def static String cxx(String file_name)
    {
        file_name + ".cxx"
    }

    /**
     * Protobuf file (*.proto)
     */
    def static String proto(String file_name)
    {
        file_name + ".proto"
    }

    /**
     * Apache Maven Project Object Model file (*.pom)
     */
    def static String pom(String file_name)
    {
        file_name + ".pom"
    }

    /**
     * Java source file (*.java)
     */
    def static String java(String file_name)
    {
        file_name + ".java"
    }

    /**
     * Properties file (*.properties)
     */
    def static String properties(String file_name)
    {
        file_name + ".properties"
    }

    /**
     * Protoc-generated artifact (*.pb.XX)
     */
    def static String pb(String file_name)
    {
        file_name + ".pb"
    }
}
