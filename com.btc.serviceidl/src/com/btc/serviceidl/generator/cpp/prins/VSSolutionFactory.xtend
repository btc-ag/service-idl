package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.cpp.IProjectSetFactory
import com.btc.serviceidl.generator.cpp.IProjectSet

class VSSolutionFactory implements IProjectSetFactory {
    
    override IProjectSet create() {
        new VSSolution
    }
    
}