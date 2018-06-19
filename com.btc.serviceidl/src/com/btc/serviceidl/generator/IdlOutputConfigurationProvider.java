package com.btc.serviceidl.generator;

import java.util.HashSet;
import java.util.Set;

import org.eclipse.xtext.generator.IOutputConfigurationProvider;
import org.eclipse.xtext.generator.OutputConfiguration;

import com.btc.serviceidl.generator.common.ArtifactNature;

public class IdlOutputConfigurationProvider implements IOutputConfigurationProvider
{

    /**
     * @return a set of {@link OutputConfiguration} available for the generator
     */
    public Set<OutputConfiguration> getOutputConfigurations()
    {
        Set<OutputConfiguration> result = new HashSet<>();
        for (ArtifactNature an : ArtifactNature.values())
        {
            OutputConfiguration current = new OutputConfiguration(an.getLabel());
            current.setDescription("Output Folder for " + an.getLabel());
            current.setOutputDirectory("./src-gen/" + an.getLabel());
            current.setOverrideExistingResources(true);
            current.setCreateOutputDirectory(true);
            current.setCleanUpDerivedResources(true);
            current.setSetDerivedProperty(true);

            result.add(current);
        }
        return result;
    }

}
