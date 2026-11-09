package com.druid.alalive;

import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;
import me.zed_0xff.zombie_buddy.Patch;

/** Test-only equivalent of clicking the ready prompt in GameLoadingState. */
public class Patches {
    private static VarHandle shown, done, player, force;
    private static boolean failed;

    public static void readyClick(Object state) {
        if (failed || state == null) return;
        try {
            if (force == null) {
                Class<?> type = state.getClass();
                MethodHandles.Lookup lookup = MethodHandles.privateLookupIn(type, MethodHandles.lookup());
                shown = lookup.findStaticVarHandle(type, "showedClickToSkip", boolean.class);
                done = lookup.findStaticVarHandle(type, "done", boolean.class);
                player = lookup.findStaticVarHandle(type, "playerCreated", boolean.class);
                force = lookup.findVarHandle(type, "forceDone", boolean.class);
            }
            if ((boolean) shown.get() && (boolean) done.get() && (boolean) player.get()
                    && !(boolean) force.get(state)) {
                force.set(state, true);
                System.out.println("[ALALive] click ready world prompt");
            }
        } catch (Throwable error) {
            failed = true;
            System.out.println("[ALALive] ready-click ERROR " + error);
        }
    }

    @Patch(className = "zombie.gameStates.GameLoadingState", methodName = "update")
    public static class ClickToStart {
        @Patch.OnEnter
        public static void enter(@Patch.This Object state) {
            Patches.readyClick(state);
        }
    }
}
