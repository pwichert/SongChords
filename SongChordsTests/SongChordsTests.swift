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

        let viewModel = ViewModel()

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
        var songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)
    }
    
    
    @Test func testChords() async throws {
        let viewModel = ViewModel()
        let parser = ChordProParser(viewModel: viewModel, songTranspose: 0, tokens: [], forPrinting: false)
        var pchord = parser.parseChord("C", convertGerman: false)
        #expect(pchord?.toString(transpose: 0, convertGerman: false) == "C")

        pchord = parser.parseChord("Cmin7", convertGerman: false)
        #expect(pchord?.toString(transpose: 0, convertGerman: false) == "Cm7")

        pchord = parser.parseChord("Cb", convertGerman: false)
        #expect(pchord?.toString(transpose: 0, convertGerman: false) == "Cb")

        pchord = parser.parseChord("C", convertGerman: false)
        #expect(pchord?.toString(transpose: 8, convertGerman: false) == "G#")

        pchord = parser.parseChord("Fm", convertGerman: false)
        #expect(pchord?.toString(transpose: -1, convertGerman: false) == "Em")

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
    
    @Test func testReverse() async throws {
        let chordProReverseParser = ChordProReverseParser()

        var inputText = """
              C                            F   Gsus4
        I get up, and nothing gets me down.
        """
        var expectedResult = """
        []
        I get [C]up, and nothing gets me down.[F]    [Gsus4]
        
        """
        
        var sections = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString(sections: sections) == expectedResult)
        
        inputText = """
        [Verse]
              C           sdsd             F   Gsus4
        I get up, and nothing gets me down.
        """
        expectedResult = """
        [Verse]
        I get [C]up, and noth[*sdsd]ing gets me down.[F]    [Gsus4]
        
        """
        
        sections = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString(sections: sections) == expectedResult)
        
        inputText = """
        C                            F   Gsus4
        I get up, and nothing gets me down.
              C                                  F    Gsus4
        You got it tough, I've seen the toughest around.
         C                             F    Gsus4
        And I know, baby, just how you feel.
                C                                          F      Gsus4
        You've got to roll with the punches to get to what's real
        """
        
        expectedResult = """
        []
        [C]I get up, and nothing gets me[F] dow[Gsus4]n.
        You go[C]t it tough, I've seen the toughest [F]aroun[Gsus4]d.
        A[C]nd I know, baby, just how you [F]feel.[Gsus4]
        You've g[C]ot to roll with the punches to get to what'[F]s real [Gsus4]
        
        """
        sections = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString(sections: sections) == expectedResult)
        
        inputText = """
        
        (Guitar Solo)
        
        (Keyboard Solo)
        """
        expectedResult = """
        []
        
        (Guitar Solo)
        
        (Keyboard Solo)
        
        """
        sections = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString(sections: sections) == expectedResult)
        
        inputText = """
        
        (Guitar Solo)
        
        C#m
        """
        expectedResult = """
        []
        
        (Guitar Solo)
        
        [C#m]
        
        """
        sections = chordProReverseParser.parse(input: inputText)
    }
}
