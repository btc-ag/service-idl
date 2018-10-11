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
 * \file       Messages.xtend
 * 
 * \brief      Warnings and error messages for the validator.
 */
package com.btc.serviceidl.validation

class Messages
{
    public static val IDENTIFIER_NAME_IS_KEYWORD = "This identifier is either a reserved keyword in C++, Java or C#, or it is used by the Protobuf compiler in the generated code! Please choose another name."

    public static val NAME_COLLISION = "Name collision: names of modules/interfaces have to be unique"

    public static val FEATURE_NOT_SUPPORED_BY_CAB = "Currently there is no CAB support for this feature, so it has no effect on the generated code"

    public static val TUPLE_TYPE_NOT_SUPPORTED = "The tuple type is currently not supported by the generator! Use a struct instead!"

    public static val CIRCULAR_INHERITANCE = "Circular inheritance detected! One of this type's base types is derived from this type itself."

    public static val NAME_COLLISION_MEMBERS = "Name collision of members in base class and derived class"

    public static val NAME_COLLISION_PARAMETERS = "Name collision of method parameters"

    public static val TYPE_NOT_CONSTRUCTIBLE = "It is impossible to create an instance of this type due to mutual dependencies! Either resolve mutual dependencies or mark dependent types as optional!"

    public static val EXTERNAL_CIRCULAR_DEPENDENCIES = "External circular dependencies are currently not supported! Awaiting C++17..."

    public static val ALIAS_SEQUENCES_NOT_SUPPORTED = "It's not trivial to represent alias sequences in Protobuf in a stable way, therefore they are currently not supported by the generator! You can easily wrap a sequences in an extra struct, if you want to alias them."

    public static val NESTED_SEQUENCES_NOT_SUPPORTED = "It's not trivial to represent nested sequences in Protobuf in a stable way, therefore they are currently not supported by the generator! You can easily wrap a sequences in an extra struct, if you want to nest them."

    public static val EXCEPTION_REFERENCE_NOT_SUPPORTED = "There is currently no concept how to use exception references in practice, therefore they are turned off"

    public static val IMMUTABLE_OUTPUT_PARAMETER = "Immutable types cannot be used as output parameters in Java! Workaround: wrap it into a struct."

    public static val DUPLICATE_EXCEPTION_TYPES = "Same exception type is used multiple times!"

    public static val DEPRECATED_NESTED_TYPE_DECLARATION = "This IDL feature is deprecated due to its unmanageable and unnecessary complexity! Do not use nested type declarations! Instead, declare them as separate types!"

    public static val DEPRECATED_ADHOC_DECLARATION = "This IDL feature is deprecated due to its uselessness along with high maintenance costs! Use a normal struct member instead!"

    public static val DEPRECATED_VERSION_DECLARATION = "Declaring versions on an interface is now deprecated and has no effect, declare the version at the IDL level instead!"

    public static val UNIQUE_MAIN_MODULE = "No more than one main module is allowed!"

    public static val EMPTY_NON_MAIN_MODULE = "Module outside main module must be empty!"

    public static val INDETERMINATE_IMPLICIT_MAIN_MODULE = "No implicit main module could be determined, since there are two non-empty top-level modules!"
    
    public static val AMBIGUOUS_IMPLICIT_MAIN_MODULE = "Implicit main module is ambiguous, since there are multiple modules containing definitions, using common container module!"
}
