# Bottom navigation reference update

Replaced the stretched navigation bitmap with a compact native bar matching the
provided screenshot's composition: a curved center cutout, raised blue camera
button, soft top shadow, and Home/Settings controls with live localized labels.
The shared component applies to every screen that already includes navigation.
Colors follow light, dark, and system appearance. Safe-area bottom padding and
larger accessibility text are supported. Home content reserves the bar's height;
the previous oversized blank list footer was reduced.

The camera retains its existing menu anchor and is hidden while the scan menu is
open. Updated existing navigation tests for the native controls and theme surface.
Seven Python checks pass. Flutter widget tests and device rendering could not be
run because Flutter is not installed in this environment.
