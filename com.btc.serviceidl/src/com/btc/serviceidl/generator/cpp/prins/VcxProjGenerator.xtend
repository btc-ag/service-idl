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
package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import com.btc.serviceidl.util.Constants
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors
class VcxProjGenerator
{
    val ParameterBundle paramBundle
    val VSSolution vsSolution
    val Set<VSSolution.ProjectReference> projectReferences

    val ProjectFileSet projectFileSet

    def generate(String projectName, IPath projectPath)
    {
        val projectExportMacro = GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER)
        val isProtobuf = (paramBundle.projectType == ProjectType.PROTOBUF)
        val isServerRunner = (paramBundle.projectType == ProjectType.SERVER_RUNNER)
        val isTest = (paramBundle.projectType == ProjectType.TEST)
        val isProxy = (paramBundle.projectType == ProjectType.PROXY)
        val isDispatcher = (paramBundle.projectType == ProjectType.DISPATCHER)
        val isExternalDbImpl = (paramBundle.projectType == ProjectType.EXTERNAL_DB_IMPL)
        val projectGuid = vsSolution.getVcxprojGUID(vsSolution.resolve(projectName, projectPath))

        var prebuildStep = if (isServerRunner)
            {
                '''
                    @ECHO @SET PATH=%%PATH%%;$(CabBin);>$(TargetDir)«projectName».bat
                    @ECHO «projectName».exe --connection tcp://127.0.0.1:«Constants.DEFAULT_PORT» --ioc $(ProjectDir)etc\ServerFactory.xml >> $(TargetDir)«projectName».bat
                '''
            }

// Please do NOT edit line indents in the code below (even though they
// may look misplaced) unless you are fully aware of what you are doing!!!
// Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
        '''
        <?xml version="1.0" encoding="utf-8"?>
        <Project DefaultTargets="Build" ToolsVersion="14.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
          <ItemGroup Label="ProjectConfigurations">
            <ProjectConfiguration Include="Debug|Win32">
              <Configuration>Debug</Configuration>
              <Platform>Win32</Platform>
            </ProjectConfiguration>
            <ProjectConfiguration Include="Debug|x64">
              <Configuration>Debug</Configuration>
              <Platform>x64</Platform>
            </ProjectConfiguration>
            <ProjectConfiguration Include="Release|Win32">
              <Configuration>Release</Configuration>
              <Platform>Win32</Platform>
            </ProjectConfiguration>
            <ProjectConfiguration Include="Release|x64">
              <Configuration>Release</Configuration>
              <Platform>x64</Platform>
            </ProjectConfiguration>
          </ItemGroup>
          <PropertyGroup Label="Globals">
            <ProjectGuid>{«projectGuid»}</ProjectGuid>
            <Keyword>Win32Proj</Keyword>
          </PropertyGroup>
          <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
            <ConfigurationType>«IF isProtobuf»StaticLibrary«ELSEIF isServerRunner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
            <WholeProgramOptimization>true</WholeProgramOptimization>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
            <ConfigurationType>«IF isProtobuf»StaticLibrary«ELSEIF isServerRunner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
            <WholeProgramOptimization>true</WholeProgramOptimization>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
            <ConfigurationType>«IF isProtobuf»StaticLibrary«ELSEIF isServerRunner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
            <ConfigurationType>«IF isProtobuf»StaticLibrary«ELSEIF isServerRunner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
          </PropertyGroup>
          <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
          <ImportGroup Label="ExtensionSettings">
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF isProtobuf || isProxy || isDispatcher || isServerRunner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF isTest»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF isProtobuf || isProxy || isDispatcher || isServerRunner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF isTest»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF isProtobuf || isProxy || isDispatcher || isServerRunner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF isTest»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF isProtobuf || isProxy || isDispatcher || isServerRunner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF isTest»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
          </ImportGroup>
          <PropertyGroup Label="UserMacros" />
          <PropertyGroup>
            <_ProjectFileVersion>11.0.61030.0</_ProjectFileVersion>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
            <LinkIncremental>true</LinkIncremental>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
            <LinkIncremental>true</LinkIncremental>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
            <LinkIncremental>false</LinkIncremental>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
            <LinkIncremental>false</LinkIncremental>
          </PropertyGroup>
          <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
            <ClCompile>
              <Optimization>Disabled</Optimization>
              «IF isExternalDbImpl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>_DEBUG;_WINDOWS;_USRDLL;«projectExportMacro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <MinimalRebuild>true</MinimalRebuild>
              <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
              <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
              <PrecompiledHeader />
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF isServerRunner»Console«ELSE»Windows«ENDIF»</SubSystem>
              <TargetMachine>MachineX86</TargetMachine>
              <LargeAddressAware>true</LargeAddressAware>
            </Link>
            «IF isServerRunner»
                <PreBuildEvent>
                  <Command>«prebuildStep»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
            <ClCompile>
              <Optimization>Disabled</Optimization>
              «IF isExternalDbImpl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>_DEBUG;_WINDOWS;_USRDLL;«projectExportMacro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
              <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
              <PrecompiledHeader>
              </PrecompiledHeader>
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF isServerRunner»Console«ELSE»Windows«ENDIF»</SubSystem>
            </Link>
            «IF isServerRunner»
                <PreBuildEvent>
                  <Command>«prebuildStep»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
            <ClCompile>
              <Optimization>MaxSpeed</Optimization>
              <IntrinsicFunctions>true</IntrinsicFunctions>
              «IF isExternalDbImpl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>NDEBUG;_WINDOWS;_USRDLL;«projectExportMacro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
              <FunctionLevelLinking>true</FunctionLevelLinking>
              <PrecompiledHeader />
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF isServerRunner»Console«ELSE»Windows«ENDIF»</SubSystem>
              <OptimizeReferences>true</OptimizeReferences>
              <EnableCOMDATFolding>true</EnableCOMDATFolding>
              <TargetMachine>MachineX86</TargetMachine>
              <LargeAddressAware>true</LargeAddressAware>
            </Link>
            «IF isServerRunner»
                <PreBuildEvent>
                  <Command>«prebuildStep»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
            <ClCompile>
              <Optimization>MaxSpeed</Optimization>
              <IntrinsicFunctions>true</IntrinsicFunctions>
              «IF isExternalDbImpl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>NDEBUG;_WINDOWS;_USRDLL;«projectExportMacro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
              <FunctionLevelLinking>true</FunctionLevelLinking>
              <PrecompiledHeader>
              </PrecompiledHeader>
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF isServerRunner»Console«ELSE»Windows«ENDIF»</SubSystem>
              <OptimizeReferences>true</OptimizeReferences>
              <EnableCOMDATFolding>true</EnableCOMDATFolding>
            </Link>
            «IF isServerRunner»
                <PreBuildEvent>
                  <Command>«prebuildStep»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          «IF !projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty»
              <ItemGroup>
                «FOR protoFile : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                    <Google_Protocol_Buffers Include="gen\«protoFile».proto" />
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «IF !(projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty && projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty)»
              <ItemGroup>
                «FOR cppFile : projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP)»
                    <ClCompile Include="source\«cppFile»" />
                «ENDFOR»
                «FOR dependencyFile : projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP)»
                    <ClCompile Include="source\«dependencyFile»" />
                «ENDFOR»
                «FOR pbCcFile : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                    <ClCompile Include="gen\«pbCcFile».pb.cc" />
                «ENDFOR»
                «FOR cxxFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <ClCompile Include="odb\«cxxFile»-odb.cxx" />
                    <ClCompile Include="odb\«cxxFile»-odb-mssql.cxx" />
                    <ClCompile Include="odb\«cxxFile»-odb-oracle.cxx" />
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «IF !(projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty && projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty)»
              <ItemGroup>
                «FOR headerFile : projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP)»
                    <ClInclude Include="include\«headerFile»" />
                «ENDFOR»
                «FOR pbHFile : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                    <ClInclude Include="gen\«pbHFile.pb.h»" />
                «ENDFOR»
                «FOR hxxFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <ClInclude Include="odb\«hxxFile.hxx»" />
                    <ClInclude Include="odb\«hxxFile»-odb.hxx" />
                    <ClInclude Include="odb\«hxxFile»-odb-mssql.hxx" />
                    <ClInclude Include="odb\«hxxFile»-odb-oracle.hxx" />
                «ENDFOR»
                «FOR odbFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <CustomBuild Include="odb\«odbFile.hxx»">
                      <Message>odb «odbFile.hxx»</Message>
                      <Command>"$(ODBExe)" --std c++11 -I $(SolutionDir).. -I $(CabInc) -I $(BoostInc) --multi-database dynamic --database common --database mssql --database oracle --generate-query --generate-prepared --generate-schema --schema-format embedded «ignoreGCCWarnings» --hxx-prologue "#include \"«Constants.FILE_NAME_ODB_TRAITS.hxx»\"" --output-dir .\odb odb\«odbFile.hxx»</Command>
                      <Outputs>odb\«odbFile»-odb.hxx;odb\«odbFile»-odb.ixx;odb\«odbFile»-odb.cxx;odb\«odbFile»-odb-mssql.hxx;odb\«odbFile»-odb-mssql.ixx;odb\«odbFile»-odb-mssql.cxx;odb\«odbFile»-odb-oracle.hxx;odb\«odbFile»-odb-oracle.ixx;odb\«odbFile»-odb-oracle.cxx;</Outputs>
                    </CustomBuild>
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «IF !projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty»
              <ItemGroup>
                «FOR odbFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <None Include="odb\«odbFile»-odb.ixx" />
                    <None Include="odb\«odbFile»-odb-mssql.ixx" />
                    <None Include="odb\«odbFile»-odb-oracle.ixx" />
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «val effectiveProjectReferences = projectReferences.filter[it.projectName != projectName]»
          «IF !effectiveProjectReferences.empty»
              <ItemGroup>
                «FOR name : effectiveProjectReferences»
                    <ProjectReference Include="$(SolutionDir)«vsSolution.getVcxProjPath(name).toWindowsString».vcxproj">
                      <Project>{«vsSolution.getVcxprojGUID(name)»}</Project>
                    </ProjectReference>
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets" />
          <ImportGroup Label="ExtensionTargets">
            «IF isProtobuf»<Import Project="$(SolutionDir)vsprops\protobuf.targets" />«ENDIF»
          </ImportGroup>
        </Project>'''
    }

    private def String disableSpecfificWarnings()
    {
        '''<DisableSpecificWarnings>4068;4355;4800;4290;%(DisableSpecificWarnings)</DisableSpecificWarnings>'''
    }

    private def String ignoreGCCWarnings()
    {
        '''-x -Wno-unknown-pragmas -x -Wno-pragmas -x -Wno-literal-suffix -x -Wno-attributes'''
    }

    def generateVcxprojFilters()
    {
        // Please do NOT edit line indents in the code below (even though they
        // may look misplaced) unless you are fully aware of what you are doing!!!
        // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
        '''
            <?xml version="1.0" encoding="utf-8"?>
            <Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
              <ItemGroup>
                 «IF !projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP).empty || !projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty»
                     <Filter Include="Source Files">
                       <UniqueIdentifier>{4FC737F1-C7A5-4376-A066-2A32D752A2FF}</UniqueIdentifier>
                       <Extensions>cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx</Extensions>
                     </Filter>
                 «ENDIF»
                 «IF !(projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP).empty && projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty)»
                     <Filter Include="Header Files">
                       <UniqueIdentifier>{93995380-89BD-4b04-88EB-625FBE52EBFB}</UniqueIdentifier>
                       <Extensions>h;hpp;hxx;hm;inl;inc;xsd</Extensions>
                     </Filter>
                 «ENDIF»
                 «IF !projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP).empty»
                     <Filter Include="Dependencies">
                       <UniqueIdentifier>{0e47593f-5119-4a3e-a4ac-b88dba5ffd81}</UniqueIdentifier>
                     </Filter>
                 «ENDIF»
                 «IF !projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty»
                     <Filter Include="Protobuf Files">
                       <UniqueIdentifier>{6f3dd233-58fc-4467-a4cc-9ba5ef3b5517}</UniqueIdentifier>
                     </Filter>
                 «ENDIF»
                 «IF !projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty»
                     <Filter Include="ODB Files">
                       <UniqueIdentifier>{31ddc234-0d60-4695-be06-2c69510365ac}</UniqueIdentifier>
                     </Filter>
                 «ENDIF»
              </ItemGroup>
              «IF !(projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty)»
                  <ItemGroup>
                    «FOR pbHFile : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                        <ClCompile Include="gen\«pbHFile.pb.h»">
                          <Filter>Header Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                    «FOR headerFile : projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP)»
                        <ClInclude Include="include\«headerFile»">
                          <Filter>Header Files</Filter>
                        </ClInclude>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !(projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty)»
                  <ItemGroup>
                    «FOR pbCcFile : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                        <ClCompile Include="gen\«pbCcFile».pb.cc">
                          <Filter>Source Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                    «FOR cppFile : projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP)»
                        <ClCompile Include="source\«cppFile»">
                          <Filter>Source Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP).empty»
                  <ItemGroup>
                    «FOR dependencyFile : projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP)»
                        <ClCompile Include="source\«dependencyFile»">
                          <Filter>Dependencies</Filter>
                        </ClCompile>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty»
                  <ItemGroup>
                    «FOR protoFile : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                        <Google_Protocol_Buffers Include="gen\«protoFile».proto">
                          <Filter>Protobuf Files</Filter>
                        </Google_Protocol_Buffers>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty»
                  <ItemGroup>
                    «FOR odbFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <ClInclude Include="odb\«odbFile.hxx»">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                        <ClInclude Include="odb\«odbFile»-odb.hxx">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                        <ClInclude Include="odb\«odbFile»-odb-oracle.hxx">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                        <ClInclude Include="odb\«odbFile»-odb-mssql.hxx">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                    «ENDFOR»
                  </ItemGroup>
                  <ItemGroup>
                    «FOR odbFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <ClCompile Include="odb\«odbFile»-odb.cxx">
                          <Filter>ODB Files</Filter>
                        </ClCompile>
                        <ClCompile Include="odb\«odbFile»-odb-oracle.cxx">
                          <Filter>ODB Files</Filter>
                        </ClCompile>
                        <ClCompile Include="odb\«odbFile»-odb-mssql.cxx">
                          <Filter>ODB Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                  </ItemGroup>
                  <ItemGroup>
                    «FOR odbFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <None Include="odb\«odbFile»-odb.ixx">
                          <Filter>ODB Files</Filter>
                        </None>
                        <None Include="odb\«odbFile»-odb-oracle.ixx">
                          <Filter>ODB Files</Filter>
                        </None>
                        <None Include="odb\«odbFile»-odb-mssql.ixx">
                          <Filter>ODB Files</Filter>
                        </None>
                    «ENDFOR»
                  </ItemGroup>
                  <ItemGroup>
                    «FOR odbFile : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <CustomBuild Include="odb\«odbFile.hxx»">
                          <Filter>Header Files</Filter>
                        </CustomBuild>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
            </Project>
        '''
    }

    def generateVcxprojUser(ProjectType projectType)
    {
        // Please do NOT edit line indents in the code below (even though they
        // may look misplaced) unless you are fully aware of what you are doing!!!
        // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
        val path = if (projectType == ProjectType.TEST) "$(UnitTestLibraryPaths)" else "$(CabBin)"
        val command = if (projectType == ProjectType.TEST) "$(UnitTestRunner)" else "$(TargetPath)"
        val args = if (projectType ==
                ProjectType.
                    TEST) "$(UnitTestDefaultArguments)" else '''--connection tcp://127.0.0.1:«Constants.DEFAULT_PORT» --ioc $(ProjectDir)etc\ServerFactory.xml'''

        '''
            <?xml version="1.0" encoding="utf-8"?>
            <Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
              <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
                <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
                <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
                <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
                <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
                <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
              </PropertyGroup>
              <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
                <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
                <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
                <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
                <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
                <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
              </PropertyGroup>
              <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
                <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
                <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
                <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
                <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
                <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
              </PropertyGroup>
              <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
                <LocalDebuggerCommand>«command»</LocalDebuggerCommand>
                <LocalDebuggerCommandArguments>«args»</LocalDebuggerCommandArguments>
                <LocalDebuggerWorkingDirectory>$(TargetDir)</LocalDebuggerWorkingDirectory>
                <LocalDebuggerEnvironment>PATH=«path»</LocalDebuggerEnvironment>
                <DebuggerFlavor>WindowsLocalDebugger</DebuggerFlavor>
              </PropertyGroup>
            </Project>
        '''
    }
}
