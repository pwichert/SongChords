SongChords allows you to export songs and playlists as **PDFs** or display them directly.  
This lets you use content outside the app as well, e.g., on stage, in rehearsal, or as a printout.

For PDF control, you can use the following **ChordPro directives**:

* `{columns}` sets the number of columns.
* `{column_break}` moves to the next column. If the last column has already been reached, a new page is started automatically.
* `{new_page}` forces a page break.

To do this, choose Edit Song {icon:pencil} and then the `Edit ChordPro Text` button. In the editor that follows, you can insert the ChordPro directives accordingly. 

---

## PDF export of songs

Individual songs can be exported as a **PDF file**.  
The PDF export uses a layout specifically optimized for printing, including:

* chords above the text can be shown or hidden
* adjusted font sizes
* automatic line and page breaks

**macOS:**
Choose {icon:arrow.up.document.fill} and follow the file selection. Choose the file format `PDF Document`.

**iOS:**
Choose {icon:arrow.up.document.fill} at the bottom and select `Save to Files`.

The generated PDF can then be shared, saved, or printed.

---

## PDF export of playlists

Playlists can be exported as a setlist. The songs are numbered, and the titles are displayed in two columns on one page.

* In the menu {icon:ellipsis.circle} above the song list, choose `Export PDF File` and follow the file selection. Choose the file format `PDF Document`.

---

## Displaying PDFs

SongChords can **display the PDF view directly** without requiring an export.

* tap {icon:text.rectangle.page} to switch to the PDF view.
* tap {icon:text.page} to switch back to the normal live view.

This way, the layout can be checked before printing.

> Tip: In some situations, the PDF view is also helpful while playing, e.g., when a song is more clearly displayed in two columns.

---

## Layout notes

The following rules apply to PDF export and printing:

* the PDF layout uses **its own font sizes** and is independent of the live view in the app. Choose `PDF Options` in the menu {icon:ellipsis.circle} above the playlists.
* columns are not automatically clipped — lines that are too long may extend into adjacent columns.
* page breaks occur automatically or via the `{new_page}` directive.
* the paper size is fixed to **A4**.
