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
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors
class VcxProjGenerator
{
    val ParameterBundle param_bundle
    val VSSolution vsSolution
    val Map<String, Set<VSSolution.ProjectReference>> protobuf_project_references
    val Set<VSSolution.ProjectReference> project_references

    val ProjectFileSet projectFileSet

    def generate(String project_name, IPath project_path)
    {
        val project_export_macro = GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER)
        val is_protobuf = (param_bundle.projectType == ProjectType.PROTOBUF)
        val is_server_runner = (param_bundle.projectType == ProjectType.SERVER_RUNNER)
        val is_test = (param_bundle.projectType == ProjectType.TEST)
        val is_proxy = (param_bundle.projectType == ProjectType.PROXY)
        val is_dispatcher = (param_bundle.projectType == ProjectType.DISPATCHER)
        val is_external_db_impl = (param_bundle.projectType == ProjectType.EXTERNAL_DB_IMPL)
        val project_guid = vsSolution.getVcxprojGUID(vsSolution.resolve(project_name, project_path))

        if (is_protobuf)
        {
            val protobuf_references = if (protobuf_project_references === null)
                    null
                else
                    protobuf_project_references.get(project_name)
            if (protobuf_references !== null)
            {
                project_references.addAll(protobuf_references)
            }
        }

        var prebuild_step = if (is_server_runner)
            {
                '''
                    @ECHO @SET PATH=%%PATH%%;$(CabBin);>$(TargetDir)«project_name».bat
                    @ECHO «project_name».exe --connection tcp://127.0.0.1:«Constants.DEFAULT_PORT» --ioc $(ProjectDir)etc\ServerFactory.xml >> $(TargetDir)«project_name».bat
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
            <ProjectGuid>{«project_guid»}</ProjectGuid>
            <Keyword>Win32Proj</Keyword>
          </PropertyGroup>
          <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
            <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
            <WholeProgramOptimization>true</WholeProgramOptimization>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
            <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
            <WholeProgramOptimization>true</WholeProgramOptimization>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
            <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
          </PropertyGroup>
          <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
            <ConfigurationType>«IF is_protobuf»StaticLibrary«ELSEIF is_server_runner»Application«ELSE»DynamicLibrary«ENDIF»</ConfigurationType>
            <PlatformToolset>v140</PlatformToolset>
          </PropertyGroup>
          <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
          <ImportGroup Label="ExtensionSettings">
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
          </ImportGroup>
          <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="PropertySheets">
            <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
            <Import Project="$(SolutionDir)\vsprops\modules.props" />
            «IF is_protobuf || is_proxy || is_dispatcher || is_server_runner»<Import Project="$(SolutionDir)\vsprops\protobuf_paths.props" />«ENDIF»
            «IF is_test»<Import Project="$(SolutionDir)\vsprops\unit_test.props" />«ENDIF»
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
              «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>_DEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <MinimalRebuild>true</MinimalRebuild>
              <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
              <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
              <PrecompiledHeader />
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
              <TargetMachine>MachineX86</TargetMachine>
              <LargeAddressAware>true</LargeAddressAware>
            </Link>
            «IF is_server_runner»
                <PreBuildEvent>
                  <Command>«prebuild_step»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'">
            <ClCompile>
              <Optimization>Disabled</Optimization>
              «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>_DEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
              <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
              <PrecompiledHeader>
              </PrecompiledHeader>
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
            </Link>
            «IF is_server_runner»
                <PreBuildEvent>
                  <Command>«prebuild_step»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
            <ClCompile>
              <Optimization>MaxSpeed</Optimization>
              <IntrinsicFunctions>true</IntrinsicFunctions>
              «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>NDEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
              <FunctionLevelLinking>true</FunctionLevelLinking>
              <PrecompiledHeader />
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
              <OptimizeReferences>true</OptimizeReferences>
              <EnableCOMDATFolding>true</EnableCOMDATFolding>
              <TargetMachine>MachineX86</TargetMachine>
              <LargeAddressAware>true</LargeAddressAware>
            </Link>
            «IF is_server_runner»
                <PreBuildEvent>
                  <Command>«prebuild_step»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
            <ClCompile>
              <Optimization>MaxSpeed</Optimization>
              <IntrinsicFunctions>true</IntrinsicFunctions>
              «IF is_external_db_impl»«disableSpecfificWarnings»«ENDIF»
              <PreprocessorDefinitions>NDEBUG;_WINDOWS;_USRDLL;«project_export_macro»_EXPORTS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
              <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
              <FunctionLevelLinking>true</FunctionLevelLinking>
              <PrecompiledHeader>
              </PrecompiledHeader>
              <WarningLevel>Level3</WarningLevel>
              <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
            </ClCompile>
            <Link>
              <GenerateDebugInformation>true</GenerateDebugInformation>
              <SubSystem>«IF is_server_runner»Console«ELSE»Windows«ENDIF»</SubSystem>
              <OptimizeReferences>true</OptimizeReferences>
              <EnableCOMDATFolding>true</EnableCOMDATFolding>
            </Link>
            «IF is_server_runner»
                <PreBuildEvent>
                  <Command>«prebuild_step»</Command>
                </PreBuildEvent>
            «ENDIF»
          </ItemDefinitionGroup>
          «IF !projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty»
              <ItemGroup>
                «FOR proto_file : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                    <Google_Protocol_Buffers Include="gen\«proto_file».proto" />
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «IF !(projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty && projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty)»
              <ItemGroup>
                «FOR cpp_file : projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP)»
                    <ClCompile Include="source\«cpp_file»" />
                «ENDFOR»
                «FOR dependency_file : projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP)»
                    <ClCompile Include="source\«dependency_file»" />
                «ENDFOR»
                «FOR pb_cc_file : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                    <ClCompile Include="gen\«pb_cc_file».pb.cc" />
                «ENDFOR»
                «FOR cxx_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <ClCompile Include="odb\«cxx_file»-odb.cxx" />
                    <ClCompile Include="odb\«cxx_file»-odb-mssql.cxx" />
                    <ClCompile Include="odb\«cxx_file»-odb-oracle.cxx" />
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «IF !(projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty && projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty)»
              <ItemGroup>
                «FOR header_file : projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP)»
                    <ClInclude Include="include\«header_file»" />
                «ENDFOR»
                «FOR pb_h_file : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                    <ClInclude Include="gen\«pb_h_file.pb.h»" />
                «ENDFOR»
                «FOR hxx_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <ClInclude Include="odb\«hxx_file.hxx»" />
                    <ClInclude Include="odb\«hxx_file»-odb.hxx" />
                    <ClInclude Include="odb\«hxx_file»-odb-mssql.hxx" />
                    <ClInclude Include="odb\«hxx_file»-odb-oracle.hxx" />
                «ENDFOR»
                «FOR odb_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <CustomBuild Include="odb\«odb_file.hxx»">
                      <Message>odb «odb_file.hxx»</Message>
                      <Command>"$(ODBExe)" --std c++11 -I $(SolutionDir).. -I $(CabInc) -I $(BoostInc) --multi-database dynamic --database common --database mssql --database oracle --generate-query --generate-prepared --generate-schema --schema-format embedded «ignoreGCCWarnings» --hxx-prologue "#include \"«Constants.FILE_NAME_ODB_TRAITS.hxx»\"" --output-dir .\odb odb\«odb_file.hxx»</Command>
                      <Outputs>odb\«odb_file»-odb.hxx;odb\«odb_file»-odb.ixx;odb\«odb_file»-odb.cxx;odb\«odb_file»-odb-mssql.hxx;odb\«odb_file»-odb-mssql.ixx;odb\«odb_file»-odb-mssql.cxx;odb\«odb_file»-odb-oracle.hxx;odb\«odb_file»-odb-oracle.ixx;odb\«odb_file»-odb-oracle.cxx;</Outputs>
                    </CustomBuild>
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «IF !projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty»
              <ItemGroup>
                «FOR odb_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                    <None Include="odb\«odb_file»-odb.ixx" />
                    <None Include="odb\«odb_file»-odb-mssql.ixx" />
                    <None Include="odb\«odb_file»-odb-oracle.ixx" />
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          «val effective_project_references = project_references.filter[it.projectName != project_name]»
          «IF !effective_project_references.empty»
              <ItemGroup>
                «FOR name : effective_project_references»
                    <ProjectReference Include="«vsSolution.getVcxProjPath(name)».vcxproj">
                      <Project>{«vsSolution.getVcxprojGUID(name)»}</Project>
                    </ProjectReference>
                «ENDFOR»
              </ItemGroup>
          «ENDIF»
          <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets" />
          <ImportGroup Label="ExtensionTargets">
            «IF is_protobuf»<Import Project="$(SolutionDir)vsprops\protobuf.targets" />«ENDIF»
          </ImportGroup>
        </Project>'''
    }

    def private String disableSpecfificWarnings()
    {
        '''<DisableSpecificWarnings>4068;4355;4800;4290;%(DisableSpecificWarnings)</DisableSpecificWarnings>'''
    }

    def private String ignoreGCCWarnings()
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
                    «FOR pb_h_file : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                        <ClCompile Include="gen\«pb_h_file.pb.h»">
                          <Filter>Header Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                    «FOR header_file : projectFileSet.getGroup(ProjectFileSet.HEADER_FILE_GROUP)»
                        <ClInclude Include="include\«header_file»">
                          <Filter>Header Files</Filter>
                        </ClInclude>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !(projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP).empty && projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty)»
                  <ItemGroup>
                    «FOR pb_cc_file : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                        <ClCompile Include="gen\«pb_cc_file».pb.cc">
                          <Filter>Source Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                    «FOR cpp_file : projectFileSet.getGroup(ProjectFileSet.CPP_FILE_GROUP)»
                        <ClCompile Include="source\«cpp_file»">
                          <Filter>Source Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP).empty»
                  <ItemGroup>
                    «FOR dependency_file : projectFileSet.getGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP)»
                        <ClCompile Include="source\«dependency_file»">
                          <Filter>Dependencies</Filter>
                        </ClCompile>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP).empty»
                  <ItemGroup>
                    «FOR proto_file : projectFileSet.getGroup(ProjectFileSet.PROTOBUF_FILE_GROUP)»
                        <Google_Protocol_Buffers Include="gen\«proto_file».proto">
                          <Filter>Protobuf Files</Filter>
                        </Google_Protocol_Buffers>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
              «IF !projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP).empty»
                  <ItemGroup>
                    «FOR odb_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <ClInclude Include="odb\«odb_file.hxx»">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                        <ClInclude Include="odb\«odb_file»-odb.hxx">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                        <ClInclude Include="odb\«odb_file»-odb-oracle.hxx">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                        <ClInclude Include="odb\«odb_file»-odb-mssql.hxx">
                          <Filter>ODB Files</Filter>
                        </ClInclude>
                    «ENDFOR»
                  </ItemGroup>
                  <ItemGroup>
                    «FOR odb_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <ClCompile Include="odb\«odb_file»-odb.cxx">
                          <Filter>ODB Files</Filter>
                        </ClCompile>
                        <ClCompile Include="odb\«odb_file»-odb-oracle.cxx">
                          <Filter>ODB Files</Filter>
                        </ClCompile>
                        <ClCompile Include="odb\«odb_file»-odb-mssql.cxx">
                          <Filter>ODB Files</Filter>
                        </ClCompile>
                    «ENDFOR»
                  </ItemGroup>
                  <ItemGroup>
                    «FOR odb_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <None Include="odb\«odb_file»-odb.ixx">
                          <Filter>ODB Files</Filter>
                        </None>
                        <None Include="odb\«odb_file»-odb-oracle.ixx">
                          <Filter>ODB Files</Filter>
                        </None>
                        <None Include="odb\«odb_file»-odb-mssql.ixx">
                          <Filter>ODB Files</Filter>
                        </None>
                    «ENDFOR»
                  </ItemGroup>
                  <ItemGroup>
                    «FOR odb_file : projectFileSet.getGroup(OdbConstants.ODB_FILE_GROUP)»
                        <CustomBuild Include="odb\«odb_file.hxx»">
                          <Filter>Header Files</Filter>
                        </CustomBuild>
                    «ENDFOR»
                  </ItemGroup>
              «ENDIF»
            </Project>
        '''
    }

    def generateVcxprojUser(ProjectType project_type)
    {
        // Please do NOT edit line indents in the code below (even though they
        // may look misplaced) unless you are fully aware of what you are doing!!!
        // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
        val path = if (project_type == ProjectType.TEST) "$(UnitTestLibraryPaths)" else "$(CabBin)"
        val command = if (project_type == ProjectType.TEST) "$(UnitTestRunner)" else "$(TargetPath)"
        val args = if (project_type ==
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
