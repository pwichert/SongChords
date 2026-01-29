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
    
    @Test func testChords() async throws {
        var englishDutchRoot: any ChordRoot = EnglishDutchRoot()
        var englishGermanRoot: any ChordRoot = EnglishGermanRoot()
        
        var pchord = try? ParsedChord.parse("D/F#", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "D/F#")

        pchord = try? ParsedChord.parse("C#maj7sus4/d#", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "C#maj7sus4/D#")

        pchord = try? ParsedChord.parse("C", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "C")

        pchord = try? ParsedChord.parse("Cmin7", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "Cmin7")

        pchord = try? ParsedChord.parse("C", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 8, rootSystem: &englishDutchRoot).0 == "G#")

        pchord = try? ParsedChord.parse("Fm", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: -1, rootSystem: &englishDutchRoot).0 == "Em")

        pchord = try? ParsedChord.parse("C", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: -4, rootSystem: &englishDutchRoot).0 == "Ab")

        pchord = try? ParsedChord.parse("B", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishGermanRoot).0 == "H")

        pchord = try? ParsedChord.parse("H", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "B")

        pchord = try? ParsedChord.parse("B", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "Bb")

        pchord = try? ParsedChord.parse("H", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: 4, rootSystem: &englishGermanRoot).0 == "Dis")

        pchord = try? ParsedChord.parse("B", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "B")

        pchord = try? ParsedChord.parse("Bb", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishGermanRoot).0 == "B")

        pchord = try? ParsedChord.parse("C/B", rootSystem: &englishGermanRoot, strict: true)
        #expect(pchord?.toString(transpose: -2, rootSystem: &englishGermanRoot).0 == "B/As")

        pchord = try? ParsedChord.parse("Bb", rootSystem: &englishDutchRoot, strict: true)
        #expect(pchord?.toString(transpose: 0, rootSystem: &englishDutchRoot).0 == "Bb")
    }
    
    @Test func testReverse() async throws {
        let englishDutchRoot: any ChordRoot = EnglishDutchRoot()

        var inputText = """
              C                            F   Gsus4
        I get up, and nothing gets me down.
        """
        var expectedResult = """
        I get [C]up, and nothing gets me down.[F]    [Gsus4]
        
        """
        
        var chordProReverseParser = ChordProReverseParser(rootSystem: englishDutchRoot)
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
        
        chordProReverseParser = ChordProReverseParser(rootSystem: englishDutchRoot)
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
        chordProReverseParser = ChordProReverseParser(rootSystem: englishDutchRoot)
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
        chordProReverseParser = ChordProReverseParser(rootSystem: englishDutchRoot)
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
        chordProReverseParser = ChordProReverseParser(rootSystem: englishDutchRoot)
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
        chordProReverseParser = ChordProReverseParser(rootSystem: englishDutchRoot)
        let _ = chordProReverseParser.parse(input: inputText)
        #expect(chordProReverseParser.toString() == expectedResult)
    }
}
