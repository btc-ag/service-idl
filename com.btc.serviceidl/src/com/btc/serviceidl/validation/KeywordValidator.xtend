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
 * \file       KeywordValidator.xtend
 * 
 * \brief      Validation of language-specific keywords for C++, Java, C#
 */
package com.btc.serviceidl.validation

import java.util.regex.Pattern

class KeywordValidator
{
    static def boolean isKeyword(String word, int pattern)
    {
        return word.isCppKeyword(pattern) || word.isCSharpKeyword(pattern) || word.isJavaKeyword(pattern) ||
            word.isProtobufKeyword(pattern)
    }

    /**
     * \remark Keyword list taken from the article "C++ keywords"
     * http://en.cppreference.com/w/cpp/keyword
     */
    static def private boolean isCppKeyword(String word, int pattern)
    {
        val keywords = #[
            "alignas",
            "alignof",
            "and",
            "and_eq",
            "asm",
            "auto",
            "bitand",
            "bitor",
            "bool",
            "break",
            "case",
            "catch",
            "char",
            "char16_t",
            "char32_t",
            "class",
            "compl",
            "concept",
            "const",
            "const_cast",
            "constexpr",
            "continue",
            "decltype",
            "default",
            "delete",
            "do",
            "double",
            "dynamic_cast",
            "else",
            "enum",
            "explicit",
            "export",
            "extern",
            "false",
            "final",
            "float",
            "for",
            "friend",
            "goto",
            "if",
            "inline",
            "int",
            "long",
            "mutable",
            "namespace",
            "new",
            "noexcept",
            "not",
            "not_eq",
            "nullptr",
            "operator",
            "or",
            "or_eq",
            "override",
            "private",
            "protected",
            "public",
            "register",
            "reinterpret_cast",
            "requires",
            "return",
            "short",
            "signed",
            "sizeof",
            "static",
            "static_assert",
            "static_cast",
            "struct",
            "switch",
            "template",
            "this",
            "thread_local",
            "throw",
            "true",
            "try",
            "typedef",
            "typeid",
            "typename",
            "union",
            "unsigned",
            "using",
            "virtual",
            "void",
            "volatile",
            "wchar_t",
            "while",
            "xor",
            "xor_eq"
        ]

        return keywords.contains(if (pattern == Pattern.CASE_INSENSITIVE) word.toLowerCase else word)
    }

    /**
     * \remark Keyword list taken from the article "Java Language Keywords"
     * https://docs.oracle.com/javase/tutorial/java/nutsandbolts/_keywords.html
     */
    static def private boolean isJavaKeyword(String word, int pattern)
    {
        val keywords = #[
            "abstract",
            "assert",
            "boolean",
            "break",
            "byte",
            "case",
            "catch",
            "char",
            "class",
            "const",
            "continue",
            "default",
            "do",
            "double",
            "else",
            "enum",
            "extends",
            "final",
            "finally",
            "float",
            "for",
            "goto",
            "if",
            "implements",
            "import",
            "instanceof",
            "int",
            "interface",
            "long",
            "native",
            "new",
            "package",
            "private",
            "protected",
            "public",
            "return",
            "short",
            "static",
            "strictfp",
            "super",
            "switch",
            "synchronized",
            "this",
            "throw",
            "throws",
            "transient",
            "try",
            "void",
            "volatile",
            "while"
        ]

        return keywords.contains(if (pattern == Pattern.CASE_INSENSITIVE) word.toLowerCase else word)
    }

    /**
     * \remark Keyword list taken from the article "C# keywords"
     * https://msdn.microsoft.com/en-us/library/vstudio/x53a06bb%28v=vs.140%29.aspx
     */
    static def private boolean isCSharpKeyword(String word, int pattern)
    {
        val keywords = #[
            "abstract",
            "as",
            "base",
            "bool",
            "break",
            "byte",
            "case",
            "catch",
            "char",
            "checked",
            "class",
            "const",
            "continue",
            "decimal",
            "default",
            "delegate",
            "do",
            "double",
            "else",
            "enum",
            "event",
            "explicit",
            "extern",
            "false",
            "finally",
            "fixed",
            "float",
            "for",
            "foreach",
            "goto",
            "if",
            "implicit",
            "in",
            "int",
            "interface",
            "internal",
            "is",
            "lock",
            "long",
            "namespace",
            "new",
            "null",
            "object",
            "operator",
            "out",
            "override",
            "params",
            "private",
            "protected",
            "public",
            "readonly",
            "ref",
            "return",
            "sbyte",
            "sealed",
            "short",
            "sizeof",
            "stackalloc",
            "static",
            "string",
            "struct",
            "switch",
            "this",
            "throw",
            "true",
            "try",
            "typeof",
            "uint",
            "ulong",
            "unchecked",
            "unsafe",
            "ushort",
            "using",
            "virtual",
            "void",
            "volatile",
            "while"
        ]

        return keywords.contains(if (pattern == Pattern.CASE_INSENSITIVE) word.toLowerCase else word)
    }

    /**
     * \remark This keywords are (empirically) known to be used as internal
     *         identifiers in the code generated by the protoc compiler and
     *         cause name collisions.
     */
    static def private boolean isProtobufKeyword(String word, int pattern)
    {
        val keywords = #[
            "descriptor",
            "clear",
            "clone"
        ]

        return keywords.contains(if (pattern == Pattern.CASE_INSENSITIVE) word.toLowerCase else word)
    }
}
