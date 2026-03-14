//
//  SongChordsTests.swift
//  SongChordsTests
//
//  Created by Peter Wichert on 07.11.24.
//

import Testing
import SongChords

struct SongChordsTests {
    
    func chordPro(srcText: String) async -> String {
        var res: String = ""
        
        do {
            let lexer = ChordProLexer(input: srcText)
            let tokenStream = try await lexer.tokensAsStream()
            
            let parser = ChordProParser(userSettings: UserSettings().makeSendable(), songTranspose: 0, forPrinting: false)
            let parserResult = await parser.chunksAsStream(tokens: tokenStream)
                     
            let chunkFilter = ViewFilter(userSettings: UserSettings(), showHeader: true, showText: true)
            let filteredStream = await chunkFilter.chunksAsStream(chunks: parserResult.stream)

            for try await chunk in filteredStream {
                try Task.checkCancellation()
                for ch in chunk {
//                    print(ch.content)
                    res.append(ch.toChordProString())
                }
            }
        } catch (let error) { print("\(error)") }
        
        return res
    }
    
    @Test func testParser() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.

        var inputText: String = """
        { title: Simple Song}
        {artist: The Example Band }
        Artist: %{artist}
        [G]This is a [C]simple [D]song.
        [Verse]
        This is Verse
        """
        
        var expectedResult: String = """
        Artist: The Example Band
        G C D
        This is a  simple  song.
        [Verse]
        This is Verse
        
        """
        
        var res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
        
        inputText = """
        {title: Simple Song}
        []
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        G C D
        This is a  simple  song.
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
        
        inputText = """
        {title: Simple Song}
         []  
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        G C D
        This is a  simple  song.
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
        
        inputText = """
        {title: Simple Song}
         []   d
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        
             d
        G C D
        This is a  simple  song.
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
        
        inputText = """
        {title: Simple Song}
        [G]This is a [C]simple [D]song.
        [Test]
        """
        expectedResult = """
        G C D
        This is a  simple  song.
        [Test]
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)

        inputText = """
        {title: Simple Song}
        [G]This is a [C]simple [D]song.
        [Test] aa
        """
        expectedResult = """
        G C D
        This is a  simple  song.
        Test
         aa
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
        
        inputText = """
        {title: Simple Song}
        {sov: vers}
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        [vers]
        G C D
        This is a  simple  song.
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
        
        inputText = """
        {title: Simple Song}
        {sov: vers}
        {eov}
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        [vers]
        G C D
        This is a  simple  song.
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
        
        inputText = """
        {title: Simple Song}
        {sov: vers}
        [abc]
        {eov}
        [G]This is a [C]simple [D]song.
        """
        expectedResult = """
        [vers]
        [abc]
        G C D
        This is a  simple  song.
        
        """
        res = await chordPro(srcText: inputText)
        #expect(res == expectedResult)
    }
    
    @Test func testReverse() async throws {
        var inputText = """
              C                            F   Gsus4
        I get up, and nothing gets me down.
        """
        var expectedResult = """
        I get [C]up, and nothing gets me down.[F]    [Gsus4]
        
        """
        
        var chordProReverseParser = ChordProReverseParser(rootSys: .common)
        let _ = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString() == expectedResult)
        
        inputText = """
        [Verse]
              C           sdsd             F   Gsus4
        I get up, and nothing gets me down.
        """
        expectedResult = """
        [Verse]
        I get [C]up, and noth[*sdsd]ing gets me down.[F]    [Gsus4]
        
        """
        
        chordProReverseParser = ChordProReverseParser(rootSys: .common)
        let _ = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString() == expectedResult)

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
        [C]I get up, and nothing gets me[F] dow[Gsus4]n.
        You go[C]t it tough, I've seen the toughest [F]aroun[Gsus4]d.
        A[C]nd I know, baby, just how you [F]feel.[Gsus4]
        You've g[C]ot to roll with the punches to get to what'[F]s real [Gsus4]
        
        """
        chordProReverseParser = ChordProReverseParser(rootSys: .common)
        let _ = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString() == expectedResult)

        inputText = """
        
        (Guitar Solo)
        
        (Keyboard Solo)
        """
        expectedResult = """
        
        (Guitar Solo)
        
        (Keyboard Solo)
        
        """
        chordProReverseParser = ChordProReverseParser(rootSys: .common)
        let _ = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString() == expectedResult)

        inputText = """
        
        (Guitar Solo)
        
        C#m
        """
        expectedResult = """
        
        (Guitar Solo)
        
        [C#m]
        
        """
        chordProReverseParser = ChordProReverseParser(rootSys: .common)
        let _ = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString() == expectedResult)

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
        chordProReverseParser = ChordProReverseParser(rootSys: .common)
        let _ = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString() == expectedResult)
    }
//}
//
//@Suite("ChordII.fromString Parsing Tests")
//struct ChordIIParsingTests {

    func assertChord(_ input: String, german: Bool = false, expected: String) {
        let chord = try? Chord.parse(input, preferedGermanParsing: german, strict: true)
        let (rendered, _) = chord?.toString(rootSys: german ? .german : .common, transposeParm: nil) ?? ("", nil)
        #expect(rendered == expected, "Input: \(input) -> got: \(rendered)), expected: \(expected)")
        print("\(rendered == expected), Input: \(input) -> got: \(rendered)), expected: \(expected)")
    }

    @Test("Basic english notes")
    func englishBasics() {
        assertChord("C", expected: "C")
        assertChord("C#", expected: "C#")
        assertChord("Db", expected: "Db")
        assertChord("F##", expected: "F##")
        assertChord("Gbb", expected: "Gbb")
    }

    @Test("German H/B basics")
    func germanBasics() {
        assertChord("H", german: true, expected: "H")
        assertChord("B", german: true, expected: "B")
        assertChord("Ces", german: true, expected: "Ces")
        assertChord("Cis", german: true, expected: "Cis")
        assertChord("As", german: true, expected: "As")
        assertChord("Ais", german: true, expected: "Ais")
    }

    @Test("Chord qualities and extensions")
    func qualitiesAndExtensions() {
        assertChord("Cm", expected: "Cm")
        assertChord("Cmin", expected: "Cmin")
        assertChord("Cdim", expected: "Cdim")
        assertChord("Caug", expected: "Caug")
        assertChord("Cmaj7", expected: "Cmaj7")
        assertChord("C#m7", expected: "C#m7")
        assertChord("Bbmin7", expected: "Bbmin7")
        assertChord("F#maj7", expected: "F#maj7")
    }

    @Test("sus/add/power")
    func susAddPower() {
        assertChord("Asus2", expected: "Asus2")
        assertChord("Dsus4", expected: "Dsus4")
        assertChord("Bbadd9", expected: "Bbadd9")
        assertChord("Gadd11", expected: "Gadd11")
        assertChord("C5", expected: "C5")
    }

    @Test("Slash bass")
    func slashBass() {
        assertChord("C/E", expected: "C/E")
        assertChord("F#maj7/A", expected: "F#maj7/A")
        assertChord("Bbmin7/D", expected: "Bbmin7/D")
        assertChord("Gsus4/B", expected: "Gsus4/B")
    }

    @Test("Mixed spellings and german accidentals with slash")
    func mixed() {
        assertChord("Gessus4", expected: "Gessus4")
        assertChord("Gessus4/Des", expected: "Gessus4/Des")
        assertChord("Hmaj7/F#", german: true, expected: "Hmaj7/F#")
        assertChord("Bdim/F", german: true, expected: "Bdim/F")
    }
}
