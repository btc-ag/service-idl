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
    static def String cpp(String fileName)
    {
        fileName + ".cpp"
    }

    /**
     * C++ header file extension (*.h)
     */
    static def String h(String fileName)
    {
        fileName + ".h"
    }

    /**
     * Visual Studio C++ project file extension (*.vcxproj)
     */
    static def String vcxproj(String fileName)
    {
        fileName + ".vcxproj"
    }

    /**
     * Visual Studio project filter file extension (*.filters)
     */
    static def String filters(String fileName)
    {
        fileName + ".filters"
    }

    /**
     * Visual Studio user setting file extension (*.user)
     */
    static def String user(String fileName)
    {
        fileName + ".user"
    }

    /**
     * C# source file (*.cs)
     */
    static def String cs(String fileName)
    {
        fileName + ".cs"
    }

    /**
     * Visual Studio C# project file extension (*.csproj)
     */
    static def String csproj(String fileName)
    {
        fileName + ".csproj"
    }

    /**
     * Visual Studio configuration file extension (*.config)
     */
    static def String config(String fileName)
    {
        fileName + ".config"
    }

    /**
     * XML file (*.xml)
     */
    static def String xml(String fileName)
    {
        fileName + ".xml"
    }

    /**
     * ODB header file (*.hxx)
     */
    static def String hxx(String fileName)
    {
        fileName + ".hxx"
    }

    /**
     * ODB generated inline header file (*.ixx)
     */
    static def String ixx(String fileName)
    {
        fileName + ".ixx"
    }

    /**
     * ODB generated source file (*.cxx)
     */
    static def String cxx(String fileName)
    {
        fileName + ".cxx"
    }

    /**
     * Protobuf file (*.proto)
     */
    static def String proto(String fileName)
    {
        fileName + ".proto"
    }

    /**
     * Apache Maven Project Object Model file (*.pom)
     */
    static def String pom(String fileName)
    {
        fileName + ".pom"
    }

    /**
     * Java source file (*.java)
     */
    static def String java(String fileName)
    {
        fileName + ".java"
    }

    /**
     * Properties file (*.properties)
     */
    static def String properties(String fileName)
    {
        fileName + ".properties"
    }

    /**
     * Protoc-generated artifact (*.pb.XX)
     */
    static def String pb(String fileName)
    {
        fileName + ".pb"
    }
}
