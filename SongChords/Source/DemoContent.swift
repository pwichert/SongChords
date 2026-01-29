//
//  DemoContent.swift
//  SongChords
//
//  Created by Peter Wichert on 28.01.26.
//

import SwiftUI
import SwiftData

struct DemoHelper {
    static func createDemoPlaylist(modelContext: ModelContext) throws {
        // Demo-Playlist
        let demoPlaylist = try PlayList(modelContext: modelContext, title: "Demo Playlist")
        
        // Demo Song 1
        let song1 = try Song(
            title: "Starlight whisper",
            srcText: """
        { col: 2 }
        {title: Starlight whisper}
        {artist: SongChords}
        
        [Verse1]
        [C]This is a [G]demo song
        [Am]Just to [F]show how it works
        
        [Chorus]
        [C]Play it [G]loud
        [Am]Play it [F]clear
        
        [Verse 2]  
        [D]The moonlight dances, [A]painting the ground,  
        [G]In silver hues, no [D]greater sound.  
        [Bm]I close my eyes and [A]feel the air,  
        [G]A quiet magic [D]everywhere.  

        [Chorus]  
        [D]Starlight whispers, [A]soft and true,  
        [G]Telling stories [Bm]old and new.  
        [D]Hold me close, in [A]their embrace,  
        [G]Starlight whispers, [D]a timeless space.  

        [Bridge]  
        [G]Every shadow fades a[A]way,  
        [D]Beneath the stars, I’ll [Bm]always stay.  
        [G]In their glow, I [A]find my peace,  
        [D]A gentle love that [A]never [D]cease.  
        {column_break}
        
        [Final Chorus]  
        [D]Starlight whispers, [A]soft and true,  
        [G]Telling stories [Bm]old and new.  
        [D]Hold me close, in [A]their embrace,  
        [G]Starlight whispers, [D]a timeless space.  

        [Outro]  
        [Bm]Starlight fades, but [A]I still know,  
        [G]Their quiet song will [D]always show.
        """
        )
        
        let playerLoops1 = [
            PlayerLoop(start: 5, stop: 18, title: "Vers1"),
            PlayerLoop(start: 60, stop: 78, title: "Chorus")
        ]
        
        let sectionAnchors1 = [
            SectionAnchor(id: 0, time: 18),
            SectionAnchor(id: 1, time: 35),
            SectionAnchor(id: 2, time: 110),
            SectionAnchor(id: 3, time: 122),
            SectionAnchor(id: 4, time: 132),
            SectionAnchor(id: 5, time: 181),
            SectionAnchor(id: 6, time: 220)
        ]
        
        song1.playerLoops = playerLoops1
        song1.sectionAnchors = sectionAnchors1
        
        // Demo Song 2
        let song2 = try Song(
            title: "Fire in the Sky",
            srcText: """
        {title: Fire in the Sky}
        {artist: SongChords}
        
        [Verse1]
        [Dm]Another [G]simple song
        [C]For testing [Am]features
        
        [Bridge]
        [F]Autoscroll
        [G]PDF export
        [C]And audio playback
        
        [Verse 2]  
        [E]Through the ashes, [B]we will rise,  
        [A]Hope reborn in [C#m]blazing skies.  
        [E]Feel the rhythm, [B]hear the sound,  
        [A]In the fire, we’re [E]unbound.  

        [Chorus]  
        [C#m]Burning bright, it [B]lights the way,  
        [A]Chasing shadows, [E]night to day.  
        [C#m]Feel the power, [B]don’t ask why,  
        [A]We’re alive with the [B]fire in the [E]sky.  

        [Bridge]  
        [A]Let it burn, let it [B]take you higher,  
        [E]Every dream is a [C#m]raging fire.  
        [A]Feel the heat, let it [B]set you free,  
        [E]In the flames, we’re [B]meant to [C#m]be.  

        [Final Chorus]  
        [C#m]Burning bright, it [B]lights the way,  
        [A]Chasing shadows, [E]night to day.  
        [C#m]Feel the power, [B]don’t ask why,  
        [A]We’re alive with the [B]fire in the [E]sky.  

        [Outro]  
        [E]Fire in the [B]sky, we’ll [A]never [E]fall.
        """
        )
        
        let playerLoops2 = [
            PlayerLoop(start: 5, stop: 12, title: "Intro")
        ]
        
        let sectionAnchors2 = [
            SectionAnchor(id: 0, time: 15),
            SectionAnchor(id: 1, time: 55),
            SectionAnchor(id: 2, time: 120),
            SectionAnchor(id: 3, time: 136),
            SectionAnchor(id: 4, time: 178),
            SectionAnchor(id: 5, time: 190),
            SectionAnchor(id: 6, time: 210)
        ]
        
        song2.playerLoops = playerLoops2
        song2.sectionAnchors = sectionAnchors2

        // Beziehungen setzen
        song1.toPlaylist(playlist: demoPlaylist)
        song2.toPlaylist(playlist: demoPlaylist)

        // In Context einfügen
        modelContext.insert(demoPlaylist)
        modelContext.insert(song1)
        modelContext.insert(song2)
        
        try modelContext.save()
    }
}
