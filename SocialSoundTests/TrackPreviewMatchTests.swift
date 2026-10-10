import Testing

/// Whether a song has a 30 s preview comes down to two string rules. They
/// decide silently: a bad match plays the wrong song, a missed match hides
/// the button. Both failures look like "the catalogue doesn't have it".
struct TrackPreviewMatchTests {

    @Test("Spotify's remix and version suffixes are dropped")
    func titleCleaning() {
        #expect(TrackPreviewService.cleanTitle("Nie meh - SD&A Remix") == "Nie meh")
        #expect(TrackPreviewService.cleanTitle("Cold Heart - PNAU Remix") == "Cold Heart")
        #expect(TrackPreviewService.cleanTitle("Nights (Live)") == "Nights")
        #expect(TrackPreviewService.cleanTitle("Je veux") == "Je veux")
    }

    @Test("A title that is only a suffix does not become empty garbage")
    func titleCleaningEdges() {
        #expect(TrackPreviewService.cleanTitle("  Redbone  ") == "Redbone")
        #expect(TrackPreviewService.cleanTitle("Mr. Brightside") == "Mr. Brightside")
    }

    @Test("Artists match across accents, case and punctuation")
    func artistMatchingIsLenient() {
        #expect(TrackPreviewService.artistMatches("Zaz", "ZAZ"))
        #expect(TrackPreviewService.artistMatches("Beyoncé", "Beyonce"))
        #expect(TrackPreviewService.artistMatches("Simon & Garfunkel", "Simon and Garfunkel"))
        #expect(TrackPreviewService.artistMatches("The Killers", "The Killers"))
    }

    @Test("Different artists do not match")
    func artistMatchingRejects() {
        #expect(!TrackPreviewService.artistMatches("Zaz", "Baby Zaz Karaoke Band"))
        #expect(!TrackPreviewService.artistMatches("SZA", "Drake"))
        #expect(!TrackPreviewService.artistMatches("Sum 41", ""))
    }
}
