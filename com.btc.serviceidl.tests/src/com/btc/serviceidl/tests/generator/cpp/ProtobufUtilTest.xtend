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
package com.btc.serviceidl.tests.generator.cpp

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.cpp.ProtobufUtil
import com.btc.serviceidl.generator.cpp.TypeResolver
import com.btc.serviceidl.generator.cpp.cab.CABModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSet
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import javax.inject.Inject
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.assertEquals

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.generator.cpp.CppConstants

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class ProtobufUtilTest
{
    @Inject extension ParseHelper<IDLSpecification>

    static class TargetVersionProvider implements ITargetVersionProvider
    {
        override getTargetVersion(String versionKind)
        {
            if (versionKind == CppConstants.SERVICECOMM_VERSION_KIND)
                return "0.12"
                
            throw new UnsupportedOperationException("TODO: auto-generated method stub")
        }
    }

    private def createTypeResolver()
    {
        new TypeResolver(new DefaultDeclarativeQualifiedNameProvider, new CMakeProjectSet,
            new CABModuleStructureStrategy, new TargetVersionProvider, newArrayList, newArrayList, newHashMap)
    }

    @Test
    def void testNestedSequence()
    {
        val idl = TestData.getGoodTestCase("struct-nested-sequence").parse

        val typeResolver = createTypeResolver

        val module = idl.modules.head
        val containingStruct = module.moduleComponents.filter(StructDeclaration).findFirst[it.name == "Foo"]
        val member = containingStruct.members.head

        assertEquals("foo::Protobuf::TypesCodec::DecodeToVector<foo::Protobuf::Bar,foo::Common::Bar>",
            ProtobufUtil.resolveDecode(typeResolver, new ParameterBundle.Builder().with(module.moduleStack).build,
                member.type.actualType, module).replace(" ", ""))
    }

    @Test
    def void testNestedStruct()
    {
        val idl = TestData.getGoodTestCase("struct-nested").parse

        val typeResolver = createTypeResolver

        val module = idl.modules.head
        val containingStruct = module.moduleComponents.filter(StructDeclaration).findFirst[it.name == "Foo"]
        val member = containingStruct.members.head

        assertEquals("foo::Protobuf::TypesCodec::Decode",
            ProtobufUtil.resolveDecode(typeResolver, new ParameterBundle.Builder().with(module.moduleStack).build,
                member.type.actualType, module).replace(" ", ""))
    }

    @Test
    def void testInterfaceWithFailableReturn()
    {
        val idl = TestData.getGoodTestCase("interface-with-failable-return").parse

        val typeResolver = createTypeResolver

        val module = idl.modules.head
        val containingInterface = module.moduleComponents.filter(InterfaceDeclaration).head
        val operation = containingInterface.functions.head
        val returnedType = operation.returnedType

        assertEquals(
            "foo::Protobuf::TestCodec::DecodeFailable<foo::Protobuf::Failable_foo_Test_Uuid,BTC::Commons::CoreExtras::UUID>",
            ProtobufUtil.resolveDecode(typeResolver, new ParameterBundle.Builder().with(module.moduleStack).build,
                returnedType.actualType, containingInterface).replace(" ", ""))
    }
}
