local DOCUMENT = {}

DOCUMENT.Name = "Princess"
DOCUMENT.Type = "Slasher"

DOCUMENT.Description = SlashCo.Language(string.lower(DOCUMENT.Name .. "_description"))
DOCUMENT.AdditionalDescription = SlashCo.Language(string.lower(DOCUMENT.Name .. "_description_additional"))

SlashCo.RegisterDocument(DOCUMENT)