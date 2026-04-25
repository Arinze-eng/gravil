package com.sjsu.boreas.ui.chat;

public class MessageItem {
    public final String id;
    public final String senderId;
    public final String kind;
    public final String body;
    public final String mediaUrl;
    public final String mediaType;
    public final long mediaSize;
    public final String createdAt;
    public final String readAt;

    public MessageItem(String id, String senderId, String kind, String body, String mediaUrl, String mediaType, long mediaSize, String createdAt, String readAt) {
        this.id = id;
        this.senderId = senderId;
        this.kind = kind;
        this.body = body;
        this.mediaUrl = mediaUrl;
        this.mediaType = mediaType;
        this.mediaSize = mediaSize;
        this.createdAt = createdAt;
        this.readAt = readAt;
    }
}
