package com.btc.serviceidl.generator.cpp

import java.util.Arrays
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data

@Data
@Accessors(NONE)
class ProjectFileSet
{
    @Data
    static class FileGroup
    {
        String name
    }

    public static val CPP_FILE_GROUP = new FileGroup("cpp")
    public static val HEADER_FILE_GROUP = new FileGroup("header")
    public static val DEPENDENCY_FILE_GROUP = new FileGroup("dependency") // TODO move this to prins
    public static val PROTOBUF_FILE_GROUP = new FileGroup("protobuf")

    public static val DEFAULT_FILE_GROUPS = Arrays.asList(CPP_FILE_GROUP, HEADER_FILE_GROUP, DEPENDENCY_FILE_GROUP,
        PROTOBUF_FILE_GROUP)

    val Map<FileGroup, Collection<String>> files

    new(Iterable<FileGroup> extraFileGroups)
    {
        this.files = new HashMap<FileGroup, Collection<String>>
        for (group : DEFAULT_FILE_GROUPS + extraFileGroups)
            this.files.put(group, new HashSet<String>)
    }

    private new(ProjectFileSet base)
    {
        this.files = base.files.unmodifiableView
    }
    
    def getGroup(FileGroup group)
    {
        this.files.get(group).unmodifiableView
    }
    
    def void addToGroup(FileGroup group, String name)
    {
        this.files.get(group).add(name)
    }

    def unmodifiableView()
    {
        new ProjectFileSet(this)
    }
}
