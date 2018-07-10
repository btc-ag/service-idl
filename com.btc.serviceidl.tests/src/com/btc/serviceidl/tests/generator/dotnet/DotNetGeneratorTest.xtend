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
package com.btc.serviceidl.tests.generator.dotnet

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.generator.AbstractGeneratorTest
import com.btc.serviceidl.tests.testdata.TestData
import java.util.Arrays
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith

import static com.btc.serviceidl.tests.TestExtensions.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class DotNetGeneratorTest extends AbstractGeneratorTest
{
    @Test
    def void testBasicServiceApi()
    {
        val fileCount = 5
        val baseDirectory = ArtifactNature.DOTNET.label + "Infrastructure/ServiceHost/Demo/API/ServiceAPI/"
        val directory = baseDirectory
        val contents = #{ArtifactNature.DOTNET.label + "__synthetic0.sln" -> '''
            
            Microsoft Visual Studio Solution File, Format Version 12.00
            # Visual Studio 14
            VisualStudioVersion = 14.0.25420.1
            MinimumVisualStudioVersion = 10.0.40219.1
            Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI", "Infrastructure\ServiceHost\Demo\API\ServiceAPI\BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI.csproj", "{9492E992-0B76-3834-A485-8F5D7175DAE7}"
            EndProject
            Global
                GlobalSection(SolutionConfigurationPlatforms) = preSolution
                    Debug|Any CPU = Debug|Any CPU
                    Release|Any CPU = Release|Any CPU
                EndGlobalSection
                GlobalSection(ProjectConfigurationPlatforms) = postSolution
                {9492E992-0B76-3834-A485-8F5D7175DAE7}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
                {9492E992-0B76-3834-A485-8F5D7175DAE7}.Debug|Any CPU.Build.0 = Debug|Any CPU
                {9492E992-0B76-3834-A485-8F5D7175DAE7}.Release|Any CPU.ActiveCfg = Release|Any CPU
                {9492E992-0B76-3834-A485-8F5D7175DAE7}.Release|Any CPU.Build.0 = Release|Any CPU
                EndGlobalSection
                GlobalSection(SolutionProperties) = preSolution
                    HideSolutionNode = FALSE
                EndGlobalSection
            EndGlobal
        ''', directory + "IKeyValueStore.cs" -> '''
            namespace BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI
            {
               public interface IKeyValueStore
               {
               }
            }
        ''', directory + "KeyValueStoreConst.cs" -> '''
            using System;
            
            namespace BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI
            {
               public static class KeyValueStoreConst
               {
                  public static readonly Guid typeGuid = new Guid("384E277A-C343-4F37-B910-C2CE6B37FC8E");
                  public static readonly string typeName = typeof(BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI.IKeyValueStore).FullName;
               }
            }
        ''', baseDirectory + "BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI.csproj" -> '''
            <?xml version="1.0" encoding="utf-8"?>
            <Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
              <PropertyGroup>
                <ProjectGuid>{9492E992-0B76-3834-A485-8F5D7175DAE7}</ProjectGuid>
                <OutputType>Library</OutputType>
                <RootNamespace>BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI</RootNamespace>
                <AssemblyName>BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI</AssemblyName>
                <TargetFrameworkVersion>v4.6</TargetFrameworkVersion>
                <TargetFrameworkProfile />
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
                <DebugSymbols>true</DebugSymbols>
                <DebugType>full</DebugType>
                <Optimize>false</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>DEBUG;TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
                <DebugType>pdbonly</DebugType>
                <Optimize>true</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|Win32' ">
                <DebugSymbols>true</DebugSymbols>
                <DebugType>full</DebugType>
                <Optimize>false</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>DEBUG;TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|Win32' ">
                <DebugType>pdbonly</DebugType>
                <Optimize>true</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|x64' ">
                <DebugSymbols>true</DebugSymbols>
                <DebugType>full</DebugType>
                <Optimize>false</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>DEBUG;TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|x64' ">
                <DebugType>pdbonly</DebugType>
                <Optimize>true</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <ItemGroup>
                <Reference Include="System">
                  <SpecificVersion>False</SpecificVersion>
                  <HintPath>$(SolutionDir)..\lib\AnyCPU\Release\System.dll</HintPath>
                </Reference>
              </ItemGroup>
              <ItemGroup>
                <Compile Include="IKeyValueStore.cs" />
                <Compile Include="KeyValueStoreConst.cs" />
                <Compile Include="Properties\AssemblyInfo.cs" />
              </ItemGroup>
            
              <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
              <!-- To modify your build process, add your task inside one of the targets below and uncomment it. 
                   Other similar extension points exist, see Microsoft.Common.targets.
              <Target Name="BeforeBuild">
              </Target>
              <Target Name="AfterBuild">
              </Target>
              -->
            </Project>
        ''', baseDirectory + "Properties/AssemblyInfo.cs" -> '''
            using System.Reflection;
            using System.Runtime.CompilerServices;
            using System.Runtime.InteropServices;
            
            // General Information about an assembly is controlled through the following 
            // set of attributes. Change these attribute values to modify the information
            // associated with an assembly.
            [assembly: AssemblyTitle("BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI")]
            [assembly: AssemblyDescription("")]
            [assembly: AssemblyConfiguration("")]
            [assembly: AssemblyProduct("BTC.PRINS.Infrastructure.ServiceHost.Demo.API.ServiceAPI")]
            [assembly: AssemblyCompany("BTC Business Technology Consulting AG")]
            [assembly: AssemblyCopyright("Copyright (C) BTC Business Technology Consulting AG 2018")]
            [assembly: AssemblyTrademark("")]
            [assembly: AssemblyCulture("")]
            
            // Setting ComVisible to false makes the types in this assembly not visible 
            // to COM components.  If you need to access a type in this assembly from 
            // COM, set the ComVisible attribute to true on that type.
            [assembly: ComVisible(false)]
            
            // The following GUID is for the ID of the typelib if this project is exposed to COM
            [assembly: Guid("801100a3-a556-3742-93ca-fe54049a7b3e")]        
        '''}

        checkGenerators(TestData.basic, setOf(ProjectType.SERVICE_API), fileCount, contents)
    }

    @Test
    def void testBasicProtobufCSProjFile()
    {
        val fileCount = 19
        val baseDirectory = ArtifactNature.DOTNET.label + "Infrastructure/ServiceHost/Demo/API/Protobuf/"
        val contents = #{baseDirectory + "BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf.csproj" -> '''
            <?xml version="1.0" encoding="utf-8"?>
            <Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
              <PropertyGroup>
                <ProjectGuid>{ABD62783-C17A-3EAA-8C93-FE69A650E4DD}</ProjectGuid>
                <OutputType>Library</OutputType>
                <RootNamespace>BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf</RootNamespace>
                <AssemblyName>BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Protobuf</AssemblyName>
                <TargetFrameworkVersion>v4.6</TargetFrameworkVersion>
                <TargetFrameworkProfile />
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
                <DebugSymbols>true</DebugSymbols>
                <DebugType>full</DebugType>
                <Optimize>false</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>DEBUG;TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
                <DebugType>pdbonly</DebugType>
                <Optimize>true</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|Win32' ">
                <DebugSymbols>true</DebugSymbols>
                <DebugType>full</DebugType>
                <Optimize>false</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>DEBUG;TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|Win32' ">
                <DebugType>pdbonly</DebugType>
                <Optimize>true</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|x64' ">
                <DebugSymbols>true</DebugSymbols>
                <DebugType>full</DebugType>
                <Optimize>false</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>DEBUG;TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|x64' ">
                <DebugType>pdbonly</DebugType>
                <Optimize>true</Optimize>
                <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
                <DefineConstants>TRACE</DefineConstants>
                <ErrorReport>prompt</ErrorReport>
                <WarningLevel>4</WarningLevel>
                <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
              </PropertyGroup>
              <ItemGroup>
                <Reference Include="System.Reflection">
                  <SpecificVersion>False</SpecificVersion>
                  <HintPath>$(SolutionDir)..\lib\AnyCPU\Release\System.Reflection.dll</HintPath>
                </Reference>
                <Reference Include="System.Linq">
                  <SpecificVersion>False</SpecificVersion>
                  <HintPath>$(SolutionDir)..\lib\AnyCPU\Release\System.Linq.dll</HintPath>
                </Reference>
                <Reference Include="System">
                  <SpecificVersion>False</SpecificVersion>
                  <HintPath>$(SolutionDir)..\lib\AnyCPU\Release\System.dll</HintPath>
                </Reference>
                <Reference Include="System.Threading.Tasks">
                  <SpecificVersion>False</SpecificVersion>
                  <HintPath>$(SolutionDir)..\lib\AnyCPU\Release\System.Threading.Tasks.dll</HintPath>
                </Reference>
                <Reference Include="Google.ProtocolBuffers.Serialization">
                  <HintPath>$(SolutionDir)packages\Google.ProtocolBuffers\lib\net40\Google.ProtocolBuffers.Serialization.dll</HintPath>
                </Reference>                
                <Reference Include="Google.ProtocolBuffers">
                  <HintPath>$(SolutionDir)packages\Google.ProtocolBuffers\lib\net40\Google.ProtocolBuffers.dll</HintPath>
                </Reference>                
              </ItemGroup>
              <ItemGroup>
                <Compile Include="Types.cs" />
                <Compile Include="DemoX.cs" />
                <Compile Include="ServiceFaultHandling.cs" />
                <Compile Include="TypesCodec.cs" />
                <Compile Include="DemoXServiceFaultHandling.cs" />
                <Compile Include="DemoXCodec.cs" />
                  <Compile Include="Properties\AssemblyInfo.cs" />
              </ItemGroup>
              <ItemGroup>
                <ProjectReference Include="$(SolutionDir)Infrastructure\ServiceHost\Demo\API\Common\BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Common.csproj">
                  <Project>{AD599B77-55B0-3DE4-8CF0-2D96A3B65830}</Project>
                  <Name>BTC.PRINS.Infrastructure.ServiceHost.Demo.API.Common</Name>
                </ProjectReference>
              </ItemGroup>
              <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
              <PropertyGroup>
                <PreBuildEvent>
                $(SolutionDir)\\packages\\Google.ProtocolBuffers\\tools\\protoc.exe --include_imports --proto_path=$(SolutionDir) --descriptor_set_out=$(ProjectDir)gen\Types.protobin $(SolutionDir)/Infrastructure/ServiceHost/Demo/API/Protobuf/gen/Types.proto
                $(SolutionDir)\\packages\\Google.ProtocolBuffers\\tools\\Protogen.exe -output_directory=$(ProjectDir) $(ProjectDir)gen\Types.protobin
                $(SolutionDir)\\packages\\Google.ProtocolBuffers\\tools\\protoc.exe --include_imports --proto_path=$(SolutionDir) --descriptor_set_out=$(ProjectDir)gen\DemoX.protobin $(SolutionDir)/Infrastructure/ServiceHost/Demo/API/Protobuf/gen/DemoX.proto
                $(SolutionDir)\\packages\\Google.ProtocolBuffers\\tools\\Protogen.exe -output_directory=$(ProjectDir) $(ProjectDir)gen\DemoX.protobin
                </PreBuildEvent>
              </PropertyGroup>
              <!-- To modify your build process, add your task inside one of the targets below and uncomment it. 
                   Other similar extension points exist, see Microsoft.Common.targets.
              <Target Name="BeforeBuild">
              </Target>
              <Target Name="AfterBuild">
              </Target>
              -->
            </Project>
        '''}

        checkGenerators(TestData.full, setOf(ProjectType.SERVICE_API, ProjectType.COMMON, ProjectType.PROTOBUF),
            fileCount, contents)
    }

    def void checkGenerators(CharSequence input, Set<ProjectType> projectTypes, int fileCount,
        Map<String, String> contents)
    {
        checkGenerators(input, new HashSet<ArtifactNature>(Arrays.asList(ArtifactNature.DOTNET)), projectTypes,
            null, fileCount, contents)
    }
}
