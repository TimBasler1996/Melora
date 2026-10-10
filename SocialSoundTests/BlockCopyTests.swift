import Testing

/// Block was once three names, three error strings and two promises across
/// the three places it can be triggered. One wording is the fix; these tests
/// are what stops it drifting apart again.
struct BlockCopyTests {

    @Test("The message admits the part that cannot be undone")
    func messageMentionsDeletion() {
        let message = BlockCopy.message
        #expect(message.lowercased().contains("deleted"),
                "the conversation delete must be stated, not implied")
        #expect(message.contains("Settings"),
                "the way back has to be named where the action is offered")
    }

    @Test("Title and failure carry the person's name")
    func namesThePerson() {
        #expect(BlockCopy.title("Lena") == "Block Lena?")
        #expect(BlockCopy.failure("Lena").contains("Lena"))
    }

    @Test("There is a fallback when the name is unknown")
    func fallbackName() {
        #expect(!BlockCopy.fallbackName.isEmpty)
        #expect(!BlockCopy.title(BlockCopy.fallbackName).contains("()"))
    }
}
