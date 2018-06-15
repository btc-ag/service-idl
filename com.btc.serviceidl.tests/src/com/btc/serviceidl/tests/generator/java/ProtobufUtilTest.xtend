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
package com.btc.serviceidl.tests.generator.java

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.java.MavenDependency
import com.btc.serviceidl.generator.java.ProtobufUtil
import com.btc.serviceidl.generator.java.TypeResolver
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.google.common.collect.ImmutableList
import com.google.inject.Inject
import java.util.HashSet
import java.util.Optional
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.assertEquals
import com.btc.serviceidl.generator.common.ProtobufType

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class ProtobufUtilTest
{
    @Inject ParseHelper<IDLSpecification> parseHelper

    @Inject IQualifiedNameProvider qualifiedNameProvider

    private def getFooModule()
    { idl.getModules().findFirst[it.name == "Foo"] }

    HashSet<MavenDependency> dependencies

    TypeResolver typeResolver

    IDLSpecification idl

    @Before
    def void setUp()
    {
        idl = parseHelper.parse("module Foo { struct Bar { string x }; interface Bar { struct Bar { string y }; } }");

        dependencies = new HashSet<MavenDependency>()
        val paramBundle = new ParameterBundle.Builder().reset(ImmutableList.of(fooModule)).build()
        typeResolver = new TypeResolver(qualifiedNameProvider, paramBundle, dependencies)
    }

    @Test
    def void testResolveProtobufStruct()
    {
        val result = ProtobufUtil.resolveProtobuf(typeResolver, fooModule.getModuleComponents().filter(
            StructDeclaration).findFirst[it.name == "Bar"], Optional.empty());
        assertEquals("com.foo.protobuf.Types.Bar", result.getFullyQualifiedName());
    }

    @Test
    def void testResolveProtobufStructWithinInterface()
    {
        val result = ProtobufUtil.resolveProtobuf(typeResolver, fooModule.getModuleComponents().filter(
            InterfaceDeclaration).findFirst[it.name == "Bar"].contains.filter(StructDeclaration).findFirst [
            it.name == "Bar"
        ], Optional.empty());
        assertEquals("com.foo.bar.protobuf.BarOuterClass.Bar", result.getFullyQualifiedName());
    }

    @Test
    def void testResolveProtobufStructWithinInterfaceWithSameName()
    {
        idl = parseHelper.parse("module Foo { interface Bar { struct Bar { string x }; }");

        dependencies = new HashSet<MavenDependency>()
        val paramBundle = new ParameterBundle.Builder().reset(ImmutableList.of(fooModule)).build()
        typeResolver = new TypeResolver(qualifiedNameProvider, paramBundle, dependencies)

        val result = ProtobufUtil.resolveProtobuf(typeResolver, fooModule.getModuleComponents().filter(
            InterfaceDeclaration).findFirst[it.name == "Bar"].contains.filter(StructDeclaration).findFirst [
            it.name == "Bar"
        ], Optional.empty());
        assertEquals("com.foo.bar.protobuf.BarOuterClass.Bar", result.getFullyQualifiedName());
    }

    @Test
    def void testResolveProtobufMethodRequestInConflictedInterface()
    {
        idl = parseHelper.parse("module Foo { interface Bar { struct Bar { string x }; void MyRequest(int i); }");

        dependencies = new HashSet<MavenDependency>()
        val paramBundle = new ParameterBundle.Builder().reset(ImmutableList.of(fooModule)).build()
        typeResolver = new TypeResolver(qualifiedNameProvider, paramBundle, dependencies)

        val result = ProtobufUtil.resolveProtobuf(typeResolver, fooModule.getModuleComponents().filter(
            InterfaceDeclaration).findFirst [
            it.name == "Bar"
        ], Optional.of(ProtobufType.REQUEST));
        assertEquals("com.foo.bar.protobuf.BarOuterClass.BarRequest", result.getFullyQualifiedName());
    }
    
    @Test
    def void testAsProtobufNameFromUpperCamel()
    {
        assertEquals("UpperCamel", ProtobufUtil.asProtobufName("UpperCamel"))
    }

    @Test
    def void testAsProtobufNameFromLowerCamel()
    {
        assertEquals("LowerCamel", ProtobufUtil.asProtobufName("lowerCamel"))
    }

    @Test
    def void testAsProtobufNameFromUpperCamelAbbrev()
    {
        assertEquals("Abc", ProtobufUtil.asProtobufName("ABC"))
    }

    @Test
    def void testAsProtobufNameFromUpperCamelAbbrevFollowedByWord()
    {
        assertEquals("AbcWord", ProtobufUtil.asProtobufName("ABCWord"))
    }

    @Test
    def void testAsProtobufNameFromLowerSnake()
    {
        assertEquals("LowerSnake", ProtobufUtil.asProtobufName("lower_snake"))
    }

    @Test
    def void testAsProtobufNameFromMixedSnake()
    {
        assertEquals("MixedSnake", ProtobufUtil.asProtobufName("mixed_Snake"))
    }
    
    @Test
    def void testAsProtobufNameFromMixedSnakeAbbrev()
    {
        assertEquals("MixedAbc", ProtobufUtil.asProtobufName("mixed_ABC"))
    }

    @Test
    def void testAsProtobufNameFromMixedSnakeAbbrev2()
    {
        assertEquals("PMw", ProtobufUtil.asProtobufName("p_MW"))
    }
}
