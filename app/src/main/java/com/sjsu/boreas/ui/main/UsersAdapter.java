package com.sjsu.boreas.ui.main;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.sjsu.boreas.R;

import java.util.ArrayList;

public class UsersAdapter extends RecyclerView.Adapter<UsersAdapter.VH> {

    public interface OnUserClick {
        void onClick(UserProfile u);
    }

    private final ArrayList<UserProfile> items = new ArrayList<>();
    private final OnUserClick cb;

    public UsersAdapter(OnUserClick cb) {
        this.cb = cb;
    }

    public void setItems(ArrayList<UserProfile> list) {
        items.clear();
        items.addAll(list);
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_user, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH h, int pos) {
        UserProfile u = items.get(pos);
        h.name.setText(u.name);
        h.sub.setText("Code: " + u.code + (u.lastSeen != null && !u.lastSeen.equals("null") ? (" · Last seen: " + u.lastSeen) : ""));
        h.itemView.setOnClickListener(v -> {
            if (cb != null) cb.onClick(u);
        });
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    static class VH extends RecyclerView.ViewHolder {
        TextView name;
        TextView sub;
        VH(@NonNull View itemView) {
            super(itemView);
            name = itemView.findViewById(R.id.name);
            sub = itemView.findViewById(R.id.sub);
        }
    }
}
