import SwiftUI
import AppKit
import SceneKit
import UniformTypeIdentifiers
import Darwin

struct Style: Codable, Identifiable { var id = UUID(); var name: String; var hex: String; var png: Data? }
struct PriorIcon { var url: URL; var custom: Bool; var image: NSImage }
enum PrismError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
extension NSColor {
    convenience init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x80EFE2
        self.init(srgbRed: CGFloat((value >> 16) & 255)/255, green: CGFloat((value >> 8) & 255)/255, blue: CGFloat(value & 255)/255, alpha: 1)
    }
    var hex: String { let c = usingColorSpace(.sRGB) ?? self; return String(format: "#%02X%02X%02X", Int(c.redComponent*255), Int(c.greenComponent*255), Int(c.blueComponent*255)) }
}

enum FolderArtwork {
    static func back() -> NSBezierPath {
        let p = NSBezierPath(); p.move(to: NSPoint(x: 26,y: 146)); p.line(to: NSPoint(x: 26,y: 192))
        p.curve(to: NSPoint(x: 37,y: 202), controlPoint1: NSPoint(x: 26,y: 202), controlPoint2: NSPoint(x: 26,y: 202))
        p.line(to: NSPoint(x: 97,y: 202)); p.curve(to: NSPoint(x: 107,y: 197), controlPoint1: NSPoint(x: 103,y: 202), controlPoint2: NSPoint(x: 103,y: 202))
        p.line(to: NSPoint(x: 123,y: 180)); p.curve(to: NSPoint(x: 133,y: 176), controlPoint1: NSPoint(x: 126,y: 176), controlPoint2: NSPoint(x: 126,y: 176))
        p.line(to: NSPoint(x: 218,y: 176)); p.curve(to: NSPoint(x: 230,y: 164), controlPoint1: NSPoint(x: 230,y: 176), controlPoint2: NSPoint(x: 230,y: 176)); p.line(to: NSPoint(x: 230,y: 146)); p.close()
        return adjusted(p)
    }
    static func front() -> NSBezierPath {
        let p = NSBezierPath(); p.move(to: NSPoint(x: 30,y: 155)); p.line(to: NSPoint(x: 233,y: 155))
        p.curve(to: NSPoint(x: 241,y: 144), controlPoint1: NSPoint(x: 243,y: 155), controlPoint2: NSPoint(x: 243,y: 155))
        p.line(to: NSPoint(x: 225,y: 54)); p.curve(to: NSPoint(x: 210,y: 41), controlPoint1: NSPoint(x: 223,y: 41), controlPoint2: NSPoint(x: 223,y: 41)); p.line(to: NSPoint(x: 40,y: 41))
        p.curve(to: NSPoint(x: 28,y: 53), controlPoint1: NSPoint(x: 29,y: 41), controlPoint2: NSPoint(x: 29,y: 41)); p.line(to: NSPoint(x: 20,y: 143))
        p.curve(to: NSPoint(x: 30,y: 155), controlPoint1: NSPoint(x: 19,y: 155), controlPoint2: NSPoint(x: 19,y: 155)); p.close()
        return adjusted(p)
    }
    static func adjusted(_ p: NSBezierPath) -> NSBezierPath {
        let t = AffineTransform(m11: 1,m12: 0,m21: 0,m22: 0.92,tX: 0,tY: 9.68); p.transform(using: t); return p
    }
    static func icon(hex: String, png: Data?) -> NSImage {
        let image = NSImage(size: NSSize(width: 512,height: 512)); image.lockFocus(); defer { image.unlockFocus() }
        if let png = png, let source = NSImage(data: png) {
            let ratio = min(480/source.size.width,480/source.size.height)
            let size = NSSize(width: source.size.width*ratio,height: source.size.height*ratio)
            source.draw(in: NSRect(x: (512-size.width)/2,y: (512-size.height)/2,width: size.width,height: size.height)); return image
        }
        let transform = NSAffineTransform(); transform.scale(by: 2); transform.concat()
        let color = NSColor(hex: hex)
        NSGradient(starting: color.blended(withFraction: 0.24,of: .black)!, ending: color.blended(withFraction: 0.14,of: .black)!)!.draw(in: back(), angle: 90)
        NSGradient(starting: color.blended(withFraction: 0.10,of: .black)!, ending: color.blended(withFraction: 0.18,of: .white)!)!.draw(in: front(), angle: 90)
        let edge = front(); edge.lineWidth = 0.8; NSColor.white.withAlphaComponent(0.35).setStroke(); edge.stroke()
        return image
    }
}

final class PrismModel: ObservableObject {
    static let shared = PrismModel()
    @Published var folders: [URL] = []
    @Published var hex = "#80EFE2"
    @Published var png: Data?
    @Published var name = "Aurora"
    @Published var folderName = ""
    @Published var status = ""
    @Published var styles: [Style] = []
    @Published var canUndo = false
    @Published var effects = true
    @Published var language: String = UserDefaults.standard.string(forKey: "language") ?? "it"
    @Published var background: Data?
    @Published var backdrop = "#091226"
    var previous: [PriorIcon] = []
    var renameUndo: (URL,URL)?
    let dataURL: URL
    var dictionaries: [[String:Any]] = []
    init() {
        dataURL = FileManager.default.urls(for: .applicationSupportDirectory,in: .userDomainMask)[0].appendingPathComponent("NovaPrism", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataURL,withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: dataURL.appendingPathComponent("styles.json")), let list = try? JSONDecoder().decode([Style].self,from: data) { styles = list }
        if let url = Bundle.main.url(forResource: "Languages",withExtension: "json"), let data = try? Data(contentsOf: url), let root = try? JSONSerialization.jsonObject(with: data) as? [String:Any] { dictionaries = root["languages"] as? [[String:Any]] ?? [] }
        background = try? Data(contentsOf: dataURL.appendingPathComponent("background.png"))
        backdrop = UserDefaults.standard.string(forKey: "backdrop") ?? "#091226"
    }
    func text(_ key: String, _ fallback: String) -> String { let strings = dictionaries.first { $0["code"] as? String == language }?["strings"] as? [String:String]; return strings?[key] ?? fallback }
    func select(_ urls: [URL]) {
        folders = Array(Set(urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey,.isPackageKey])).map { $0.isDirectory == true && $0.isPackage != true } ?? false })).sorted { $0.path < $1.path }
        folderName = folders.count == 1 ? folders[0].lastPathComponent : ""; status = "\(folders.count) " + text("folders","cartelle")
    }
    func chooseFolders() { let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true; p.allowsMultipleSelection = true; if p.runModal() == .OK { select(p.urls) } }
    func choosePNG() { let p = NSOpenPanel(); p.allowedContentTypes = [.png]; if p.runModal() == .OK, let url = p.url { do { let data = try Data(contentsOf: url); guard NSImage(data: data) != nil, data.count < 30_000_000 else { throw PrismError.message("PNG non valido / Invalid PNG") }; png = data } catch { status = error.localizedDescription } } }
    func sample() { NSColorSampler().show { color in if let color = color { self.png = nil; self.hex = color.hex } } }
    func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { return }
        styles.append(Style(name: clean,hex: hex,png: png)); persist()
    }
    func persist() { do { try JSONEncoder().encode(styles).write(to: dataURL.appendingPathComponent("styles.json"),options: .atomic) } catch { status = error.localizedDescription } }
    func hasCustomIcon(_ url: URL) -> Bool {
        var bytes = [UInt8](repeating: 0,count: 32)
        let result = bytes.withUnsafeMutableBytes { getxattr(url.path,"com.apple.FinderInfo",$0.baseAddress,32,0,0) }
        return result >= 10 && (bytes[8] & 0x04) != 0
    }
    func apply() {
        guard !folders.isEmpty else { return }
        guard hex.range(of: "^#[0-9a-fA-F]{6}$",options: .regularExpression) != nil else { status = "Colore HEX non valido / Invalid HEX"; return }
        let snapshot = folders.map { PriorIcon(url: $0,custom: hasCustomIcon($0),image: NSWorkspace.shared.icon(forFile: $0.path)) }
        let image = FolderArtwork.icon(hex: hex,png: png); var changed: [PriorIcon] = []
        for prior in snapshot {
            guard FileManager.default.isWritableFile(atPath: prior.url.path), NSWorkspace.shared.setIcon(image,forFile: prior.url.path,options: []) else {
                let failed = changed.filter { !NSWorkspace.shared.setIcon($0.custom ? $0.image : nil,forFile: $0.url.path,options: []) }
                previous = failed; canUndo = !failed.isEmpty; status = "Impossibile modificare \(prior.url.lastPathComponent). \(failed.count) ripristini non riusciti."; return
            }; changed.append(prior)
        }
        previous = snapshot; renameUndo = nil; canUndo = true; status = "✓ \(folders.count) " + text("applied","cartelle aggiornate")
    }
    func undo() {
        do {
            if let (current,old) = renameUndo { try FileManager.default.moveItem(at: current,to: old); select([old]); renameUndo = nil }
            else { previous = previous.filter { !NSWorkspace.shared.setIcon($0.custom ? $0.image : nil,forFile: $0.url.path,options: []) }; if !previous.isEmpty { throw PrismError.message("Ripristino non riuscito / Restore failed") } }
            canUndo = false; status = text("undo","Annulla") + " ✓"
        } catch { status = error.localizedDescription }
    }
    func rename() {
        guard folders.count == 1 else { return }; let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains(":"), !name.contains("\0") else { status = "Nome non valido / Invalid name"; return }
        let old = folders[0], new = old.deletingLastPathComponent().appendingPathComponent(name,isDirectory: true)
        guard old != new else { return }
        do { if FileManager.default.fileExists(atPath: new.path) { throw PrismError.message("Nome già esistente / Name already exists") }; try FileManager.default.moveItem(at: old,to: new); select([new]); renameUndo = (new,old); previous = []; canUndo = true } catch { status = error.localizedDescription }
    }
    func transfer(importing: Bool) {
        do {
            if importing { let p = NSOpenPanel(); p.allowedContentTypes = [.json]; if p.runModal() == .OK, let url = p.url { let data = try Data(contentsOf: url); guard data.count < 60_000_000 else { throw PrismError.message("File troppo grande / File too large") }; let list = try JSONDecoder().decode([Style].self,from: data); guard list.allSatisfy({ $0.hex.range(of: "^#[0-9a-fA-F]{6}$",options: .regularExpression) != nil && ($0.png == nil || NSImage(data: $0.png!) != nil) }) else { throw PrismError.message("Palette non valida / Invalid palette") }; styles.append(contentsOf: list.map { Style(name:$0.name,hex:$0.hex,png:$0.png) }); persist() } }
            else { let p = NSSavePanel(); p.allowedContentTypes = [.json]; p.nameFieldStringValue = "NovaPrism-palette.json"; if p.runModal() == .OK, let url = p.url { try JSONEncoder().encode(styles).write(to: url,options: .atomic) } }
        } catch { status = error.localizedDescription }
    }
    func chooseBackground() { let p = NSOpenPanel(); p.allowedContentTypes = [.image]; if p.runModal() == .OK, let url = p.url, let data = try? Data(contentsOf: url), NSImage(data: data) != nil { background = data; try? data.write(to: dataURL.appendingPathComponent("background.png"),options: .atomic) } }
    func installService() {
        guard let service = Bundle.main.url(forResource: "Nova Prism",withExtension: "workflow") else { return }
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services",isDirectory:true), destination = folder.appendingPathComponent("Nova Prism.workflow")
        do { try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true); if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }; try FileManager.default.copyItem(at: service,to: destination); status = "Finder → Azioni rapide / Quick Actions → Nova Prism" } catch { status = error.localizedDescription }
    }
}

struct FolderScene: NSViewRepresentable {
    var hex: String; var png: Data?
    final class View: SCNView {
        var folder: SCNNode?; var last: NSPoint = .zero
        override func mouseDown(with event: NSEvent) { if event.clickCount == 2 { folder?.eulerAngles = SCNVector3Zero }; last = event.locationInWindow }
        override func mouseDragged(with event: NSEvent) { let p = event.locationInWindow; guard let node = folder else { return }; node.eulerAngles.y += CGFloat(p.x-last.x)*0.012; node.eulerAngles.x = min(1.3,max(-1.3,node.eulerAngles.x-CGFloat(p.y-last.y)*0.01)); last = p }
    }
    func makeNSView(context: Context) -> View {
        let view = View(); view.backgroundColor = .clear; view.antialiasingMode = .multisampling4X; view.scene = SCNScene()
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.usesOrthographicProjection = true; camera.camera?.orthographicScale = 170; camera.position = SCNVector3(0,0,700); view.scene!.rootNode.addChildNode(camera)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 600; view.scene!.rootNode.addChildNode(ambient)
        let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni; light.light?.intensity = 1000; light.position = SCNVector3(-180,220,300); view.scene!.rootNode.addChildNode(light)
        let folder = SCNNode(); view.folder = folder; view.scene!.rootNode.addChildNode(folder); return view
    }
    func updateNSView(_ view: View, context: Context) {
        guard let folder = view.folder else { return }; folder.childNodes.forEach { $0.removeFromParentNode() }
        if let png = png, let image = NSImage(data: png) { let plane = SCNPlane(width: 230,height: 230*image.size.height/image.size.width); plane.firstMaterial?.diffuse.contents = image; plane.firstMaterial?.isDoubleSided = true; folder.addChildNode(SCNNode(geometry: plane)); return }
        for (path,depth,z,dark) in [(FolderArtwork.back(),CGFloat(9),CGFloat(-7),true),(FolderArtwork.front(),CGFloat(9),CGFloat(0),false)] {
            let geometry = SCNShape(path: path,extrusionDepth: depth); geometry.chamferRadius = 1.2; geometry.chamferSegmentCount = 3
            let material = SCNMaterial(); material.lightingModel = .physicallyBased; material.diffuse.contents = dark ? NSColor(hex: hex).blended(withFraction:0.22,of:.black) : NSColor(hex: hex); material.metalness.contents = 0.15; material.roughness.contents = 0.32; geometry.materials = [material]
            let node = SCNNode(geometry: geometry); node.position = SCNVector3(-128,-128,z); folder.addChildNode(node)
        }
    }
}

struct Dock: View {
    @ObservedObject var model: PrismModel
    @State private var pointer: CGFloat = -1000
    let colors = [Style(name:"Aurora",hex:"#80EFE2"),Style(name:"Prisma",hex:"#A89BFF"),Style(name:"Plasma",hex:"#FF75B8"),Style(name:"Solar",hex:"#FFB05D"),Style(name:"Ion",hex:"#68BCFF"),Style(name:"Corallo",hex:"#FF766C"),Style(name:"Ice",hex:"#D5EDFF"),Style(name:"Obsidian",hex:"#7587A9"),Style(name:"Pulse",hex:"#C2FA60")]
    var body: some View {
        HStack(alignment:.bottom,spacing:12) {
            ForEach(Array(colors.enumerated()),id:\.element.id) { index, style in
                let distance = abs(pointer-(CGFloat(index)*60+24)); let weight = distance < 125 ? (1+cos(distance/125 * .pi))/2 : 0
                Button { model.png = nil; model.hex = style.hex; model.name = style.name } label: {
                    VStack(spacing:9) { RoundedRectangle(cornerRadius:10).fill(Color(nsColor:NSColor(hex:style.hex))).frame(width:48,height:32).overlay { if model.png == nil && model.hex == style.hex { Image(systemName:"checkmark.circle.fill").foregroundColor(.white).shadow(radius:2) } }; Text(style.name).font(.system(size:9)).foregroundColor(.white.opacity(0.85)) }
                }.buttonStyle(.plain).scaleEffect(1+weight*0.32,anchor:.bottom).offset(y:-weight*10)
            }
        }.padding(.horizontal,12).padding(.vertical,16).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:20))
        .onContinuousHover { phase in switch phase { case .active(let p): withAnimation(.easeOut(duration:0.09)) { pointer = p.x-12 }; case .ended: withAnimation(.easeOut(duration:0.15)) { pointer = -1000 } } }
    }
}

struct Studio: View {
    @ObservedObject var model = PrismModel.shared
    @State private var showLanguage = false
    var body: some View {
        ZStack {
            Color(nsColor:NSColor(hex:model.backdrop))
            if let data = model.background ?? (Bundle.main.url(forResource:"Nebulosa",withExtension:"png").flatMap { try? Data(contentsOf:$0) }), let image = NSImage(data:data) { Image(nsImage:image).resizable().scaledToFill().opacity(0.26).clipped() }
            RadialGradient(colors:[Color.cyan.opacity(0.12),.clear],center:.center,startRadius:20,endRadius:400)
            VStack(spacing:22) {
                HStack { VStack(alignment:.leading,spacing:4) { Text("N O V A  P R I S M").font(.system(size:25,weight:.light)); Text("C O L O R  S T U D I O  /  3.0").font(.system(size:9)).foregroundColor(.secondary) }; Spacer(); Button { model.chooseFolders() } label: { Label(model.text("chooseFolder","Scegli cartelle"),systemImage:"folder.badge.plus") }; Menu { ForEach(model.dictionaries,id:\.selfCode) { entry in Button(entry["nativeName"] as? String ?? "") { model.language = entry["code"] as? String ?? "it"; UserDefaults.standard.set(model.language,forKey:"language") } } } label: { Image(systemName:"globe") }; Menu { Button(model.text("import","Importa palette")) { model.transfer(importing:true) }; Button(model.text("export","Esporta palette")) { model.transfer(importing:false) }; Divider(); Button("Finder · Azione rapida / Quick Action") { model.installService() }; Button(model.text("background","Sfondo immagine")) { model.chooseBackground() }; ColorPicker("Sfondo / Background",selection:Binding(get:{Color(nsColor:NSColor(hex:model.backdrop))},set:{ model.backdrop = NSColor($0).hex; UserDefaults.standard.set(model.backdrop,forKey:"backdrop") })); Button("Ripristina sfondo / Reset background") { model.background = nil; try? FileManager.default.removeItem(at:model.dataURL.appendingPathComponent("background.png")) } } label: { Image(systemName:"ellipsis") } }
                HStack(alignment:.center,spacing:26) {
                    VStack(alignment:.leading,spacing:18) {
                        Text(model.text("color","Colore")).font(.title3.bold())
                        ColorPicker(model.text("custom","Scegli il colore"),selection:Binding(get:{Color(nsColor:NSColor(hex:model.hex))},set:{model.png = nil; model.hex = NSColor($0).hex}),supportsOpacity:false)
                        TextField("HEX",text:$model.hex).font(.system(.body,design:.monospaced))
                        RoundedRectangle(cornerRadius:18).fill(LinearGradient(colors:[.white,Color(nsColor:NSColor(hex:model.hex)),.black],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(height:140)
                        Button { model.sample() } label: { Label(model.text("pick","Campiona dallo schermo"),systemImage:"eyedropper") }
                    }.padding(22).frame(width:220).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22))
                    VStack(spacing:8) { Text("P R I S M  /  S Y N T H E S I S").font(.system(size:13,weight:.light)); Text("Trascina per ruotare · Doppio clic per ripristinare").font(.system(size:10)).foregroundColor(.secondary); FolderScene(hex:model.hex,png:model.png).frame(minWidth:340,minHeight:300); Ellipse().stroke(LinearGradient(colors:[.cyan.opacity(0.7),.purple.opacity(0.4)],startPoint:.leading,endPoint:.trailing),lineWidth:1).frame(height:30).padding(.horizontal,15); Dock(model:model).padding(.top,18) }.frame(maxWidth:.infinity)
                    VStack(spacing:22) {
                        VStack(alignment:.leading,spacing:14) { Text(model.text("image","Immagine")).font(.title3.bold()); Button { model.choosePNG() } label: { Label(model.text("upload","Carica PNG"),systemImage:"photo") }; if model.png != nil { Button(model.text("useColor","Usa il colore")) { model.png = nil } } }.frame(maxWidth:.infinity,alignment:.leading).padding(22).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22))
                        VStack(alignment:.leading,spacing:12) { Text(model.text("saved","I tuoi stili")).font(.title3.bold()); TextField(model.text("name","Nome"),text:$model.name); Button { model.save() } label: { Label(model.text("save","Salva stile"),systemImage:"plus") }; ScrollView { LazyVGrid(columns:[GridItem(.adaptive(minimum:64))],spacing:14) { ForEach(model.styles) { style in Button { model.name = style.name; model.hex = style.hex; model.png = style.png } label: { VStack { Image(nsImage:FolderArtwork.icon(hex:style.hex,png:style.png)).resizable().scaledToFit().frame(height:42); Text(style.name).font(.system(size:10)).lineLimit(2) } }.buttonStyle(.plain).contextMenu { Button(model.text("rename","Rinomina")) { let alert = NSAlert(); alert.messageText = model.text("rename","Rinomina"); let field = NSTextField(string:style.name); field.frame = NSRect(x:0,y:0,width:220,height:24); alert.accessoryView = field; alert.addButton(withTitle:"OK"); alert.addButton(withTitle:model.text("cancel","Annulla")); if alert.runModal() == .alertFirstButtonReturn, let i = model.styles.firstIndex(where:{$0.id == style.id}), !field.stringValue.isEmpty { model.styles[i].name = field.stringValue; model.persist() } }; Button(model.text("delete","Elimina")) { model.styles.removeAll {$0.id == style.id}; model.persist() } } } } }.frame(height:140) }.padding(22).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22))
                    }.frame(width:250)
                }
                HStack { Text(model.status).font(.system(size:11)).foregroundColor(.secondary).frame(maxWidth:.infinity,alignment:.leading); if model.folders.count == 1 { TextField("Cartella",text:$model.folderName).frame(width:220); Button { model.rename() } label: { Image(systemName:"pencil") } }; Button(model.text("apply","Applica alla cartella")) { model.apply() }.buttonStyle(.borderedProminent).tint(.cyan).disabled(model.folders.isEmpty); Button(model.text("undo","Annulla")) { model.undo() }.disabled(!model.canUndo) }
            }.padding(28)
        }.preferredColorScheme(.dark).frame(minWidth:1100,minHeight:710).onAppear { showLanguage = UserDefaults.standard.string(forKey:"language") == nil }
        .sheet(isPresented:$showLanguage) { VStack(spacing:18) { Text("Nova Prism").font(.title); Text("Scegli la lingua / Choose your language"); Picker("",selection:$model.language) { ForEach(model.dictionaries,id:\.selfCode) { entry in Text(entry["nativeName"] as? String ?? "").tag(entry["code"] as? String ?? "it") } }.frame(width:260); Button("Continua / Continue") { UserDefaults.standard.set(model.language,forKey:"language"); showLanguage = false } }.padding(35) }
    }
}
extension Dictionary where Key == String, Value == Any { var selfCode: String { self["code"] as? String ?? "" } }
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication,openFiles filenames: [String]) { PrismModel.shared.select(filenames.map { URL(fileURLWithPath:$0) }); NSApp.activate(ignoringOtherApps:true); sender.reply(toOpenOrPrint:.success) }
}
@main struct NovaPrism: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    init() { if CommandLine.arguments.contains("--self-test") { do { try SelfTest.run(); print("OK: macOS native icons, restore, rename, palettes and 3D"); exit(0) } catch { fputs("\(error)\n",stderr); exit(1) } } }
    var body: some Scene { WindowGroup("Nova Prism") { Studio() }.windowStyle(.hiddenTitleBar) }
}
enum SelfTest {
    static func run() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("prism-test-\(UUID())"); try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true); defer { try? FileManager.default.removeItem(at:root) }
        let folder = root.appendingPathComponent("Folder"); try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let model = PrismModel.shared; model.select([folder]); model.apply(); guard model.canUndo,model.hasCustomIcon(folder) else { throw PrismError.message("Icon application failed") }; model.undo(); guard !model.canUndo,!model.hasCustomIcon(folder) else { throw PrismError.message("Undo failed") }
        model.folderName = "Renamed"; model.rename(); guard model.folders.first?.lastPathComponent == "Renamed" else { throw PrismError.message("Rename failed") }; model.undo(); guard FileManager.default.fileExists(atPath:folder.path) else { throw PrismError.message("Rename undo failed") }
        let data = try JSONEncoder().encode([Style(name:"A",hex:"#FF8866")]); guard try JSONDecoder().decode([Style].self,from:data).count == 1 else { throw PrismError.message("Palette roundtrip failed") }
        let shape = SCNShape(path:FolderArtwork.front(),extrusionDepth:9); guard shape.extrusionDepth == 9 else { throw PrismError.message("3D extrusion failed") }
    }
}
