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

        let userSettings = UserSettings().makeSendable()

        var inputText: String = """
        { title: Simple Song}
        {artist: The Example Band }
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
        var songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
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
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}
        {sov: vers}
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        'vers'
        [G]This is a [C]simple [D]song.
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}
        {sov: vers}
        {eov}
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        'vers'
        ''
        [G]This is a [C]simple [D]song.
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)

        
        inputText = """
        {title: Simple Song}
        {sov: vers}
        [abc]
        {eov}
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        'vers'
        'abc'
        ''
        [G]This is a [C]simple [D]song.
        
        """
        tokens = try ChordProLexer(input: inputText).tokenize()
        songRepresentation = try ChordProParser(userSettings: userSettings, songTranspose: 0, tokens: tokens, forPrinting: false).parse()
        #expect(songRepresentation.toChordProString() == expectedResult)
    }
    
    @Test func testChords() async throws {
        var englishDutchRoot: any ChordRoot = EnglishDutchRoot()
        var englishGermanRoot: any ChordRoot = EnglishGermanRoot()
        
        var pchord = ParsedChord.parse("D/F#", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "D/F#")

        pchord = ParsedChord.parse("C#maj7sus4/d#", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "C#maj7sus4/D#")

        pchord = ParsedChord.parse("C", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "C")

        pchord = ParsedChord.parse("Cmin7", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "Cmin7")

        pchord = ParsedChord.parse("C", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 8, rootSystem: &englishDutchRoot) == "G#")

        pchord = ParsedChord.parse("Fm", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: -1, rootSystem: &englishDutchRoot) == "Em")

        pchord = ParsedChord.parse("C", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: -4, rootSystem: &englishDutchRoot) == "Ab")

        pchord = ParsedChord.parse("B", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishGermanRoot) == "H")

        pchord = ParsedChord.parse("H", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "B")

        pchord = ParsedChord.parse("B", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "Bb")

        pchord = ParsedChord.parse("H", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: 4, rootSystem: &englishGermanRoot) == "Dis")

        pchord = ParsedChord.parse("B", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "B")

        pchord = ParsedChord.parse("Bb", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishGermanRoot) == "B")

        pchord = ParsedChord.parse("C/B", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: -2, rootSystem: &englishGermanRoot) == "B/As")

        pchord = ParsedChord.parse("Bb", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot) == "Bb")
    }
    
    @Test func testReverse() async throws {
        let chordProReverseParser = ChordProReverseParser()
        var englishDutchRoot: any ChordRoot = EnglishDutchRoot()

        var inputText = """
              C                            F   Gsus4
        I get up, and nothing gets me down.
        """
        var expectedResult = """
        []
        I get [C]up, and nothing gets me down.[F]    [Gsus4]
        
        """
        
        var sections = chordProReverseParser.parse(input: inputText, rootSystem: &englishDutchRoot)
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
        
        sections = chordProReverseParser.parse(input: inputText, rootSystem: &englishDutchRoot)
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
        sections = chordProReverseParser.parse(input: inputText, rootSystem: &englishDutchRoot)
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
        sections = chordProReverseParser.parse(input: inputText, rootSystem: &englishDutchRoot)
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
        sections = chordProReverseParser.parse(input: inputText, rootSystem: &englishDutchRoot)
        #expect(chordProReverseParser.toString(sections: sections) == expectedResult)
        
        inputText = """
        [Verse]
             Cm7               F
        The power of love is a curious thing
        Cm7                         F
        Make a one man weep, make another man sing
        Cm7                  F
        Change a heart to a little white dove
        Cm7                  F
        More than a feeling, that's the power of love
        """
        expectedResult = """
        [Verse]
        The p[Cm7]ower of love is a [F]curious thing
        [Cm7]Make a one man weep, make an[F]other man sing
        [Cm7]Change a heart to a l[F]ittle white dove
        [Cm7]More than a feeling, [F]that's the power of love
        
        """
        sections = chordProReverseParser.parse(input: inputText, rootSystem: &englishDutchRoot)
        #expect(chordProReverseParser.toString(sections: sections) == expectedResult)
    }
}
