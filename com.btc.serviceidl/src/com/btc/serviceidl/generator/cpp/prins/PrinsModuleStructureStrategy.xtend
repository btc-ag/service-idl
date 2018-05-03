package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.generator.common.ProjectType
import org.eclipse.core.runtime.Path
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ArtifactNature

class PrinsModuleStructureStrategy implements IModuleStructureStrategy
{

    override getIncludeFilePath(Iterable<ModuleDeclaration> module_stack, ProjectType project_type, String baseName)
    {
        new Path(ReferenceResolver.MODULES_HEADER_PATH_PREFIX).append(
            GeneratorUtil.asPath(ParameterBundle.createBuilder(module_stack).with(project_type).build,
                ArtifactNature.CPP)).append(if (project_type == ProjectType.PROTOBUF) "gen" else "include").append(
            baseName).addFileExtension(if (project_type == ProjectType.PROTOBUF) "pb.h" else "h")
    }

}
