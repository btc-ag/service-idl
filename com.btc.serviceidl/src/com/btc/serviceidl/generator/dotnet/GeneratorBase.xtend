package com.btc.serviceidl.generator.dotnet

class GeneratorBase {
    protected val extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
    protected val extension TypeResolver typeResolver

    new(BasicCSharpSourceGenerator basicCSharpSourceGenerator)
    {
        this.basicCSharpSourceGenerator = basicCSharpSourceGenerator
        this.typeResolver = basicCSharpSourceGenerator.typeResolver
    }    
}