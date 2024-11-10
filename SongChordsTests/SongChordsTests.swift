//
//  SongChordsTests.swift
//  SongChordsTests
//
//  Created by Peter Wichert on 07.11.24.
//

import Testing
import SongChords

struct SongChordsTests {
    
    @Test func testParser() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        var inputText: String = """
        {title: Simple Song}
        {artist: The Example Band}
        Artist: %{artist}
        [G]This is a [C]simple [D]song.
        [Verse]
        This is Verse
        """
        
        var expectedResult: String = """
        ''
        Artist: The Example Band
        [G]This is a [C]simple [D]song.
        'Verse'
        This is Verse
        
        """
        
        var tokens = try ChordProLexer(input: inputText).tokenize()
        var songRepresentation = try ChordProParser(tokens: tokens).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}

        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        ''

        [G]This is a [C]simple [D]song.
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(tokens: tokens).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}
        []
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        ''
        [G]This is a [C]simple [D]song.
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(tokens: tokens).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}
         []  
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        ''
        [G]This is a [C]simple [D]song.
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(tokens: tokens).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}
         []   d
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        ''
            d
        [G]This is a [C]simple [D]song.
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(tokens: tokens).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}
        [G]This is a [C]simple [D]song.
        [Test]
        """
        expectedResult = """
        ''
        [G]This is a [C]simple [D]song.
        'Test'
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(tokens: tokens).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)


        inputText = """
        {title: Simple Song}
        [G]This is a [C]simple [D]song.
        [Test] aa
        """
        expectedResult = """
        ''
        [G]This is a [C]simple [D]song.
        Test aa
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(tokens: tokens).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)
    }
    
    
    @Test func testChords() async throws {
        let parser = ChordProParser(tokens: [])
        var pchord = parser.parseChord("C", convertGerman: false)
        #expect(pchord?.toString(transpose: 0, convertGerman: false) == "C")

        pchord = parser.parseChord("Cb", convertGerman: false)
        #expect(pchord?.toString(transpose: 0, convertGerman: false) == "Cb")

        pchord = parser.parseChord("C", convertGerman: false)
        #expect(pchord?.toString(transpose: 8, convertGerman: false) == "G#")

        pchord = parser.parseChord("C", convertGerman: false)
        #expect(pchord?.toString(transpose: -4, convertGerman: false) == "Ab")

        pchord = parser.parseChord("H", convertGerman: false)
        #expect(pchord == nil)

        pchord = parser.parseChord("H", convertGerman: true)
        #expect(pchord?.toString(transpose: 0, convertGerman: false) == "B")

        pchord = parser.parseChord("B", convertGerman: false)
        #expect(pchord?.toString(transpose: 0, convertGerman: true) == "H")

        pchord = parser.parseChord("B", convertGerman: true)
        #expect(pchord?.toString(transpose: 0, convertGerman: false) == "Bb")

        pchord = parser.parseChord("H", convertGerman: true)
        #expect(pchord?.toString(transpose: 4, convertGerman: true) == "D#")

        pchord = parser.parseChord("B", convertGerman: true)
        #expect(pchord?.toString(transpose: 0, convertGerman: true) == "B")

        pchord = parser.parseChord("Bb", convertGerman: true)
        #expect(pchord?.toString(transpose: 0, convertGerman: true) == "B")
    }
}
