# Media3 Transformer/ExoPlayer use reflection for codec/extractor lookup;
# stripping those classes produces release-only crashes that don't repro in
# debug builds. Verify a real release build specifically once Phase 11 is
# reached (plan §Phase 11) — this is a starting point, not a verified set.
-keep class androidx.media3.decoder.** { *; }
-keep class androidx.media3.exoplayer.** { *; }
-keep class androidx.media3.transformer.** { *; }
-keep class androidx.media3.effect.** { *; }
-dontwarn androidx.media3.**
