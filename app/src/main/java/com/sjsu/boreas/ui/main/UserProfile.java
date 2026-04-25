package com.sjsu.boreas.ui.main;

public class UserProfile {
    public final String id;
    public final String name;
    public final String code;
    public final String lastSeen;

    public UserProfile(String id, String name, String code, String lastSeen) {
        this.id = id;
        this.name = name;
        this.code = code;
        this.lastSeen = lastSeen;
    }
}
