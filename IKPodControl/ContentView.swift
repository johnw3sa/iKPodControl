//
//  ContentView.swift
//  IKPodControl
//
//  Created by John Eigenbrode on 7/22/25.
//

import SwiftUI
import Combine

// MARK: - Macro Management

struct Macro: Codable, Identifiable {
    var id = UUID()
    var name: String
    var commands: [String]
    var delay: TimeInterval = 0.1
    
    init(name: String, commands: [String] = []) {
        self.name = name
        self.commands = commands
    }
}

class MacroManager: ObservableObject {
    @Published var tapMacros: [Int: Macro] = [:]
    @Published var holdMacros: [Int: Macro] = [:]
    @Published var encoderCWMacros: [Macro] = []
    @Published var encoderCCWMacros: [Macro] = []
    
    private let userDefaults = UserDefaults.standard
    private let macrosKey = "KPodMacros"
    
    init() {
        loadMacros()
    }
    
    func saveMacros() {
        let data = MacroData(
            tapMacros: tapMacros,
            holdMacros: holdMacros,
            encoderCWMacros: encoderCWMacros,
            encoderCCWMacros: encoderCCWMacros
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: macrosKey)
        }
    }
    
    private func loadMacros() {
        guard let data = userDefaults.data(forKey: macrosKey),
              let decoded = try? JSONDecoder().decode(MacroData.self, from: data) else {
            setupDefaultMacros()
            return
        }
        
        tapMacros = decoded.tapMacros
        holdMacros = decoded.holdMacros
        encoderCWMacros = decoded.encoderCWMacros
        encoderCCWMacros = decoded.encoderCCWMacros
    }
    
    private func setupDefaultMacros() {
        // Setup default macros for each button
        for i in 0...7 {
            tapMacros[i] = Macro(name: "Button \(i+1) Tap", commands: [""])
            holdMacros[i] = Macro(name: "Button \(i+1) Hold", commands: [""])
        }
        encoderCWMacros = [Macro(name: "Encoder CW", commands: [""])]
        encoderCCWMacros = [Macro(name: "Encoder CCW", commands: [""])]
        saveMacros()
    }
}

struct MacroData: Codable {
    let tapMacros: [Int: Macro]
    let holdMacros: [Int: Macro]
    let encoderCWMacros: [Macro]
    let encoderCCWMacros: [Macro]
}

// MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var hidManager = KPodHIDManager()
    @StateObject private var macroManager = MacroManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StatusView(hidManager: hidManager)
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("Status")
                }
                .tag(0)
            
            MacroEditorView(macroManager: macroManager)
                .tabItem {
                    Image(systemName: "text.cursor")
                    Text("Macros")
                }
                .tag(1)
            
            ControlView(hidManager: hidManager)
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Controls")
                }
                .tag(2)
        }
        .frame(minWidth: 150, minHeight: 700)
    }
}

struct StatusView: View {
    @ObservedObject var hidManager: KPodHIDManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("KPod Interface")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 10) {
                HStack {
                    Circle()
                        .fill(hidManager.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(hidManager.isConnected ? "Connected" : "Disconnected")
                        .fontWeight(.semibold)
                }
                
                Text(hidManager.deviceInfo)
                    .foregroundColor(.secondary)
            }
            
            if let report = hidManager.lastReport {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Report:")
                        .font(.headline)
                    
                    Group {
                        Text("Encoder Ticks: \(report.ticks)")
                        Text("Button States: \(String(report.buttonStates, radix: 2).paddingToLeft(upTo: 8, using: "0"))")
                        Text("Tap/Hold: \(report.isTapHold ? "Hold" : "Tap")")
                        Text("Rocker Position: \(rockerPositionName(report.rockerPosition))")
                    }
                    .font(.monospaced(.body)())
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack(spacing: 20) {
                Button("Get Device Info") {
                    hidManager.getDeviceInfo()
                }
                
                Button("Get Version") {
                    hidManager.getVersion()
                }
                
                Button("Test Beep") {
                    hidManager.beep()
                }
            }
            .disabled(!hidManager.isConnected)
            
            Spacer()
        }
        .padding()
    }
    
    private func rockerPositionName(_ position: UInt8) -> String {
        switch position {
        case 0: return "Center (VFO B)"
        case 1: return "Right (RIT/XIT)"
        case 2: return "Left (VFO A)"
        default: return "Error"
        }
    }
}

struct MacroEditorView: View {
    @ObservedObject var macroManager: MacroManager
    @State private var selectedButton = 0
    @State private var selectedMacroType = 0 // 0 = Tap, 1 = Hold
    
    var body: some View {
        HSplitView {
            VStack {
                Text("Button Selection")
                    .font(.headline)
                
                Picker("Button", selection: $selectedButton) {
                    ForEach(0..<8) { i in
                        Text("Button \(i + 1)").tag(i)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Picker("Action Type", selection: $selectedMacroType) {
                    Text("Tap").tag(0)
                    Text("Hold").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
            }
            .frame(minWidth: 100)
            .padding()
            
            VStack {
                Text("Macro Editor")
                    .font(.headline)
                
                if currentMacro != nil {
                    MacroDetailView(macro: binding(for: selectedButton, type: selectedMacroType))
                } else {
                    Text("No macro selected")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            macroManager.saveMacros()
        }
    }
    
    private var currentMacro: Macro? {
        if selectedMacroType == 0 {
            return macroManager.tapMacros[selectedButton]
        } else {
            return macroManager.holdMacros[selectedButton]
        }
    }
    
    private func binding(for button: Int, type: Int) -> Binding<Macro> {
        if type == 0 {
            return Binding(
                get: { macroManager.tapMacros[button] ?? Macro(name: "Button \(button + 1) Tap") },
                set: {
                    macroManager.tapMacros[button] = $0
                    macroManager.saveMacros()
                }
            )
        } else {
            return Binding(
                get: { macroManager.holdMacros[button] ?? Macro(name: "Button \(button + 1) Hold") },
                set: {
                    macroManager.holdMacros[button] = $0
                    macroManager.saveMacros()
                }
            )
        }
    }
}



struct MacroDetailView: View {
    @Binding var macro: Macro
    @State private var newCommand = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextField("Macro Name", text: $macro.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Commands:")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(0..<macro.commands.count, id: \.self) { index in
                            HStack {
                                TextField("Command \(index + 1)", text: Binding(
                                    get: { macro.commands[index] },
                                    set: { macro.commands[index] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: {
                                    macro.commands.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                HStack {
                    TextField("New Command", text: $newCommand)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addCommand()
                        }
                    
                    Button("Add", action: addCommand)
                }
            }
            
            HStack {
                Text("Delay between commands:")
                TextField("Delay (seconds)", value: $macro.delay, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            Spacer()
        }
        
    }
    
    private func addCommand() {
        if !newCommand.isEmpty {
            macro.commands.append(newCommand)
            newCommand = ""
        }
    }
}

struct ControlView: View {
    @ObservedObject var hidManager: KPodHIDManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("KPod Controls")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            GroupBox("Configuration") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Encoder Scale (100 counts/rev)", isOn: $hidManager.encoderScale)
                        .onChange(of: hidManager.encoderScale) { _, _ in
                            hidManager.configure()
                        }
                    
                    Toggle("Beeper Mute", isOn: $hidManager.muteEnabled)
                        .onChange(of: hidManager.muteEnabled) { _, _ in
                            hidManager.configure()
                        }
                }
                .padding()
            }
            
            GroupBox("LED Control") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(1...4, id: \.self) { led in
                        Toggle("LED \(led)", isOn: Binding(
                            get: { (hidManager.ledStates & (1 << (led - 1))) != 0 },
                            set: { isOn in
                                if isOn {
                                    hidManager.ledStates |= (1 << (led - 1))
                                } else {
                                    hidManager.ledStates &= ~(1 << (led - 1))
                                }
                                hidManager.setLEDs()
                            }
                        ))
                    }
                }
                .padding()
            }
            
            GroupBox("AUX Output Control") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(1...3, id: \.self) { aux in
                        Toggle("AUX \(aux)", isOn: Binding(
                            get: { (hidManager.auxStates & (1 << (aux - 1))) != 0 },
                            set: { isOn in
                                if isOn {
                                    hidManager.auxStates |= (1 << (aux - 1))
                                } else {
                                    hidManager.auxStates &= ~(1 << (aux - 1))
                                }
                                hidManager.setLEDs()
                            }
                        ))
                    }
                }
                .padding()
            }
            
            GroupBox("Beep Control") {
                VStack(spacing: 10) {
                    HStack {
                        Button("1000 Hz") { hidManager.beep(frequency: 0) }
                        Button("1500 Hz") { hidManager.beep(frequency: 1) }
                        Button("2000 Hz") { hidManager.beep(frequency: 2) }
                        Button("500 Hz") { hidManager.beep(frequency: 3) }
                    }
                    
                    HStack {
                        Button("Low") { hidManager.beep(level: 0) }
                        Button("Medium") { hidManager.beep(level: 1) }
                        Button("High") { hidManager.beep(level: 2) }
                    }
                }
                .padding()
            }
            
            Button("Reset Device") {
                hidManager.resetDevice()
            }
            .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .disabled(!hidManager.isConnected)
    }
}

// MARK: - KPod Communication Protocol

struct KPodCommand {
    var cmd: UInt8
    var data: [UInt8]
    
    init(command: UInt8, data: [UInt8] = Array(repeating: 0, count: 7)) {
        self.cmd = command
        self.data = Array(data.prefix(7) + Array(repeating: 0, count: max(0, 7 - data.count)))
    }
    
    var bytes: [UInt8] {
        return [cmd] + data
    }
}

struct KPodReport {
    let cmd: UInt8
    let ticks: Int16
    let controls: UInt8
    let spare: [UInt8]
    
    init(from data: [UInt8]) {
        cmd = data[0]
        ticks = Int16(data[1]) | (Int16(data[2]) << 8)
        controls = data[3]
        spare = Array(data[4...7])
    }
    
    var buttonStates: UInt8 {
        return controls & 0x0F
    }
    
    var isTapHold: Bool {
        return (controls & 0x10) != 0
    }
    
    var rockerPosition: UInt8 {
        return (controls & 0x60) >> 5
    }
}

// MARK: - HID Communication Manager

class KPodHIDManager: ObservableObject {
    // Removed 'objectWillChange: ObservableObjectPublisher'

    @Published var isConnected = false
    @Published var deviceInfo = ""
    @Published var lastReport: KPodReport?
    @Published var ledStates: UInt8 = 0
    @Published var auxStates: UInt8 = 0
    @Published var encoderScale: Bool = false // false = 200 counts, true = 100 counts
    @Published var muteEnabled: Bool = false
    
    private var hidManager: IOHIDManager?
    private var device: IOHIDDevice?
    private let vendorID = 0x04D8
    private let productID = 0xF12D
    
    private var inputReportBuffer: UnsafeMutablePointer<UInt8>?
    
    init() {
        setupHIDManager()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let manager = hidManager else {
            print("Failed to create HID manager")
            return
        }
        
        let matchingDict = [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDProductIDKey: productID
        ] as CFDictionary
        
        IOHIDManagerSetDeviceMatching(manager, matchingDict)
        
        let matchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let manager = Unmanaged<KPodHIDManager>.fromOpaque(context!).takeUnretainedValue()
            manager.deviceConnected(device)
        }
        
        let removalCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let manager = Unmanaged<KPodHIDManager>.fromOpaque(context!).takeUnretainedValue()
            manager.deviceDisconnected(device)
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, matchingCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, removalCallback, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    private func deviceConnected(_ hidDevice: IOHIDDevice) {
        DispatchQueue.main.async {
            self.device = hidDevice
            self.isConnected = true
            self.deviceInfo = "KPod Connected"
            self.setupInputCallback()
            self.getDeviceInfo()
        }
    }
    
    private func deviceDisconnected(_ hidDevice: IOHIDDevice) {
        DispatchQueue.main.async {
            if self.device == hidDevice {
                self.device = nil
                self.isConnected = false
                self.deviceInfo = "KPod Disconnected"
            }
        }
    }
    
    private func setupInputCallback() {
        guard let device = device else { return }
        
        // Deallocate previous buffer if allocated
        self.inputReportBuffer?.deallocate()
        self.inputReportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
        self.inputReportBuffer?.initialize(repeating: 0, count: 8)
        
        let inputCallback: IOHIDReportCallback = { context, result, sender, type, reportID, report, reportLength in
            let manager = Unmanaged<KPodHIDManager>.fromOpaque(context!).takeUnretainedValue()
            manager.handleInputReport(report, length: reportLength)
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, self.inputReportBuffer!, 8, inputCallback, context)
    }
    
    private func handleInputReport(_ report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard length >= 8 else { return }
        
        var data = [UInt8](repeating: 0, count: 8)
        for i in 0..<8 {
            data[i] = report[i]
        }
        
        DispatchQueue.main.async {
            self.lastReport = KPodReport(from: data)
        }
    }
    
    // MARK: - Command Functions
    
    func sendCommand(_ command: KPodCommand) {
        guard let device = device else { return }
        
        let data = command.bytes
        data.withUnsafeBytes { bytes in
            if let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress {
                IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, baseAddress, data.count)
            }
        }
        
        // Read response
        requestUpdate()
    }
    
    func requestUpdate() {
        let cmd = KPodCommand(command: UInt8(Character("u").asciiValue!))
        sendCommand(cmd)
    }
    
    func getDeviceInfo() {
        let cmd = KPodCommand(command: UInt8(Character("=").asciiValue!))
        sendCommand(cmd)
    }
    
    func getVersion() {
        let cmd = KPodCommand(command: UInt8(Character("v").asciiValue!))
        sendCommand(cmd)
    }
    
    func resetDevice() {
        let cmd = KPodCommand(command: UInt8(Character("r").asciiValue!))
        sendCommand(cmd)
    }
    
    func configure() {
        var configByte: UInt8 = 0
        if encoderScale { configByte |= 0x02 }
        if muteEnabled { configByte |= 0x01 }
        
        let cmd = KPodCommand(command: UInt8(Character("C").asciiValue!), data: [configByte])
        sendCommand(cmd)
    }
    
    func setLEDs() {
        let controlByte = (ledStates << 3) | auxStates
        let cmd = KPodCommand(command: UInt8(Character("O").asciiValue!), data: [controlByte])
        sendCommand(cmd)
    }
    
    func beep(frequency: UInt8 = 0, level: UInt8 = 1, duration: UInt8 = 10) {
        let cmd = KPodCommand(command: UInt8(Character("Z").asciiValue!), data: [frequency, level, duration])
        sendCommand(cmd)
    }
    
    private func cleanup() {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }
        self.inputReportBuffer?.deallocate()
        self.inputReportBuffer = nil
    }
}

extension String {
    func paddingToLeft(upTo length: Int, using character: Character) -> String {
        if self.count < length {
            return String(repeating: character, count: length - self.count) + self
        } else {
            return self
        }
    }
}



#Preview {
    ContentView()
}

