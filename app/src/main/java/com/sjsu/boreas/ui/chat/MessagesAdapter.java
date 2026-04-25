package com.sjsu.boreas.ui.chat;

import android.media.MediaPlayer;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.sjsu.boreas.R;
import com.squareup.picasso.Picasso;

import java.util.ArrayList;

public class MessagesAdapter extends RecyclerView.Adapter<MessagesAdapter.VH> {

    public interface MediaResolver {
        String resolveSignedUrl(MessageItem m) throws Exception;
    }

    private final ArrayList<MessageItem> items = new ArrayList<>();
    private final String myId;
    private final MediaResolver mediaResolver;

    public MessagesAdapter(String myId, MediaResolver mediaResolver) {
        this.myId = myId;
        this.mediaResolver = mediaResolver;
    }

    public void setItems(ArrayList<MessageItem> list) {
        items.clear();
        items.addAll(list);
        notifyDataSetChanged();
    }

    public void addItems(ArrayList<MessageItem> list) {
        int start = items.size();
        items.addAll(list);
        notifyItemRangeInserted(start, list.size());
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_message, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH h, int pos) {
        MessageItem m = items.get(pos);
        boolean mine = m.senderId != null && m.senderId.equals(myId);

        h.body.setText(m.kind.equals("text") ? m.body : (mine ? "You sent a " + m.kind : "Received a " + m.kind));
        String meta = (mine ? "You" : "Them") + " · " + m.createdAt;
        if (mine && m.readAt != null && !m.readAt.equals("null") && !m.readAt.isEmpty()) meta += " · Read";
        h.meta.setText(meta);

        h.image.setVisibility(View.GONE);
        h.play.setVisibility(View.GONE);

        if (m.kind.equals("image") && m.mediaUrl != null && !m.mediaUrl.equals("null")) {
            h.image.setVisibility(View.VISIBLE);
            h.image.setImageDrawable(null);
            new Thread(() -> {
                try {
                    String signed = mediaResolver != null ? mediaResolver.resolveSignedUrl(m) : null;
                    if (signed != null) {
                        h.image.post(() -> Picasso.get().load(signed).into(h.image));
                    }
                } catch (Exception ignored) {}
            }).start();
        }

        if (m.kind.equals("voice") && m.mediaUrl != null && !m.mediaUrl.equals("null")) {
            h.play.setVisibility(View.VISIBLE);
            h.play.setOnClickListener(v -> {
                h.play.setEnabled(false);
                new Thread(() -> {
                    try {
                        String signed = mediaResolver != null ? mediaResolver.resolveSignedUrl(m) : null;
                        if (signed != null) {
                            MediaPlayer mp = new MediaPlayer();
                            mp.setDataSource(signed);
                            mp.setOnPreparedListener(MediaPlayer::start);
                            mp.setOnCompletionListener(x -> {
                                x.release();
                                h.play.post(() -> h.play.setEnabled(true));
                            });
                            mp.prepareAsync();
                        } else {
                            h.play.post(() -> h.play.setEnabled(true));
                        }
                    } catch (Exception e) {
                        h.play.post(() -> h.play.setEnabled(true));
                    }
                }).start();
            });
        }
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    static class VH extends RecyclerView.ViewHolder {
        TextView body;
        ImageView image;
        Button play;
        TextView meta;

        VH(@NonNull View itemView) {
            super(itemView);
            body = itemView.findViewById(R.id.body);
            image = itemView.findViewById(R.id.image);
            play = itemView.findViewById(R.id.btn_play);
            meta = itemView.findViewById(R.id.meta);
        }
    }
}
