/**
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package com.btc.serviceidl.generator.cpp.cmake

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.ExternalDependency
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import java.util.Collections
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

@Accessors(NONE)
class CMakeProjectFileGenerator
{
    val IFileSystemAccess fileSystemAccess
    val ITargetVersionProvider targetVersionProvider
    val Iterable<ExternalDependency> externalDependencies
    val Iterable<IProjectReference> projectReferences

    val ProjectFileSet projectFileSet

    val ProjectType projectType
    val IPath projectPath
    val String projectName

    def generate()
    {
        fileSystemAccess.generateFile(
            projectPath.append("build").append("make.cmakeset").toString,
            ArtifactNature.CPP.label,
            generateCMakeSet().toString
        )
        fileSystemAccess.generateFile(
            projectPath.append("build").append("CMakeLists.txt").toString,
            ArtifactNature.CPP.label,
            generateCMakeLists().toString
        )
        if (CMakeGenerator.getCmakeTargetType(projectType) == "SHARED_LIB")
        {
            fileSystemAccess.generateFile(
                projectPath.append("res").append("resource.h").toString,
                ArtifactNature.CPP.label,
                generateResourceHeader().toString
            )
            fileSystemAccess.generateFile(
                projectPath.append("res").append("version.rc").toString,
                ArtifactNature.CPP.label,
                generateVersionResource().toString
            )
        }
    }

    private def getMyProjectReferences()
    {
        projectReferences.downcast
    }

    static def private downcast(extension Iterable<IProjectReference> set)
    {
        set.map[it as CMakeProjectSet.ProjectReference].toSet
    }

    private def generateCMakeLists()
    {
        new CMakeGenerator(
            targetVersionProvider,
            externalDependencies,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateCMakeLists(projectName, projectPath, projectType)
    }

    private def generateCMakeSet()
    {
        new CMakeGenerator(
            targetVersionProvider,
            externalDependencies,
            myProjectReferences,
            projectFileSet.unmodifiableView
        ).generateCMakeSet(projectName, projectPath)
    }

    private def generateResourceHeader()
    {
        '''
            //{{NO_DEPENDENCIES}}
            // Microsoft Visual C++ generated include file.
            // Used by version.rc
            //
            #define IDR_VERSION2 101
            
            // Next default values for new objects
            //
            #ifdef APSTUDIO_INVOKED
            #ifndef APSTUDIO_READONLY_SYMBOLS
            #define _APS_NEXT_RESOURCE_VALUE 102
            #define _APS_NEXT_COMMAND_VALUE 40001
            #define _APS_NEXT_CONTROL_VALUE 1001
            #define _APS_NEXT_SYMED_VALUE 101
            #endif
            #endif
        '''
    }

    private def generateVersionResource()
    {
        val relativeBasePath = String.join("/", Collections.nCopies(projectPath.segmentCount + 1, ".."))
        
        '''
            // Microsoft Visual C++ generated resource script.
            //
            #include "resource.h"
            
            #define APSTUDIO_READONLY_SYMBOLS
            /////////////////////////////////////////////////////////////////////////////
            //
            // Generated from the TEXTINCLUDE 2 resource.
            //
            #include "windows.h"
            
            /////////////////////////////////////////////////////////////////////////////
            #undef APSTUDIO_READONLY_SYMBOLS
            
            /////////////////////////////////////////////////////////////////////////////
            // Deutsch (Deutschland) resources
            
            #if !defined(AFX_RESOURCE_DLL) || defined(AFX_TARG_DEU)
            LANGUAGE LANG_GERMAN, SUBLANG_GERMAN
            
            #ifdef APSTUDIO_INVOKED
            /////////////////////////////////////////////////////////////////////////////
            //
            // TEXTINCLUDE
            //
            
            1 TEXTINCLUDE 
            BEGIN
                "resource.h\0"
            END
            
            2 TEXTINCLUDE 
            BEGIN
                "\r\n"
                "\0"
            END
            
            #endif    // APSTUDIO_INVOKED
            
            
            /////////////////////////////////////////////////////////////////////////////
            //
            // Version
            //
            #include "«relativeBasePath»/res/sharedVersion.h"
            
            VS_VERSION_INFO VERSIONINFO
             FILEVERSION FILE_VER
             PRODUCTVERSION PROD_VER
             FILEFLAGSMASK 0x3fL
            #ifdef _DEBUG
             FILEFLAGS 0x1L
            #else
             FILEFLAGS 0x0L
            #endif
             FILEOS 0x40004L
             FILETYPE 0x0L
             FILESUBTYPE 0x0L
            BEGIN
                BLOCK "StringFileInfo"
                BEGIN
                    BLOCK "040704b0"
                    BEGIN
                        VALUE "CompanyName", STR_COMPANY
                        VALUE "LegalCopyright", STR_COPYRIGHT_INFO
                        VALUE "FileDescription", "Dynamic Link Library"
                        VALUE "FileVersion", STR_FILE_VER
                        VALUE "InternalName", "«projectName»"
                        VALUE "OriginalFilename", "«projectName»"
                        VALUE "ProductName", "«projectName»"
                        VALUE "ProductVersion", STR_PROD_VER
                    END
                END
                BLOCK "VarFileInfo"
                BEGIN
                    VALUE "Translation", 0x407, 1200
                END
            END
            
            #endif    // German (Germany) resources
            /////////////////////////////////////////////////////////////////////////////
            
            
            
            #ifndef APSTUDIO_INVOKED
            /////////////////////////////////////////////////////////////////////////////
            //
            // Generated from the TEXTINCLUDE 3 resource.
            //
            
            
            /////////////////////////////////////////////////////////////////////////////
            #endif    // not APSTUDIO_INVOKED
        '''
    }
}
