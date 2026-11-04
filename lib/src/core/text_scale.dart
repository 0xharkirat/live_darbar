/// The largest text size the app lays out for, as a multiple of the default.
///
/// Android's biggest font setting is 2x. iOS goes past it, to 3.1x at its
/// largest accessibility size, and at that size no screen fits a phone.
/// `MaterialApp.builder` holds the listener's size at this value: text stays
/// as large as Android lets anyone set it, and the layout stays whole.
const kMaxTextScale = 2.0;

/// The largest text size for words that sit on a painting.
///
/// The hero card keeps the painting's shape, and its words are drawn over it
/// at the bottom. At 2x the title wraps to 2 lines and climbs over the LIVE
/// badge. The same words are at full size in the mini player and the player.
const kPaintingTextScale = 1.3;
