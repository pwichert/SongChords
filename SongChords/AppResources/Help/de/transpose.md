SongChords unterstützt das Transponieren von Akkorden in zwei Stufen:

1. Einfaches Transponieren mit positiven/negativen Werten
2. Kontextbezogenes Transponieren über ChordPro-Direktiven

## Einfaches Transponieren (Semitöne)

* Positive Werte verschieben nach oben (z. B. +2 = ein Ganzton nach oben)
* Negative Werte verschieben nach unten (z. B. −1 = ein Halbton nach unten)
* Die Notennamen werden so gewählt, dass bei positiven Werten eher Kreuz- und bei negativen Werten eher B-Schreibweisen verwendet werden

Beispiele:

`C  -> (+1)  -> C#`
`C  -> (-11) -> Db`
`G  -> (−2)  -> F`
`F# -> (−1)  -> F`

Slash-Chords:

`C/E  -> (+2) -> D/F#`
`Bb/D -> (−2) -> Ab/C`

## Transponieren mit ChordPro-Direktiven

Mit Direktiven lässt sich die Schreibweise (Kreuz/Be) und der tonale Kontext steuern. Dabei können in manchen Situationen komplizierte Tonarten entstehen (viele Kreuz- oder Be-Zeichen), was nicht immer erwünscht ist. Daher ist dieses Verhalten mit der Option "Transponieren nach Tonart" steuerbar.

* {key: ...} legt die Ausgangstonart fest (z. B. {key: ​C}, {key: ​F​#m})
* {transpose: n} verschiebt um n Halbtöne
* {key​_actual: ...} Wenn ein Song einen "key" hat, wird automatisch ein Metadaten-Eintrag key_actual hinzugefügt, der die tatsächliche Tonart einschließlich aller Transpositionen enthält
* {key​_from: ...} Wenn ein "transpose" aktiv ist, wird automatisch ein Meta-Eintrag key_from erzeugt, der die Tonart vor dem Transponieren enthält

Beispiel:

`{key: F#m}`
`{ transpose: 6 }`

erzeugt automatisch:

`{key_from: F#m}`
`{key_actual: B#m}`

`F#m  A  C#m  ->  B#m  D#  F##m`

> Tipp: Bei allen Arten des Transponierens wird der Wert der Direktive "transpose" und der Wert des Sliders "Transponieren" (beim Bearbeiten eines Songs) addiert. Das bedeutet, dass man mit dem Slider "mal eben schnell" Transponieren kann, ohne Direktiven verwenden zu müssen.
