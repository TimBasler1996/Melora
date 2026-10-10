import Testing

/// Distance is the one number strangers see about each other, and the rule
/// that keeps it coarse is three lines of arithmetic nobody would notice
/// breaking. The band boundaries are the contract.
struct DistanceFormatTests {

    @Test("Anything under half a kilometre is one band, never a figure")
    func nearIsABand() {
        #expect(DistanceFormat.band(0) == "under 500 m")
        #expect(DistanceFormat.band(12) == "under 500 m")
        #expect(DistanceFormat.band(499) == "under 500 m")
    }

    @Test("The 500 m and 1 km boundaries land on the right side")
    func boundaries() {
        #expect(DistanceFormat.band(500) == "under 1 km")
        #expect(DistanceFormat.band(999) == "under 1 km")
        #expect(DistanceFormat.band(1000) == "about 1 km")
    }

    @Test("Under ten kilometres rounds to halves")
    func halfKilometreSteps() {
        #expect(DistanceFormat.band(1200) == "about 1 km")
        #expect(DistanceFormat.band(1300) == "about 1.5 km")
        #expect(DistanceFormat.band(2400) == "about 2.5 km")
        #expect(DistanceFormat.band(9700) == "about 9.5 km")
    }

    @Test("Ten kilometres and beyond round to whole ones")
    func wholeKilometres() {
        #expect(DistanceFormat.band(10_000) == "about 10 km")
        #expect(DistanceFormat.band(42_400) == "about 42 km")
        #expect(DistanceFormat.band(700_000) == "about 700 km")
    }

    @Test("A named distance never reads as zero")
    func coarseNeverZero() {
        #expect(DistanceFormat.coarseKilometres(1) == "1 km")
        #expect(DistanceFormat.coarseKilometres(400) == "1 km")
        #expect(DistanceFormat.coarseKilometres(1600) == "2 km")
    }

    @Test("Every band is hedged — nothing ever reads as an exact position")
    func alwaysHedged() {
        for meters in stride(from: 0, through: 60_000, by: 137) {
            let text = DistanceFormat.band(meters)
            #expect(text.hasPrefix("under ") || text.hasPrefix("about "),
                    "unhedged band \"\(text)\" for \(meters) m")
        }
    }
}
