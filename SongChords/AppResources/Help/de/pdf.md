SongChords ermöglicht es, Songs und Playlisten als **PDF** zu exportieren oder direkt darzustellen.  
So lassen sich Inhalte auch außerhalb der App nutzen, z. B. auf der Bühne, im Proberaum oder als Ausdruck.

Für die PDF-Steuerung können die folgenden **ChordPro-Direktiven** verwendet werden:

* `{columns}` legt die Anzahl der Spalten fest
* `{column_break}` wechselt zur nächsten Spalte. Falls bereits die letzte Spalte erreicht ist, wird automatisch eine neue Seite begonnen.
* `{new_page}` erzwingt einen Seitenumbruch

Wähle dazu Song bearbeiten {icon:pencil} und dann Button `ChordPro-Text bearbeiten`. Im folgenden Editor kannst du die ChordPro-Direktiven entsprechend einarbeiten. 

---

## PDF-Export von Songs

Einzelne Songs können als **PDF-Datei** exportiert werden.  
Der PDF-Export übernimmt eine speziell für den Druck optimierte Darstellung, unter anderem:

* Akkorde über dem Text ein- oder ausgeblendet
* angepasste Schriftgrößen
* automatische Zeilen- und Seitenumbrüche

**MacOS:**
Wähle dazu {icon:arrow.up.document.fill} und folge der Dateiauswahl. Wähle dabei das Dateiformat `Pdf-Dokument`.

**iOS:**
Wähle dazu unten {icon:arrow.up.document.fill} und wähle `in Dateien sichern`.

Das erzeugte PDF kann anschließend geteilt, gespeichert oder gedruckt werden.

---

## PDF-Export von Playlisten

Playlisten lassen sich als Setliste exportieren. Dabei werden die Songs durchnummeriert und die Titel auf einer Seite zweispaltig dargestellt.

* wähle dazu im Menü {icon:ellipsis.circle} über der Songliste `PDF-Datei exportieren` und folge der Dateiauswahl. Wähle dabei das Dateiformat `Pdf-Dokument`.

---

## Anzeige von PDFs

SongChords kann die **PDF-Darstellung direkt anzeigen**, ohne dass ein Export notwendig ist.

* tippe auf {icon:text.rectangle.page}, um in die PDF-Ansicht zu wechseln
* tippe auf {icon:text.page}, um wieder zur normalen Live-Darstellung zurückzukehren

So kann das Layout vor dem Drucken überprüft werden.

> Tipp: In manchen Situationen ist die PDF-Darstellung auch während des Spielens hilfreich, z.B. wenn ein Song zweispaltig übersichtlicher dargestellt wird

---

## Layout-Hinweise

Beim PDF-Export und Drucken gelten folgende Regeln:

* das PDF-Layout verwendet **eigene Schriftgrößen** und ist unabhängig von der Live-Darstellung in der App. Wähle dazu `PDF-Optionen` im Menü {icon:ellipsis.circle} über den Playlisten.
* Spalten werden nicht automatisch „geclipped“ – zu lange Zeilen können in benachbarte Spalten hineinragen
* Seitenumbrüche erfolgen automatisch oder über Direktive `{new_page}`
* das Papierformat ist fest auf **DIN A4** eingestellt
