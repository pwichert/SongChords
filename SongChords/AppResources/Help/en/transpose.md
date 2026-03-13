SongChords supports chord transposition in two stages:

1. Simple transposition using positive/negative values
2. Context-aware transposition using ChordPro directives

## Simple Transposition (Semitones)

* Positive values transpose upward (e.g., +2 = up a whole tone)
* Negative values transpose downward (e.g., −1 = down a semitone)
* Note names are chosen so that positive values prefer sharp notation, while negative values prefer flat notation

Examples:

`C  -> (+1)  -> C#`
`C  -> (-11) -> Db`
`G  -> (−2)  -> F`
`F# -> (−1)  -> F`

Slash chords:

`C/E  -> (+2) -> D/F#`
`Bb/D -> (−2) -> Ab/C`

## Transposition with ChordPro Directives

Directives allow you to control the notation (sharp/flat) and the tonal context. In some situations this can lead to complex key signatures (many sharps or flats), which may not always be desired. Therefore, this behavior can be controlled with the “Transpose by Key Signature” option.

* {key: ...} defines the original key (e.g. {key: C}, {key: F#m})
* {transpose: n} transposes by n semitones
* {key_actual: ...} If a song has a key, a metadata entry key_actual is automatically added that contains the actual key including all transpositions
* {key_from: ...} If transpose is active, a metadata entry key_from is automatically generated that contains the key before transposition

Example:

`{key: F#m}`
`{ transpose: 6 }`

automatically produces::

`{key_from: F#m}`
`{key_actual: B#m}`

`F#m  A  C#m  ->  B#m  D#  F##m`

> Tip: For all types of transposition, the value of the transpose directive and the value of the “Transpose” slider (when editing a song) are added together. This means the slider can be used to quickly transpose a song without needing to use directives.
