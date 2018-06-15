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
package com.btc.serviceidl.tests.cmdline

import java.io.File
import org.junit.Test

import static org.junit.Assert.*
import java.io.BufferedReader
import java.io.InputStreamReader
import org.junit.Ignore
import com.btc.serviceidl.generator.Main
import java.util.Arrays
import java.nio.file.Files
import com.google.common.collect.Sets
import org.eclipse.core.runtime.Path

class CommandLineRunnerTest
{
    @Test
    def void testWithoutArgs()
    {
        val process = Runtime.getRuntime().exec("java com.btc.serviceidl.generator.Main")

        assertEquals(1, process.waitFor)
    }

    @Test
    def void testWithNonExistentInputFile()
    {
        val process = Runtime.getRuntime().exec("java com.btc.serviceidl.generator.Main Z:\\foo.bar")

        assertEquals(1, process.waitFor)
    }

    static val TEST_DATA_DIR = "src/com/btc/serviceidl/tests/testdata/";

    @Ignore("TODO check how to set the classpath such that this works from the test")
    @Test
    def void testWithValidInput()
    {
        val file = new File(TEST_DATA_DIR + "base.idl");
        System.out.println(file.absolutePath);
        val process = Runtime.getRuntime().exec("java com.btc.serviceidl.generator.Main " + file.absolutePath)

        val errorReader = new BufferedReader(new InputStreamReader(process.errorStream))
        var res = new String
        var String line = null
        while ((line = errorReader.readLine()) !== null)
        {
            res += line;
        }
        System.out.println(res);

        assertEquals(0, process.waitFor)
    }

    static def Iterable<File> listFilesRecursively(File base)
    {
        if (base.directory)
            base.listFiles.map[it.listFilesRecursively].flatten
        else
            Arrays.asList(base)
    }

    static def <T> assertSetEquals(Iterable<T> expected, Iterable<T> actual)
    {
        val expectedSet = expected.toSet
        val actualSet = actual.toSet

        val extra = Sets.difference(actualSet, expectedSet)
        val missing = Sets.difference(expectedSet, actualSet)

        val sizeComparisonInfo = if (expectedSet.size == actualSet.size)
                "same size but"
            else
                "different sizes: expected=" + expectedSet.size + ", actual=" + actualSet.size + ","
        assertTrue("Sets are different, " + sizeComparisonInfo + " missing elements: " + String.join(", ", missing.map [
            '"' + it.toString + '"'
        ].sort) + "; extra elements: " + String.join(", ", extra.map['"' + it.toString + '"'].sort),
            missing.empty && extra.empty)
    }

    static def assertExpectedFiles(Iterable<String> expected, java.nio.file.Path path)
    {
        val files = path.toFile.listFilesRecursively.map[new Path(it.toString.replace(path + File.separator, ""))]
        assertSetEquals(expected.map[new Path(it)], files)
    }

    @Test
    def void testWithValidInputInProcess()
    {
        val file = new File(TEST_DATA_DIR + "base.idl")
        val path = Files.createTempDirectory("test-gen")
        assertEquals(0, Main.mainBackend(Arrays.asList(file.absolutePath, "-outputPath", path.toString)))
        assertExpectedFiles(
            #["cpp/modules/BTC/Commons/Core/Common/BTC.Commons.Core.Common.vcxproj",
                "cpp/modules/BTC/Commons/Core/Common/BTC.Commons.Core.Common.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/Common/include/Types.h",
                "cpp/modules/BTC/Commons/Core/Common/include/btc_commons_core_common_export.h",
                "cpp/modules/BTC/Commons/Core/Common/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/Common/source/Types.cpp",
                "cpp/modules/BTC/Commons/Core/Protobuf/BTC.Commons.Core.Protobuf.vcxproj",
                "cpp/modules/BTC/Commons/Core/Protobuf/BTC.Commons.Core.Protobuf.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/Protobuf/gen/Types.proto",
                "cpp/modules/BTC/Commons/Core/Protobuf/include/TypesCodec.h",
                "cpp/modules/BTC/Commons/Core/Protobuf/include/btc_commons_core_protobuf_export.h",
                "cpp/modules/BTC/Commons/Core/Protobuf/source/Dependencies.cpp",
                "dotnet/BTC/Commons/Core/Common/BTC.Commons.Core.Common.csproj",
                "dotnet/BTC/Commons/Core/Common/Properties/AssemblyInfo.cs", "dotnet/BTC/Commons/Core/Common/Types.cs",
                "dotnet/BTC/Commons/Core/Protobuf/BTC.Commons.Core.Protobuf.csproj",
                "dotnet/BTC/Commons/Core/Protobuf/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/Protobuf/TypesCodec.cs", "dotnet/BTC/Commons/Core/Protobuf/gen/Types.proto",
                "dotnet/BTC/Commons/Core/Protobuf/packages.config", "dotnet/BTC/Commons/Core/Protobuf/paket.references",
                "dotnet/base.sln", "dotnet/paket.dependencies", "java/btc.commons.core/pom.xml",
                "java/btc.commons.core/src/main/java/com/btc/commons/core/common/InvalidArgumentException.java",
                "java/btc.commons.core/src/main/java/com/btc/commons/core/common/ServiceFaultHandlerFactory.java",
                "java/btc.commons.core/src/main/java/com/btc/commons/core/protobuf/TypesCodec.java",
                "java/btc.commons.core/src/main/proto/Types.proto"], path)
    }

    @Test
    def void testWithValidInputWithWarningsInProcess()
    {
        val file = new File(TEST_DATA_DIR + "failable.idl")
        val path = Files.createTempDirectory("test-gen")
        assertEquals(0, Main.mainBackend(Arrays.asList(file.absolutePath, "-outputPath", path.toString)))
        // TODO check output for Warnings!
        assertExpectedFiles(
            #["cpp/modules/BTC/Commons/Core/Dispatcher/BTC.Commons.Core.Dispatcher.vcxproj",
                "cpp/modules/BTC/Commons/Core/Dispatcher/BTC.Commons.Core.Dispatcher.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/Dispatcher/include/CFooDispatcher.h",
                "cpp/modules/BTC/Commons/Core/Dispatcher/include/btc_commons_core_dispatcher_export.h",
                "cpp/modules/BTC/Commons/Core/Dispatcher/source/CFooDispatcher.cpp",
                "cpp/modules/BTC/Commons/Core/Dispatcher/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/Impl/BTC.Commons.Core.Impl.vcxproj",
                "cpp/modules/BTC/Commons/Core/Impl/BTC.Commons.Core.Impl.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/Impl/include/CFooImpl.h",
                "cpp/modules/BTC/Commons/Core/Impl/include/btc_commons_core_impl_export.h",
                "cpp/modules/BTC/Commons/Core/Impl/source/CFooImpl.cpp",
                "cpp/modules/BTC/Commons/Core/Impl/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/Protobuf/BTC.Commons.Core.Protobuf.vcxproj",
                "cpp/modules/BTC/Commons/Core/Protobuf/BTC.Commons.Core.Protobuf.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/Protobuf/gen/Foo.proto",
                "cpp/modules/BTC/Commons/Core/Protobuf/include/FooCodec.h",
                "cpp/modules/BTC/Commons/Core/Protobuf/include/btc_commons_core_protobuf_export.h",
                "cpp/modules/BTC/Commons/Core/Protobuf/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/Proxy/BTC.Commons.Core.Proxy.vcxproj",
                "cpp/modules/BTC/Commons/Core/Proxy/BTC.Commons.Core.Proxy.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/Proxy/include/CFooProxy.h",
                "cpp/modules/BTC/Commons/Core/Proxy/include/btc_commons_core_proxy_export.h",
                "cpp/modules/BTC/Commons/Core/Proxy/source/CFooProxy.cpp",
                "cpp/modules/BTC/Commons/Core/Proxy/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/ServerRunner/BTC.Commons.Core.ServerRunner.Foo.vcxproj",
                "cpp/modules/BTC/Commons/Core/ServerRunner/BTC.Commons.Core.ServerRunner.Foo.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/ServerRunner/BTC.Commons.Core.ServerRunner.Foo.vcxproj.user",
                "cpp/modules/BTC/Commons/Core/ServerRunner/etc/ServerFactory.xml",
                "cpp/modules/BTC/Commons/Core/ServerRunner/include/btc_commons_core_serverrunner_export.h",
                "cpp/modules/BTC/Commons/Core/ServerRunner/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/ServerRunner/source/FooServerRunner.cpp",
                "cpp/modules/BTC/Commons/Core/ServiceAPI/BTC.Commons.Core.ServiceAPI.vcxproj",
                "cpp/modules/BTC/Commons/Core/ServiceAPI/BTC.Commons.Core.ServiceAPI.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/ServiceAPI/include/IFoo.h",
                "cpp/modules/BTC/Commons/Core/ServiceAPI/include/btc_commons_core_serviceapi_export.h",
                "cpp/modules/BTC/Commons/Core/ServiceAPI/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/ServiceAPI/source/IFoo.cpp",
                "cpp/modules/BTC/Commons/Core/Test/BTC.Commons.Core.Test.vcxproj",
                "cpp/modules/BTC/Commons/Core/Test/BTC.Commons.Core.Test.vcxproj.filters",
                "cpp/modules/BTC/Commons/Core/Test/BTC.Commons.Core.Test.vcxproj.user",
                "cpp/modules/BTC/Commons/Core/Test/include/btc_commons_core_test_export.h",
                "cpp/modules/BTC/Commons/Core/Test/source/Dependencies.cpp",
                "cpp/modules/BTC/Commons/Core/Test/source/FooTest.cpp",
                "dotnet/BTC/Commons/Core/ClientConsole/App.config",
                "dotnet/BTC/Commons/Core/ClientConsole/BTC.Commons.Core.ClientConsole.csproj",
                "dotnet/BTC/Commons/Core/ClientConsole/Program.cs",
                "dotnet/BTC/Commons/Core/ClientConsole/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/ClientConsole/btc.commons.core.clientconsole.log4net.config",
                "dotnet/BTC/Commons/Core/ClientConsole/packages.config",
                "dotnet/BTC/Commons/Core/ClientConsole/paket.references",
                "dotnet/BTC/Commons/Core/Dispatcher/BTC.Commons.Core.Dispatcher.csproj",
                "dotnet/BTC/Commons/Core/Dispatcher/FooDispatcher.cs",
                "dotnet/BTC/Commons/Core/Dispatcher/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/Dispatcher/packages.config",
                "dotnet/BTC/Commons/Core/Dispatcher/paket.references",
                "dotnet/BTC/Commons/Core/Impl/BTC.Commons.Core.Impl.csproj", "dotnet/BTC/Commons/Core/Impl/FooImpl.cs",
                "dotnet/BTC/Commons/Core/Impl/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/Protobuf/BTC.Commons.Core.Protobuf.csproj",
                "dotnet/BTC/Commons/Core/Protobuf/FooCodec.cs",
                "dotnet/BTC/Commons/Core/Protobuf/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/Protobuf/gen/Foo.proto", "dotnet/BTC/Commons/Core/Protobuf/packages.config",
                "dotnet/BTC/Commons/Core/Protobuf/paket.references",
                "dotnet/BTC/Commons/Core/Proxy/BTC.Commons.Core.Proxy.csproj",
                "dotnet/BTC/Commons/Core/Proxy/FooData.cs", "dotnet/BTC/Commons/Core/Proxy/FooProtocol.cs",
                "dotnet/BTC/Commons/Core/Proxy/FooProxy.cs", "dotnet/BTC/Commons/Core/Proxy/FooProxyFactory.cs",
                "dotnet/BTC/Commons/Core/Proxy/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/Proxy/packages.config", "dotnet/BTC/Commons/Core/Proxy/paket.references",
                "dotnet/BTC/Commons/Core/ServerRunner/App.config",
                "dotnet/BTC/Commons/Core/ServerRunner/BTC.Commons.Core.ServerRunner.csproj",
                "dotnet/BTC/Commons/Core/ServerRunner/Program.cs",
                "dotnet/BTC/Commons/Core/ServerRunner/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/ServerRunner/btc.commons.core.serverrunner.log4net.config",
                "dotnet/BTC/Commons/Core/ServerRunner/packages.config",
                "dotnet/BTC/Commons/Core/ServerRunner/paket.references",
                "dotnet/BTC/Commons/Core/ServiceAPI/BTC.Commons.Core.ServiceAPI.csproj",
                "dotnet/BTC/Commons/Core/ServiceAPI/FooConst.cs", "dotnet/BTC/Commons/Core/ServiceAPI/IFoo.cs",
                "dotnet/BTC/Commons/Core/ServiceAPI/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/Test/BTC.Commons.Core.Test.csproj",
                "dotnet/BTC/Commons/Core/Test/FooImplTest.cs", "dotnet/BTC/Commons/Core/Test/FooServerRegistration.cs",
                "dotnet/BTC/Commons/Core/Test/FooTest.cs", "dotnet/BTC/Commons/Core/Test/FooZeroMQIntegrationTest.cs",
                "dotnet/BTC/Commons/Core/Test/Properties/AssemblyInfo.cs",
                "dotnet/BTC/Commons/Core/Test/packages.config", "dotnet/BTC/Commons/Core/Test/paket.references",
                "dotnet/failable.sln", "dotnet/paket.dependencies", "java/btc.commons.core.foo/pom.xml",
                "java/btc.commons.core.foo/src/main/java/com/btc/commons/core/foo/dispatcher/FooDispatcher.java",
                "java/btc.commons.core.foo/src/main/java/com/btc/commons/core/foo/impl/FooImpl.java",
                "java/btc.commons.core.foo/src/main/java/com/btc/commons/core/foo/protobuf/FooCodec.java",
                "java/btc.commons.core.foo/src/main/java/com/btc/commons/core/foo/proxy/FooProxy.java",
                "java/btc.commons.core.foo/src/main/java/com/btc/commons/core/foo/proxy/FooProxyFactory.java",
                "java/btc.commons.core.foo/src/main/java/com/btc/commons/core/foo/serviceapi/FooServiceFaultHandlerFactory.java",
                "java/btc.commons.core.foo/src/main/java/com/btc/commons/core/foo/serviceapi/IFoo.java",
                "java/btc.commons.core.foo/src/main/proto/Foo.proto",
                "java/btc.commons.core.foo/src/test/java/com/btc/commons/core/foo/clientconsole/Program.java",
                "java/btc.commons.core.foo/src/test/java/com/btc/commons/core/foo/serverrunner/FooServerRunner.java",
                "java/btc.commons.core.foo/src/test/java/com/btc/commons/core/foo/serverrunner/Program.java",
                "java/btc.commons.core.foo/src/test/java/com/btc/commons/core/foo/test/FooImplTest.java",
                "java/btc.commons.core.foo/src/test/java/com/btc/commons/core/foo/test/FooTest.java",
                "java/btc.commons.core.foo/src/test/java/com/btc/commons/core/foo/test/FooZeroMQIntegrationTest.java",
                "java/btc.commons.core.foo/src/test/resources/ServerRunnerBeans.xml",
                "java/btc.commons.core.foo/src/test/resources/log4j.ClientConsole.properties",
                "java/btc.commons.core.foo/src/test/resources/log4j.ServerRunner.properties",
                "java/btc.commons.core.foo/src/test/resources/log4j.Test.properties"], path)
    }

    @Test
    def void testWithImport()
    {
        val derivedFile = new File(TEST_DATA_DIR + "import-derived.idl")
        val importedFile = new File(TEST_DATA_DIR + "import-imported.idl")
        val path = Files.createTempDirectory("test-gen")
        assertEquals(0, Main.mainBackend(
            Arrays.asList(derivedFile.absolutePath, importedFile.absolutePath, "-outputPath", path.toString)))

        // TODO currently a solution file is generated for each file specified on the command line. Is this sensible?
        // TODO ... but only one paket.dependencies file, probably it is overwritten by the second solution generation
        assertExpectedFiles(
            #["cpp/modules/Derived/Common/BTC.PRINS.Derived.Common.vcxproj",
                "cpp/modules/Derived/Common/BTC.PRINS.Derived.Common.vcxproj.filters",
                "cpp/modules/Derived/Common/include/Types.h",
                "cpp/modules/Derived/Common/include/btc_prins_derived_common_export.h",
                "cpp/modules/Derived/Common/source/Dependencies.cpp", "cpp/modules/Derived/Common/source/Types.cpp",
                "cpp/modules/Derived/Protobuf/BTC.PRINS.Derived.Protobuf.vcxproj",
                "cpp/modules/Derived/Protobuf/BTC.PRINS.Derived.Protobuf.vcxproj.filters",
                "cpp/modules/Derived/Protobuf/gen/Types.proto", "cpp/modules/Derived/Protobuf/include/TypesCodec.h",
                "cpp/modules/Derived/Protobuf/include/btc_prins_derived_protobuf_export.h",
                "cpp/modules/Derived/Protobuf/source/Dependencies.cpp",
                "cpp/modules/Imported/Common/BTC.PRINS.Imported.Common.vcxproj",
                "cpp/modules/Imported/Common/BTC.PRINS.Imported.Common.vcxproj.filters",
                "cpp/modules/Imported/Common/include/Types.h",
                "cpp/modules/Imported/Common/include/btc_prins_imported_common_export.h",
                "cpp/modules/Imported/Common/source/Dependencies.cpp", "cpp/modules/Imported/Common/source/Types.cpp",
                "cpp/modules/Imported/Protobuf/BTC.PRINS.Imported.Protobuf.vcxproj",
                "cpp/modules/Imported/Protobuf/BTC.PRINS.Imported.Protobuf.vcxproj.filters",
                "cpp/modules/Imported/Protobuf/gen/Types.proto", "cpp/modules/Imported/Protobuf/include/TypesCodec.h",
                "cpp/modules/Imported/Protobuf/include/btc_prins_imported_protobuf_export.h",
                "cpp/modules/Imported/Protobuf/source/Dependencies.cpp",
                "dotnet/Derived/Common/BTC.PRINS.Derived.Common.csproj",
                "dotnet/Derived/Common/Properties/AssemblyInfo.cs", "dotnet/Derived/Common/Types.cs",
                "dotnet/Derived/Protobuf/BTC.PRINS.Derived.Protobuf.csproj",
                "dotnet/Derived/Protobuf/Properties/AssemblyInfo.cs", "dotnet/Derived/Protobuf/TypesCodec.cs",
                "dotnet/Derived/Protobuf/gen/Types.proto", "dotnet/Derived/Protobuf/packages.config",
                "dotnet/Derived/Protobuf/paket.references", "dotnet/Imported/Common/BTC.PRINS.Imported.Common.csproj",
                "dotnet/Imported/Common/Properties/AssemblyInfo.cs", "dotnet/Imported/Common/Types.cs",
                "dotnet/Imported/Protobuf/BTC.PRINS.Imported.Protobuf.csproj",
                "dotnet/Imported/Protobuf/Properties/AssemblyInfo.cs", "dotnet/Imported/Protobuf/TypesCodec.cs",
                "dotnet/Imported/Protobuf/gen/Types.proto", "dotnet/Imported/Protobuf/packages.config",
                "dotnet/Imported/Protobuf/paket.references", "dotnet/import-derived.sln", "dotnet/import-imported.sln",
                "dotnet/paket.dependencies", "java/btc.prins.derived/pom.xml",
                "java/btc.prins.derived/src/main/java/com/btc/prins/derived/common/ServiceFaultHandlerFactory.java",
                "java/btc.prins.derived/src/main/java/com/btc/prins/derived/common/StructureReferencingImport.java",
                "java/btc.prins.derived/src/main/java/com/btc/prins/derived/protobuf/TypesCodec.java",
                "java/btc.prins.derived/src/main/proto/Types.proto", "java/btc.prins.imported/pom.xml",
                "java/btc.prins.imported/src/main/java/com/btc/prins/imported/common/ServiceFaultHandlerFactory.java",
                "java/btc.prins.imported/src/main/java/com/btc/prins/imported/protobuf/TypesCodec.java",
                "java/btc.prins.imported/src/main/proto/Types.proto"], path)
    }

}
