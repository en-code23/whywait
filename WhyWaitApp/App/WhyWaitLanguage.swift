import AppKit
import SpriteKit

/// Translate at the assignment boundary, not by walking a scene every frame.
/// SpriteKit label geometry, animations and collision ownership are unchanged.
final class WhyWaitLabelNode: SKLabelNode {
    override var text: String? {
        get { super.text }
        set { super.text = newValue.map(WWText.text) }
    }
}

enum WhyWaitLanguage: String, CaseIterable {
    case english = "en", german = "de"
    static let changed = Notification.Name("WhyWaitLanguageChanged")
    static var current: WhyWaitLanguage {
        get { WhyWaitLanguage(rawValue: UserDefaults.standard.string(forKey: "whywait.language") ?? "en") ?? .english }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "whywait.language")
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }
}

/// Small reversible presentation catalog. IDs, saves and game rules stay language-neutral.
/// Placeholders preserve numbers/game names; translation never runs over editable text.
enum WWText {
    private static let cache: NSCache<NSString, NSString> = {
        let result = NSCache<NSString, NSString>()
        result.countLimit = 512
        return result
    }()
    static func text(_ source: String) -> String {
        guard source.rangeOfCharacter(from: .letters) != nil else { return source }
        let german = WhyWaitLanguage.current == .german
        let key = ((german ? "de:" : "en:") + source) as NSString
        if let cached = cache.object(forKey: key) { return cached as String }
        for entry in catalog {
            let pattern = german ? entry.english : entry.german
            let destination = german ? entry.germanText : entry.englishText
            let range = NSRange(source.startIndex..., in: source)
            guard let match = pattern.firstMatch(in: source, range: range) else { continue }
            var output = destination
            for index in 1..<match.numberOfRanges {
                if let captured = Range(match.range(at: index), in: source) {
                    output = output.replacingOccurrences(of: "{\(index - 1)}", with: String(source[captured]))
                }
            }
            let result = source == source.uppercased() ? output.uppercased() : output
            cache.setObject(result as NSString, forKey: key)
            return result
        }
        cache.setObject(source as NSString, forKey: key)
        return source
    }

    static func localize(_ view: NSView) {
        if let field = view as? NSTextField, !field.isEditable {
            let translated = text(field.stringValue)
            if translated != field.stringValue { field.stringValue = translated }
        }
        if let button = view as? NSButton, !(button is NSPopUpButton) { button.title = text(button.title) }
        view.subviews.forEach(localize)
    }

    static func localize(_ menu: NSMenu) {
        for item in menu.items {
            item.title = text(item.title)
            if let submenu = item.submenu { localize(submenu) }
        }
    }

    static func localizeLabels(in node: SKNode) {
        if let label = node as? SKLabelNode, let value = label.text { label.text = text(value) }
        node.children.forEach { localizeLabels(in: $0) }
    }

    private struct Entry {
        let englishText: String
        let germanText: String
        let english: NSRegularExpression
        let german: NSRegularExpression
        init(_ en: String, _ de: String) {
            englishText = en; germanText = de
            func pattern(_ value: String) -> NSRegularExpression {
                var escaped = NSRegularExpression.escapedPattern(for: value)
                for i in 0..<5 {
                    escaped = escaped.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: "{\(i)}"), with: "(.+?)")
                }
                return try! NSRegularExpression(pattern: "^" + escaped + "$", options: [.caseInsensitive])
            }
            english = pattern(en); german = pattern(de)
        }
    }
    // Exact UI phrases must win over broad templates such as “Launch {0}”.
    private static let catalog: [Entry] = (
        pairs.filter { !$0.0.contains("{0}") }
        + pairs.filter { $0.0.contains("{0}") }
    ).map(Entry.init)
    private static let pairs: [(String, String)] = [
        ("Ready to play", "Bereit zum Spielen"), ("{0} play · {1}", "{0} Spiel · {1}"),
        ("{0} plays · {1}", "{0} Spiele · {1}"), ("{0} launch", "{0} Spielstart"),
        ("Favorite: {0}", "Favorit: {0}"), ("YOUR DESKTOP, IN PLAY.", "DEIN DESKTOP SPIELT MIT."),
        ("A small escape while the work carries on.", "Eine kleine Pause, während die Arbeit weitergeht."),
        ("Small games for the long-running parts.", "Kleine Spiele für lange Wartezeiten."),
        ("SELECT AN ENTRY", "WÄHLE EINEN EINTRAG"), ("UNDISCOVERED", "UNENTDECKT"),
        ("{0} / {1} FOUND", "{0} / {1} GEFUNDEN"), ("Preferred:  {0}", "Tiefe:  {0}"),
        ("Variants:  {0} / {1}", "Varianten:  {0} / {1}"), ("Found:  {0}", "Gefunden:  {0}"),
        ("Automatically sold", "Automatisch verkauft"), ("ASSESSED   ¢ {0}", "WERT   ¢ {0}"),
        ("FAVORITE SPECIMEN", "LIEBLINGSFANG"), ("ARCHIVED SPECIMEN", "ARCHIVIERTER FANG"),
        ("CPU              YOU", "CPU              DU"),
        ("+{0}% cast range", "+{0}% Wurfweite"), ("+{0} reel speed", "+{0} Einholtempo"),
        ("+{0}% tension limit", "+{0}% Spannungsgrenze"), ("+{0}ms hook window", "+{0}ms Anschlagzeit"),
        ("-{0}% bite wait", "-{0}% Wartezeit"), ("GEAR REFINED TO LV.{0}  ·  -{1}", "AUF STUFE {0} VERBESSERT  ·  -{1}"),
        ("REEF CHUM", "RIFFKÖDER"), ("PRISM FLY", "PRISMENFLIEGE"), ("ABYSS LANTERN", "TIEFSEELATERNE"),
        ("Quicker bites · modest rarity lift", "Schnellere Bisse · mehr seltene Fänge"),
        ("Greatly improves variant sightings", "Deutlich mehr seltene Varianten"),
        ("Draws deep-water ocean species", "Lockt Tiefseefische an"),
        ("TIDEVAULT BERTH", "TIDEVAULT-PLATZ"), ("CAPACITY  {0}", "KAPAZITÄT  {0}"),
        ("Archive more favorite specimens", "Mehr Lieblingsfänge aufbewahren"),
        ("Your next catch can live here", "Hier ist Platz für deinen nächsten Fang"),
        ("Select a specimen", "Wähle einen Fang"), ("PAGE {0} / {1}", "SEITE {0} / {1}"),
        ("FAVORITE", "FAVORIT"), ("UNFAVORITE", "ENTFAVORISIEREN"), ("LOCK", "SPERREN"),
        ("UNLOCK", "ENTSPERREN"), ("RELEASE", "FREILASSEN"), ("LOCKED", "GESPERRT"),
        ("Catches are already appraised on landing", "Fänge werden beim Landen vergütet"),
        ("{0} / {1} DISCOVERED", "{0} / {1} ENTDECKT"), ("Caught: {0}", "Gefangen: {0}"),
        ("Largest: {0}", "Schwerster: {0}"), ("Longest: {0}", "Längster: {0}"),
        ("Preferred Zone: {0}", "Bevorzugte Tiefe: {0}"), ("Best Value: {0} coins", "Höchster Wert: {0} Münzen"),
        ("Weight  {0}", "Gewicht  {0}"), ("Length  {0}", "Länge  {0}"),
        ("STANDARD", "NORMAL"), ("GILDED", "VERGOLDET"), ("IRIDESCENT", "SCHILLERND"), ("ANCIENT", "URALT"),
        ("Bluegill", "Blauer Sonnenbarsch"), ("Roach", "Rotauge"), ("Perch", "Flussbarsch"),
        ("Crucian Carp", "Karausche"), ("Smallmouth Bass", "Schwarzbarsch"), ("Channel Catfish", "Kanalwels"),
        ("Rainbow Trout", "Regenbogenforelle"), ("Common Carp", "Karpfen"), ("Largemouth Bass", "Forellenbarsch"),
        ("Eel", "Aal"), ("Northern Pike", "Hecht"), ("Golden Trout", "Goldforelle"), ("Walleye", "Glasaugenbarsch"),
        ("Muskie", "Muskellunge"), ("Lake Sturgeon", "Seestör"), ("Redtail Catfish", "Rotflossenwels"),
        ("Alligator Gar", "Alligatorhecht"), ("Peacock Bass", "Pfauenaugenbarsch"), ("Giant Snakehead", "Riesenschlangenkopf"),
        ("Golden Koi", "Goldener Koi"), ("Ancient Sturgeon", "Uralter Stör"), ("Midnight Leviathan", "Mitternachtsleviathan"),
        ("Blacktip Shark", "Schwarzspitzenhai"), ("Blue Shark", "Blauhai"), ("Hammerhead Shark", "Hammerhai"),
        ("Whale Shark", "Walhai"), ("Swordfish", "Schwertfisch"), ("Moon Manta", "Mondmanta"),
        ("Starfall Manta", "Sternschnuppenmanta"), ("Sand Flounder", "Sandflunder"),
        ("Abyssal Oarfish", "Tiefsee-Riemenfisch"), ("Ocean Sunfish", "Mondfisch"), ("Atlantic Mackerel", "Atlantische Makrele"),
        ("WAVE {0}", "WELLE {0}"), ("SCORE {0}", "PUNKTE {0}"), ("HEADSHOT", "KOPFTREFFER"),
        ("HEAVY", "WUCHTIG"), ("PRECISION", "PRÄZISION"), ("THRUST", "STOSS"), ("SLASH", "HIEB"),
        ("HOLE IN ONE!", "MIT EINEM SCHLAG!"), ("NICE!", "STARK!"), ("GOOD!", "GUT!"),
        ("FIRST TO 5", "ZUERST 5 PUNKTE"), ("YOU SCORED", "DEIN PUNKT"), ("CPU SCORED", "CPU PUNKT"),
        ("CHALLENGE", "AUFGABE"), ("UNTOUCHABLE", "UNBERÜHRBAR"), ("PERFECT CUT", "PERFEKTER SCHNITT"),
        ("Preferences", "Einstellungen"), ("Settings…", "Einstellungen…"),
        ("Open WhyWait", "WhyWait öffnen"), ("Quit WhyWait", "WhyWait beenden"),
        ("Check for Updates…", "Nach Updates suchen…"), ("Play Last Game", "Letztes Spiel starten"),
        ("Play Last Game — {0}", "Letztes Spiel — {0}"),
        ("Resume  ·  {0}", "Weiter  ·  {0}"), ("Resume Last Game", "Letztes Spiel starten"),
        ("Surprise Me", "Zufälliges Spiel"), ("PLAY", "SPIELEN"), ("Launch {0}", "{0} starten"),
        ("LAST", "ZULETZT"), ("LAST PLAYED", "ZULETZT GESPIELT"),
        ("PLAY QUEUE", "SPIELAUSWAHL"), ("INTERMISSION READY", "BEREIT FÜR DIE PAUSE"),
        ("{0} ARTIFACTS  /  ONE ACTIVE", "{0} SPIELE  /  EINS AKTIV"),
        ("ACTIVE ARTIFACT  /  {0}", "AUSGEWÄHLT  /  {0}"),
        ("SYSTEM  /  LOCAL", "SYSTEM  /  LOKAL"), ("GENERAL", "ALLGEMEIN"),
        ("GAMEPLAY", "SPIEL"), ("BEHAVIOR", "VERHALTEN"), ("CONTROLS", "STEUERUNG"),
        ("Tune the intermission, keep the desktop quiet.", "Deine Pause. Dein Desktop."),
        ("Launch WhyWait at login", "Beim Anmelden starten"),
        ("Install WhyWait in Applications to enable launch at login.", "Lege WhyWait in Programme ab, um den Autostart zu aktivieren."),
        ("Approval required in System Settings → Login Items.", "Freigabe unter Systemeinstellungen → Anmeldeobjekte erforderlich."),
        ("Launch-at-login status is unavailable.", "Autostart-Status ist nicht verfügbar."),
        ("Launch at login unavailable: {0}", "Autostart nicht verfügbar: {0}"),
        ("Keep menu-bar icon enabled", "Menüleistensymbol anzeigen"),
        ("Global shortcut enabled", "Globalen Kurzbefehl aktivieren"),
        ("Automatically check for updates", "Automatisch nach Updates suchen"),
        ("Show game HUD", "Spielanzeigen einblenden"), ("Reduce visual effects", "Visuelle Effekte reduzieren"),
        ("Cursor trail effects", "Bewegungsspuren anzeigen"), ("Game object size", "Größe der Spielobjekte"),
        ("Escape returns to launcher", "Escape öffnet die Spielauswahl"),
        ("Reopen launcher after game ends", "Nach Spielende Auswahl öffnen"),
        ("LAUNCHES", "SPIELSTARTS"), ("PLAY TIME", "SPIELZEIT"), ("MOST PLAYED", "LIEBLINGSSPIEL"),
        ("FISH DISCOVERED", "FISCHE ENTDECKT"), ("COINS", "MÜNZEN"), ("TOTAL CATCHES", "FÄNGE GESAMT"),
        ("{0} launches", "{0} Spielstarts"), ("{0} fish", "{0} Fische"),
        ("Bank shots across your desktop.", "Golf mit Bande auf deinem Desktop."),
        ("Cursor-control a paddle against the CPU.", "Deine Maus gegen den Computer."),
        ("Swipe through fruit—avoid the bombs.", "Obst zerschneiden. Bomben ausweichen."),
        ("Swing through a momentum course.", "Mit Schwung durch den Parcours."),
        ("Cast, collect rare variants, and stock your Tidevault.", "Angeln, Varianten sammeln, Tidevault füllen."),
        ("Master a physical blade on a dummy.", "Meistere dein Schwert an der Puppe."),
        ("Survive waves with physics-based slashes.", "Überlebe mit Schwung und Schwert."),
        ("Pull back from the ball, read the desktop course, and sink each procedural hole in as few strokes as possible.", "Ziehe vom Ball zurück und versenke ihn mit möglichst wenigen Schlägen im nächsten Loch."),
        ("Move the right paddle with the cursor and use fast vertical swipes to shape skill-based returns against the CPU.", "Steuere den rechten Schläger mit der Maus. Schnelle Bewegungen geben deinen Schlägen Effet."),
        ("Turn quick cursor movement into a blade, build swipe combos, and preserve three lives while the pace climbs.", "Deine Maus wird zur Klinge. Sammle Kombos und schütze deine drei Leben, während das Tempo steigt."),
        ("Attach to open desktop space, preserve momentum, and thread checkpoints through a compact procedural course.", "Setze deinen Haken frei auf dem Desktop. Nutze den Schwung und erreiche die Kontrollpunkte der Reihe nach."),
        ("Cast into depth zones, manage line tension, archive prized catches, discover ocean species, and outfit your tackle room.", "Wirf in verschiedene Tiefen, kontrolliere die Schnurspannung und entdecke seltene Fische. Sammle Fänge und verbessere deine Ausrüstung."),
        ("Guide a weighted sword through spring physics and learn how speed, alignment, and contact point shape each strike.", "Führe ein träges Schwert mit der Maus. Tempo, Ausrichtung und Trefferpunkt bestimmen die Stärke deines Schlages."),
        ("Defend a fixed position from escalating waves using the same inertial sword—without attack buttons or canned swings.", "Verteidige deine Position gegen Zombie-Wellen – mit echter Schwertphysik, ohne Angriffstaste."),
        ("Drag from ball to shoot  ·  R reset  ·  Esc launcher", "Vom Ball ziehen: Schlag  ·  R Neustart  ·  Esc Auswahl"),
        ("Move mouse to paddle  ·  R reset  ·  Esc launcher", "Maus bewegt Schläger  ·  R Neustart  ·  Esc Auswahl"),
        ("Swipe quickly to slice  ·  R reset  ·  Esc launcher", "Schnell wischen: Schnitt  ·  R Neustart  ·  Esc Auswahl"),
        ("Hold left to grapple  ·  Release to detach  ·  R new course", "Linksklick halten: Haken  ·  Loslassen: lösen  ·  R Parcours"),
        ("Hold/release to cast  ·  D FishDex  ·  B Tidevault  ·  U shop", "Halten/loslassen: Wurf  ·  D FishDex  ·  B Tidevault  ·  U Laden"),
        ("Move mouse to swing  ·  Right-click recover  ·  R reset", "Maus schwingt Schwert  ·  Rechtsklick: bergen  ·  R Neustart"),
        ("Move mouse to swing  ·  Right-click recover  ·  R restart", "Maus schwingt Schwert  ·  Rechtsklick: bergen  ·  R Neustart"),
        ("↑↓  SELECT    RETURN  LAUNCH    ⌘,  PREFERENCES    ESC  HIDE    {0}  OPEN", "↑↓  AUSWAHL    ENTER  SPIELEN    ⌘,  EINSTELLUNGEN    ESC  AUSBLENDEN    {0}  ÖFFNEN"),
        ("THE TACKLE ROOM", "DIE ANGELSTUBE"), ("HAND-TUNED GEAR & TIDEBREAK SUPPLIES", "AUSRÜSTUNG FÜR DEINE NÄCHSTE ANGELPAUSE"),
        ("EQUIPMENT", "AUSRÜSTUNG"), ("LURES + VAULT", "KÖDER + ARCHIV"), ("ROD SHOP", "RUTENLADEN"),
        ("EQUIPPED", "AUSGERÜSTET"), ("EQUIP", "AUSRÜSTEN"), ("BUY  {0}", "KAUFEN  {0}"),
        ("REFINE  {0}", "AUFWERTEN  {0}"), ("EXPAND  {0}", "ERWEITERN  {0}"), ("U  CLOSE", "U  SCHLIESSEN"),
        ("D  CLOSE", "D  SCHLIESSEN"), ("B  CLOSE", "B  SCHLIESSEN"), ("FISH", "FISCHE"), ("TREASURES", "SCHÄTZE"),
        ("ROD", "RUTE"), ("REEL", "ROLLE"), ("LINE", "SCHNUR"), ("LINE!", "SCHNUR!"),
        ("HOOK", "HAKEN"), ("BAIT KIT", "KÖDERSET"), ("NEAR", "NAH"), ("MID", "MITTEL"), ("DEEP", "TIEF"),
        ("COMMON", "HÄUFIG"), ("UNCOMMON", "UNGEWÖHNLICH"), ("RARE", "SELTEN"), ("EPIC", "EPISCH"), ("LEGENDARY", "LEGENDÄR"),
        ("NEW SPECIES!", "NEUE ART!"), ("NEW RECORD", "NEUER REKORD"), ("LANDED", "GEFANGEN"),
        ("HOLD + RELEASE TO CAST", "HALTEN + LOSLASSEN ZUM AUSWERFEN"),
        ("CLICK WHEN IT BITES", "BEIM ANBISS KLICKEN"),
        ("HOLD TO REEL  ·  MOVE TO MANAGE TENSION", "HALTEN ZUM EINHOLEN  ·  MAUS STEUERT SPANNUNG"),
        ("FINISH CURRENT CAST", "BEENDE ZUERST DEN WURF"), ("LINE BROKE", "SCHNUR GERISSEN"),
        ("MISS", "VERPASST"), ("HOOK LOST", "FISCH ENTKOMMEN"), ("SPECIMEN LOCKED", "FANG GESPERRT"),
        ("SAVE CHANGED OR UNAVAILABLE · TRY AGAIN", "SPEICHERSTAND GEÄNDERT ODER NICHT VERFÜGBAR · ERNEUT VERSUCHEN"),
        ("Supple starter · easy, forgiving flex", "Weicher Einstieg · gutmütige Biegung"),
        ("+7% reach · smoother cast control", "+7% Reichweite · bessere Wurfkontrolle"),
        ("+14% reach · precise, fast recovery", "+14% Reichweite · präzise, schnelle Rückstellung"),
        ("+20% reach · +8% safe tension", "+20% Reichweite · +8% sichere Spannung"),
        ("NEED ¢ {0}", "BENÖTIGT ¢ {0}"), ("ALREADY MAX LEVEL", "BEREITS MAXIMALE STUFE"),
        ("+{0} COINS", "+{0} MÜNZEN"), ("STROKES {0}", "SCHLÄGE {0}"), ("HOLE IN {0}", "LOCH IN {0}"),
        ("YOU WIN", "GEWONNEN"), ("CPU WINS", "CPU GEWINNT"), ("GAME OVER", "SPIEL VORBEI"),
        ("YOU DIED", "BESIEGT"), ("MISSED", "VERPASST"), ("FINISH", "ZIEL"), ("CLEAN", "SAUBER"),
        ("PERFECT", "PERFEKT"), ("DESTROYED", "ZERSTÖRT"), ("CHALLENGE COMPLETE", "AUFGABE GESCHAFFT")
    ]
}
