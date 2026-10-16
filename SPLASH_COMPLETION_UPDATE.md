# Finish the animated loader at 1.5x

Startup waits for the animated Lottie loader to finish one complete cycle at 1.5x
speed, and for saved-document loading. The six-second source animation therefore
finishes in four seconds. Navigation is driven by animation completion, not a
fixed timer. If data takes longer, the final animation frame remains visible.

Reduced motion displays a still frame. Animation errors release the animation
gate so a broken asset cannot block startup. Loading errors still offer Retry.
Updated Flutter tests cover slow data, fast data waiting for four-second playback,
and 1.5x speed. Seven Python checks pass; Flutter tests and APK compilation could
not run because Flutter is unavailable here.
