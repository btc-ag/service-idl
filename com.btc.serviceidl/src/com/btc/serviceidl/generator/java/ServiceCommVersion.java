package com.btc.serviceidl.generator.java;

public enum ServiceCommVersion {
    V0_3("0.3"),
    V0_5("0.5");

    private final String label;

    ServiceCommVersion(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    public static ServiceCommVersion get(String string) {
        for (ServiceCommVersion value : values()) {
            if (value.getLabel().equals(string)) return value;
        }
        throw new IllegalArgumentException("Unknown Java ServiceComm version: " + string);
    }
}
