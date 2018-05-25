package com.btc.serviceidl.generator.cpp;

import org.eclipse.core.runtime.IPath;
import org.eclipse.xtext.xbase.lib.Pair;

import com.btc.serviceidl.generator.common.ProjectType;
import com.btc.serviceidl.idl.ModuleDeclaration;

public interface IModuleStructureStrategy {

    IPath getIncludeFilePath(Iterable<ModuleDeclaration> declarations, ProjectType type, String string);

    Pair<String, String> getEncapsulationHeaders();

    HeaderResolver createHeaderResolver();

}
