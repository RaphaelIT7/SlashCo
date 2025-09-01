local DOCUMENT = {}

DOCUMENT.Name = "The Watcher" -- His name in his lua file under SLASHER.Name is "The Watcher" so we should use that one instead of the name given to register him.
DOCUMENT.Type = "Slasher"
DOCUMENT.Slasher = "Watcher"

DOCUMENT.DescriptionID = DOCUMENT.Name .. "_description"
DOCUMENT.AdditionalDescriptionID = DOCUMENT.Name .. "_description_additional"

SlashCo.RegisterDocument(DOCUMENT)