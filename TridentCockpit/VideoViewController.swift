/////
////  VideoViewController.swift
///   Copyright © 2019 Dmitriy Borovikov. All rights reserved.
//

import Cocoa
import SceneKit
import FastRTPSBridge

class VideoViewController: NSViewController, NSWindowDelegate {
    @IBOutlet weak var videoView: VideoView!
    @IBOutlet weak var depthLabel: NSTextField!
    @IBOutlet weak var tempLabel: NSTextField!
    @IBOutlet weak var batteryTimeLabel: NSTextField!
    @IBOutlet weak var cameraTimeLabel: NSTextField!
    @IBOutlet weak var recordingTimeLabel: NSTextField!

    @IBOutlet weak var indicatorsView: NSView!
    @IBOutlet weak var cameraControlView: CameraControlView!
    @IBOutlet weak var propellerButton: NSButton!
    @IBOutlet weak var lightButton: NSButton!
    @IBOutlet weak var recordingButton: FlatButton!
    @IBOutlet weak var tridentView: RovModelView!

    private var videoDecoder: VideoDecoder!
    private let tridentControl = TridentControl()
    
    private var lightOn = false
    private var videoSessionId: UUID?
    private var vehicleId: String?
    private var rovBeacon: RovBeacon?
    
    private var depth: Float = 0 {
        didSet { depthLabel.stringValue = String(format: "%.1f", depth) }
    }
    private var temperature: Double = 0 {
        didSet { tempLabel.stringValue = String(format: "%.1f", temperature) }
    }
    
    private var batteryTime: Int32 = 0 {
        didSet {
            var time = ""
            guard batteryTime != 65535 else {
                batteryTimeLabel.stringValue = time + "charging"
                return
            }
            if batteryTime / 60 != 0 {
                time += String(batteryTime / 60) + "h"
            }
            if batteryTime % 60 != 0 {
                time += String(batteryTime % 60) + "m"
            }
            batteryTimeLabel.stringValue = time
        }
    }

    private var cameraTime: UInt32 = 0 {
        didSet {
            var time = "Remaining time:\n"
            if cameraTime / 60 != 0 {
                time += String(cameraTime / 60) + "h "
            }
            if cameraTime % 60 != 0 {
                time += String(cameraTime % 60) + "m"
            }
            cameraTimeLabel.stringValue = time
        }
    }

    #if DEBUG
    deinit {
        print("Deinit VideoViewController")
    }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        depthLabel.stringValue = "n/a"
        tempLabel.stringValue = "n/a"
        batteryTimeLabel.stringValue = "n/a"
        cameraTimeLabel.stringValue = ""
        recordingTimeLabel.stringValue = ""
        cameraTimeLabel.textColor = .systemGray
        cameraControlView.isHidden = true
        
        indicatorsView.wantsLayer = true
        indicatorsView.layer?.backgroundColor = NSColor(named: "cameraControlBackground")!.cgColor
        lightButton.roundCorners(withRadius: 5)
        lightButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        
        let node = tridentView.modelNode()
        node.orientation = RovQuaternion(x: -0.119873046875, y: 0.99249267578125, z: 0.01611328125, w: 0.01910400390625).scnQuaternion()
        
        tridentControl.setup(delegate: self)
        videoDecoder = VideoDecoder(sampleBufferLayer: videoView.sampleBufferLayer)
        view.wantsLayer = true
        view.layer?.contents = NSImage(named: "Trident")

        #if DEBUG
        setupNotifications()
        #endif
    }

    func windowWillClose(_ notification: Notification) {
        tridentControl.disable()
        stopRTPS()
        videoDecoder.destroyVideoSession()
        DisplayManage.enableSleep()
    }
    
    func windowDidResize(_ notification: Notification) {
        cameraControlView.windowDidResize()
        tridentView.windowDidResize()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.title = "Connecting to Trident..."
        view.window?.delegate = self
        cameraControlView.addConstraints()
        tridentView.addConstraints()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if #available(OSX 10.15, *) {} else {
            DisplayManage.disableSleep()
        }
        
        getConnection()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        tridentControl.disable()
        FastRTPS.removeReader(topic: .rovCamFwdH2640Video)
        if #available(OSX 10.15, *) {} else {
            DisplayManage.enableSleep()
        }
    }
    
    @IBAction func recordingButtonPress(_ sender: Any) {
        switchRecording()
    }
    
    @IBAction func lightButtonPress(_ sender: Any) {
        switchLight()
    }
    
    @IBAction func propellerButtonPress(_ sender: Any) {
        guard tridentControl.motorSpeed != nil else { return }
        let newSpeed = tridentControl.motorSpeed!.rawValue + 1
        tridentControl.motorSpeed = TridentControl.MotorSpeed(rawValue: newSpeed)
        if tridentControl.motorSpeed == nil {
            tridentControl.motorSpeed = .first
        }
        updatePropellerButtonState()
    }
    
    @IBAction func relativeYawAction(_ sender: Any) {
        let node = tridentView.modelNode()
        let o = node.orientation
        let q = RovQuaternion(x: Double(-o.x), y: Double(-o.z), z: Double(-o.y), w: Double(o.w))
        tridentView.setCameraPos(yaw: Float(-q.yaw))

        NSApplication.shared.mainMenu?.recursiveSearch(tag: 11)!.state = .on
        NSApplication.shared.mainMenu?.recursiveSearch(tag: 12)!.state = .off
    }
    
    @IBAction func absoluteYawAction(_ sender: Any) {
        tridentView.setCameraPos(yaw: .pi)
        
        NSApplication.shared.mainMenu?.recursiveSearch(tag: 11)!.state = .off
        NSApplication.shared.mainMenu?.recursiveSearch(tag: 12)!.state = .on
    }
    
    @IBAction func stabilizeAction(_ sender: Any) {
        let controllerStatus = RovControllerStatus(vehicleId: vehicleId ?? "",
                                                   controllerId: .trident,
                                                   state: !Preference.tridentStabilize ? .enabled : .disabled)
        FastRTPS.send(topic: .rovControllerStateRequested, ddsData: controllerStatus)
    }
    
    @IBAction func telemetryOverlayAction(_ sender: Any) {
        FastRTPS.send(topic: .rovVideoOverlayModeCommand, ddsData: !Preference.videoOverlayMode ? "on" : "off")
    }
    
    override func keyUp(with event: NSEvent) {
        if !tridentControl.processKeyEvent(event: event) {
            super.keyUp(with: event)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if !tridentControl.processKeyEvent(event: event) {
            super.keyDown(with: event)
        }
    }
    
    private func setTelemetryOverlay(mode: String) {
        switch mode {
        case "on":
            Preference.videoOverlayMode = true
        case "off":
            Preference.videoOverlayMode = false
        default:
            print("illegal mode:", mode)
        }
        
        let menuItem = NSApplication.shared.mainMenu?.recursiveSearch(tag: 4)
        menuItem!.state = Preference.videoOverlayMode ? .on:.off
    }
    
    private func setController(status: RovControllerStatus) {
        guard status.controllerId == .trident else { return }
        Preference.tridentStabilize = (status.state == .enabled)
        
        let menuItem = NSApplication.shared.mainMenu?.recursiveSearch(tag: 3)
        menuItem!.state = Preference.tridentStabilize ? .on:.off
    }
       
    private func getConnection() {
        var interfaceAddresses: Set<String> = []
        DispatchQueue.global(qos: .userInteractive).async {
            repeat {
                interfaceAddresses = FastRTPS.getIP4Address()
                if interfaceAddresses.isEmpty {
                    Thread.sleep(forTimeInterval: 0.5)
                }
            } while interfaceAddresses.isEmpty
            self.startRTPS(addresses: interfaceAddresses)
        }
    }

    private func startRTPS(addresses: Set<String>) {
        print(addresses)
        let address = addresses.first { $0.starts(with: "10.1.1.") } ?? addresses.first!
        let network = address + "/24"
        FastRTPS.createParticipant(interfaceIPv4: address, networkAddress: network)
        registerReaders()
        registerWriters()
    }
    
    private func stopRTPS() {
        FastRTPS.resignAll()
        FastRTPS.stopRTPS()
    }

    private func rovProvision(rovBeacon: RovBeacon) {
        self.rovBeacon = rovBeacon
        self.vehicleId = rovBeacon.uuid
        view.window?.title = rovBeacon.uuid
        cameraControlView.isHidden = false

        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            self.view.layer?.contents = nil
        }
        tridentControl.enable()

        let timeMs = UInt(Date().timeIntervalSince1970 * 1000)
        FastRTPS.send(topic: .rovDatetime, ddsData: String(timeMs))
        FastRTPS.send(topic: .rovVideoOverlayModeCommand, ddsData: Preference.videoOverlayMode ? "on" : "off")
        let videoReq = RovVideoSessionCommand(sessionID: "", metadata: "", request: .stopped, response: .unknown, reason: "")
        FastRTPS.send(topic: .rovVidSessionReq, ddsData: videoReq)
        let lightPower = RovLightPower(id: "fwd", power: 0)
        FastRTPS.send(topic: .rovLightPowerRequested, ddsData: lightPower)
        let controllerStatus = RovControllerStatus(vehicleId: vehicleId ?? "",
                                                   controllerId: .trident,
                                                   state: Preference.tridentStabilize ? .enabled : .disabled)
        FastRTPS.send(topic: .rovControllerStateRequested, ddsData: controllerStatus)

        FastRTPS.removeReader(topic: .rovBeacon)
    }
    
    private func registerReaders() {
        FastRTPS.registerReader(topic: .rovCamFwdH2640Video) { [weak self] (videoData: RovVideoData) in
            self?.videoDecoder.decodeVideo(data: videoData.data, timestamp: videoData.timestamp)
        }

        FastRTPS.registerReader(topic: .rovTempWater) { [weak self] (temp: RovTemperature) in
            DispatchQueue.main.async {
                self?.temperature = temp.temperature.temperature
            }
        }
        
        FastRTPS.registerReader(topic: .rovDepth) { [weak self] (depth: RovDepth) in
            DispatchQueue.main.async {
                self?.depth = depth.depth
            }
        }
        
        FastRTPS.registerReader(topic: .rovFuelgaugeHealth) { [weak self] (health: RovFuelgaugeHealth) in
            DispatchQueue.main.async {
                self?.batteryTime = health.average_time_to_empty_mins
            }
        }
        
        FastRTPS.registerReader(topic: .rovRecordingStats) { [weak self] (recordingStats: RovRecordingStats) in
            DispatchQueue.main.async {
                self?.cameraTime = recordingStats.estRemainingRecTimeS / 60
            }
        }
        
        FastRTPS.registerReader(topic: .rovAttitude) { [weak self] (attitude: RovAttitude) in
            let node = self?.tridentView.modelNode()
            let orientation = attitude.orientation
            node?.orientation = orientation.scnQuaternion()
//            print((1 + orientation.yaw / .pi) * 180)
        }
        
        FastRTPS.registerReader(topic: .rovVidSessionCurrent) { [weak self] (videoSession: RovVideoSession) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch videoSession.state {
                case .unknown:
                    break
                case .recording:
                    if self.videoSessionId == nil {
                        self.videoSessionId = UUID(uuidString: videoSession.sessionID)
                    }
                    let sec = videoSession.totalDurationS % 60
                    let min = (videoSession.totalDurationS / 60)
                    let hour = videoSession.totalDurationS / 3600
                    self.recordingTimeLabel.stringValue = String(format: "%2.2d:%2.2d:%2.2d", hour, min, sec)
                    
                    self.recordingButton.activeButtonColor = NSColor(named: "recordActive")!
                    self.recordingButton.buttonColor = NSColor(named: "recordNActive")!
                    self.cameraTimeLabel.textColor = .white

                case .stopped:
                    self.videoSessionId = nil
                    self.recordingTimeLabel.stringValue = ""
                    self.cameraTimeLabel.textColor = .systemGray
                    self.recordingButton.activeButtonColor = NSColor(named: "stopActive")!
                    self.recordingButton.buttonColor = NSColor(named: "stopNActive")!
                }
            }
        }
        
        FastRTPS.registerReader(topic: .rovVidSessionRep) { [weak self] (videoSessionCommand: RovVideoSessionCommand) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch videoSessionCommand.response {
                case .unknown:
                    break
                case .accepted:
                    self.videoSessionId = UUID(uuidString: videoSessionCommand.sessionID)
                case .rejectedGeneric:
                    self.videoSessionId = nil
                case .rejectedInvalidSession:
                    self.videoSessionId = nil
                case .rejectedSessionInProgress:
                    self.videoSessionId = nil
                    let alert = NSAlert()
                    alert.messageText = "Recording"
                    alert.informativeText = "Already in progress"
                    alert.runModal()
                case .rejectedNoSpace:
                    self.videoSessionId = nil
                    let alert = NSAlert()
                    alert.messageText = "Recording"
                    alert.informativeText = "No space left"
                    alert.runModal()
                }
            }
        }
        
        FastRTPS.registerReader(topic: .rovLightPowerCurrent) { [weak self] (lightPower: RovLightPower) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if lightPower.power > 0 {
                    // Light On
                    self.lightOn = true
                    self.lightButton.image = NSImage(named: "Light On")
                    self.lightButton.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
                } else {
                    // Light Off
                    self.lightOn = false
                    self.lightButton.image = NSImage(named: "Light Off")
                    self.lightButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
                }
            }
        }
        
        FastRTPS.registerReader(topic: .rovVideoOverlayModeCurrent) { [weak self] (overlayMode: String) in
            DispatchQueue.main.async {
                self?.setTelemetryOverlay(mode: overlayMode)
            }
        }

        FastRTPS.registerReader(topic: .rovControllerStateCurrent) { [weak self] (controllerStatus: RovControllerStatus) in
            DispatchQueue.main.async {
                self?.setController(status: controllerStatus)
            }
        }

        FastRTPS.registerReader(topic: .rovBeacon) { [weak self] (rovBeacon: RovBeacon) in
            guard self?.vehicleId == nil else { return }
            DispatchQueue.main.async {
                self?.rovProvision(rovBeacon: rovBeacon)
            }
        }

//        FastRTPS.registerReader(topic: .rovSubsystemStatus) { (status: RovSubsystemStatus) in
//            print("status:", status.subsystemId.rawValue, status.substate)
//        }
//        FastRTPS.registerReader(topic: .rovFirmwareStatus) { (firmwareStatus: RovFirmwareStatus) in
//            print(firmwareStatus)
//        }
//        FastRTPS.registerReader(topic: .rovFirmwareServiceStatus) { (firmwareServiceStatus: RovFirmwareServiceStatus) in
//            print(firmwareServiceStatus)
//        }
//        FastRTPS.registerReader(topic: .rovFirmwareCommandRep) { (command: RovFirmwareCommand) in
//            print(command)
//        }
//        FastRTPS.registerReader(topic: .rovControlCurrent) { (control: RovTridentControlTarget) in
//            print(control)
//        }
//        FastRTPS.registerReader(topic: .navTrackingCurrent) { (cameraObjectTrack: RovCameraObjectTrack) in
//            print(cameraObjectTrack)
//        }
//        FastRTPS.registerReader(topic: .mcuI2cStats) { (stats: I2CStats) in
//            print(stats)
//        }
//        FastRTPS.registerReader(topic: .rovSafety) { (state: RovSafetyState) in
//            print(state)
//        }

    }
    
    private func registerWriters() {
        FastRTPS.registerWriter(topic: .rovLightPowerRequested, ddsType: RovLightPower.self)
        FastRTPS.registerWriter(topic: .rovDatetime, ddsType: String.self)
        FastRTPS.registerWriter(topic: .rovVideoOverlayModeCommand, ddsType: String.self)
        FastRTPS.registerWriter(topic: .rovVidSessionReq, ddsType: RovVideoSessionCommand.self)
        FastRTPS.registerWriter(topic: .rovDepthConfigRequested, ddsType: RovDepthConfig.self)
        FastRTPS.registerWriter(topic: .rovControlTarget, ddsType: RovTridentControlTarget.self)
        FastRTPS.registerWriter(topic: .rovControllerStateRequested, ddsType: RovControllerStatus.self)
        FastRTPS.registerWriter(topic: .rovFirmwareCommandReq, ddsType: RovFirmwareCommand.self)
    }
    
    private func startRecordingSession(id: UUID) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoDate = formatter.string(from: Date())
        let metadata = #"{"start_ts":"\#(isoDate)"}"#

        let videoSessionCommand = RovVideoSessionCommand(sessionID: id.uuidString.lowercased(),
                                                         metadata: metadata,
                                                         request: .recording,
                                                         response: .unknown,
                                                         reason: "")
        FastRTPS.send(topic: .rovVidSessionReq, ddsData: videoSessionCommand)
    }
    
    private func stopRecordingSession(id: UUID) {
        let videoSessionCommand = RovVideoSessionCommand(sessionID: id.uuidString.lowercased(),
                                                         metadata: "",
                                                         request: .stopped,
                                                         response: .unknown,
                                                         reason: "")
        FastRTPS.send(topic: .rovVidSessionReq, ddsData: videoSessionCommand)
    }

}

extension VideoViewController: TridentControlDelegate {
    func control(pitch: Float, yaw: Float, thrust: Float, lift: Float) {
        let tridentCommand = RovTridentControlTarget(id: "control", pitch: pitch, yaw: yaw, thrust: thrust, lift: lift)
        FastRTPS.send(topic: .rovControlTarget, ddsData: tridentCommand)
    }
    
    func updatePropellerButtonState() {
        switch tridentControl.motorSpeed {
        case .first?:
            propellerButton.isHidden = false
            propellerButton.image = NSImage(named: "Prop 1")
        case .second?:
            propellerButton.isHidden = false
            propellerButton.image = NSImage(named: "Prop 2")
        case .third?:
            propellerButton.isHidden = false
            propellerButton.image = NSImage(named: "Prop 3")
        case nil:
            propellerButton.isHidden = true
        }
    }
    
    func switchLight() {
        let lightPower = RovLightPower(id: "fwd", power: lightOn ? 0:1)
        FastRTPS.send(topic: .rovLightPowerRequested, ddsData: lightPower)
    }
    
    func switchRecording() {
        if let videoSessionId = videoSessionId {
            stopRecordingSession(id: videoSessionId)
        } else {
            startRecordingSession(id: UUID())
        }
    }
    
}
