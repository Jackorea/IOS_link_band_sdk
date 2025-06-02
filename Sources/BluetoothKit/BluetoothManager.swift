import Foundation
import CoreBluetooth

// MARK: - Bluetooth Manager

/// Bluetooth Low Energy 연결 및 디바이스 검색을 관리하는 내부 클래스입니다.
///
/// 이 클래스는 CoreBluetooth 스택을 처리하고 디바이스 스캔, 연결 관리, 
/// 데이터 스트리밍을 위한 깔끔한 인터페이스를 제공합니다. 
/// 디스패치 큐를 사용하여 적절한 동시성 안전성을 구현합니다.
public class BluetoothManager: NSObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    public weak var delegate: BluetoothManagerDelegate?
    public weak var sensorDataDelegate: SensorDataDelegate?
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var discoveredDevices: [BluetoothDevice] = []
    
    private let configuration: SensorConfiguration
    private let dataParser: SensorDataParser
    private let logger: BluetoothKitLogger
    
    // 연결 상태 관리
    private var connectionState: ConnectionState = .disconnected {
        didSet {
            let currentState = connectionState
            notifyStateChange(currentState)
        }
    }
    
    // Auto-reconnection 상태
    private var lastConnectedPeripheralIdentifier: UUID?
    private var userInitiatedDisconnect = false
    private var isAutoReconnectEnabled: Bool
    
    // MARK: - Initialization
    
    /// 새로운 BluetoothManager 인스턴스를 생성합니다.
    ///
    /// - Parameters:
    ///   - configuration: 센서 구성 설정
    ///   - logger: 디버깅을 위한 로거 구현
    public init(configuration: SensorConfiguration, logger: BluetoothKitLogger) {
        self.configuration = configuration
        self.logger = logger
        self.dataParser = SensorDataParser(configuration: configuration)
        self.isAutoReconnectEnabled = configuration.autoReconnectEnabled
        
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        log("BluetoothManager initialized", level: .info)
    }
    
    // MARK: - Public Interface
    
    public var isScanning: Bool {
        return centralManager.isScanning
    }
    
    public var isConnected: Bool {
        return connectedPeripheral?.state == .connected
    }
    
    public var currentConnectionState: ConnectionState {
        return connectionState
    }
    
    public var discoveredDevicesList: [BluetoothDevice] {
        return discoveredDevices
    }
    
    public func startScanning() {
        guard centralManager.state == .poweredOn else {
            log("Cannot start scanning: Bluetooth not available", level: .warning)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            return
        }
        
        centralManager.stopScan()
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil)
        connectionState = .scanning
        
        log("Started scanning for devices", level: .info)
    }
    
    public func stopScanning() {
        centralManager.stopScan()
        if case .scanning = connectionState {
            connectionState = .disconnected
        }
        log("Stopped scanning", level: .info)
    }
    
    public func connect(to device: BluetoothDevice) {
        guard centralManager.state == .poweredOn else {
            log("Cannot connect: Bluetooth not available", level: .warning)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            return
        }
        
        stopScanning()
        userInitiatedDisconnect = false
        connectionState = .connecting(device.name)
        centralManager.connect(device.peripheral, options: nil)
        
        log("Attempting to connect to \(device.name)", level: .info)
    }
    
    public func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        userInitiatedDisconnect = true
        lastConnectedPeripheralIdentifier = nil
        centralManager.cancelPeripheralConnection(peripheral)
        
        log("Disconnecting from device", level: .info)
    }
    
    public func enableAutoReconnect(_ enabled: Bool) {
        let previousState = isAutoReconnectEnabled
        isAutoReconnectEnabled = enabled
        log("Auto-reconnect \(enabled ? "enabled" : "disabled") (was \(previousState ? "enabled" : "disabled"))", level: .info)
        
        if enabled {
            // auto-reconnect가 활성화되고 마지막 연결된 디바이스가 있으며,
            // 현재 연결이 끊어진 상태라면, 재연결을 시도합니다
            if let lastPeripheralId = lastConnectedPeripheralIdentifier,
               !isConnected,
               centralManager.state == .poweredOn {
                
                // 검색된 디바이스에서 peripheral을 찾거나 검색을 시도합니다
                if let peripheral = discoveredDevices.first(where: { $0.peripheral.identifier == lastPeripheralId })?.peripheral {
                    connectionState = .reconnecting(peripheral.name ?? "Unknown Device")
                    centralManager.connect(peripheral, options: nil)
                    log("Auto-reconnect triggered: attempting to reconnect to \(peripheral.name ?? "Unknown Device")", level: .info)
                } else {
                    // peripheral이 검색된 디바이스에 없다면, 검색을 시도합니다
                    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [lastPeripheralId])
                    if let peripheral = peripherals.first {
                        connectionState = .reconnecting(peripheral.name ?? "Unknown Device")
                        centralManager.connect(peripheral, options: nil)
                        log("Auto-reconnect triggered: attempting to reconnect to retrieved peripheral \(peripheral.name ?? "Unknown Device")", level: .info)
                    }
                }
            }
        } else {
            // auto-reconnect가 비활성화되면, 진행 중인 재연결 시도를 취소합니다
            if case .reconnecting(let deviceName) = connectionState {
                // 재연결을 시도 중인 peripheral을 찾아서 연결을 취소합니다
                if let lastPeripheralId = lastConnectedPeripheralIdentifier {
                    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [lastPeripheralId])
                    if let peripheral = peripherals.first {
                        centralManager.cancelPeripheralConnection(peripheral)
                        log("Cancelled ongoing reconnection attempt to \(deviceName)", level: .info)
                    }
                }
                connectionState = .disconnected
            }
            log("Auto-reconnect disabled - all automatic reconnection attempts will be blocked", level: .info)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleDeviceDiscovered(_ peripheral: CBPeripheral, rssi: NSNumber) {
        let name = peripheral.name ?? ""
        guard name.hasPrefix(configuration.deviceNamePrefix) else { return }
        
        // 디바이스가 이미 존재하는지 확인합니다
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = BluetoothDevice(peripheral: peripheral, name: name, rssi: rssi)
            discoveredDevices.append(device)
            
            notifyDeviceDiscovered(device)
            
            log("Discovered device: \(name) (RSSI: \(rssi))", level: .debug)
        }
    }
    
    private func handleConnectionSuccess(_ peripheral: CBPeripheral) {
        // 이 연결이 허용되는지 확인합니다
        // auto-reconnect가 비활성화되어 있고 사용자가 시작한 연결이 아니라면, 취소합니다
        if case .reconnecting = connectionState, !isAutoReconnectEnabled {
            log("Auto-reconnect is disabled, cancelling automatic connection to \(peripheral.name ?? "Unknown Device")", level: .info)
            centralManager.cancelPeripheralConnection(peripheral)
            connectionState = .disconnected
            return
        }
        
        connectedPeripheral = peripheral
        lastConnectedPeripheralIdentifier = peripheral.identifier
        userInitiatedDisconnect = false
        
        let deviceName = peripheral.name ?? "Unknown Device"
        connectionState = .connected(deviceName)
        
        // 서비스 검색을 시작합니다
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        if let device = discoveredDevices.first(where: { $0.peripheral.identifier == peripheral.identifier }) {
            notifyDeviceConnected(device)
        }
        
        log("Connected to \(deviceName)", level: .info)
    }
    
    private func handleConnectionFailure(_ peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        connectionState = .failed(BluetoothKitError.connectionFailed(errorMessage))
        
        log("Connection failed: \(errorMessage)", level: .error)
    }
    
    private func handleDisconnection(_ peripheral: CBPeripheral, error: Error?) {
        let deviceName = peripheral.name ?? "Unknown Device"
        
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        
        // auto-reconnection을 처리합니다
        if !userInitiatedDisconnect,
           let lastID = lastConnectedPeripheralIdentifier,
           peripheral.identifier == lastID {
            
            if isAutoReconnectEnabled {
                connectionState = .reconnecting(deviceName)
                centralManager.connect(peripheral, options: nil)
                log("Auto-reconnecting to \(deviceName)", level: .info)
            } else {
                connectionState = .disconnected
                log("Auto-reconnect is disabled, not attempting to reconnect to \(deviceName)", level: .info)
            }
        } else {
            connectionState = .disconnected
            if userInitiatedDisconnect {
                lastConnectedPeripheralIdentifier = nil
                userInitiatedDisconnect = false
                log("User initiated disconnect, clearing last connected device", level: .debug)
            }
        }
        
        if let device = discoveredDevices.first(where: { $0.peripheral.identifier == peripheral.identifier }) {
            notifyDeviceDisconnected(device, error: error)
        }
        
        let errorInfo = error?.localizedDescription ?? "No error"
        log("Disconnected from \(deviceName): \(errorInfo)", level: .info)
    }
    
    private func handleCharacteristicUpdate(_ characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, error == nil else {
            log("Characteristic update error: \(error?.localizedDescription ?? "Unknown")", level: .warning)
            return
        }
        
        do {
            switch characteristic.uuid {
            case SensorUUID.eegNotifyChar:
                let readings = try dataParser.parseEEGData(data)
                for reading in readings {
                    notifySensorData(reading) { [weak self] data in
                        self?.sensorDataDelegate?.didReceiveEEGData(data)
                    }
                }
                
            case SensorUUID.ppgChar:
                let readings = try dataParser.parsePPGData(data)
                for reading in readings {
                    notifySensorData(reading) { [weak self] data in
                        self?.sensorDataDelegate?.didReceivePPGData(data)
                    }
                }
                
            case SensorUUID.accelChar:
                let readings = try dataParser.parseAccelerometerData(data)
                for reading in readings {
                    notifySensorData(reading) { [weak self] data in
                        self?.sensorDataDelegate?.didReceiveAccelerometerData(data)
                    }
                }
                
            case SensorUUID.batteryChar:
                let reading = try dataParser.parseBatteryData(data)
                notifySensorData(reading) { [weak self] data in
                    self?.sensorDataDelegate?.didReceiveBatteryData(data)
                }
                
            default:
                log("Received data from unknown characteristic: \(characteristic.uuid)", level: .debug)
            }
        } catch {
            log("Data parsing error: \(error)", level: .error)
        }
    }
    
    private func log(_ message: String, level: LogLevel, file: String = #file, function: String = #function, line: Int = #line) {
        logger.log(message, level: level, file: file, function: function, line: line)
    }
    
    // MARK: - Private Helper Methods
    
    private func notifyStateChange(_ state: ConnectionState) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didUpdateState: state)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didUpdateState: state)
            }
        }
    }
    
    private func notifyDeviceDiscovered(_ device: BluetoothDevice) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didDiscoverDevice: device)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didDiscoverDevice: device)
            }
        }
    }
    
    private func notifyDeviceConnected(_ device: BluetoothDevice) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didConnectToDevice: device)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didConnectToDevice: device)
            }
        }
    }
    
    private func notifyDeviceDisconnected(_ device: BluetoothDevice, error: Error?) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didDisconnectFromDevice: device, error: error)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didDisconnectFromDevice: device, error: error)
            }
        }
    }
    
    private func notifySensorData<T: Sendable>(_ data: T, callback: @escaping @Sendable (T) -> Void) {
        if Thread.isMainThread {
            callback(data)
        } else {
            DispatchQueue.main.async {
                callback(data)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("📶 Bluetooth is powered on", level: .info)
            if case .failed(let error) = connectionState,
               error == .bluetoothUnavailable {
                connectionState = .disconnected
            }
            
        case .poweredOff:
            log("📵 Bluetooth is powered off", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            
        case .unauthorized:
            log("🚫 Bluetooth access unauthorized", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            
        case .unsupported:
            log("❌ Bluetooth not supported", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            
        default:
            log("🔄 Bluetooth state: \(central.state.rawValue)", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
        }
    }
    
    public func centralManager(_ central: CBCentralManager,
                              didDiscover peripheral: CBPeripheral,
                              advertisementData: [String : Any],
                              rssi RSSI: NSNumber) {
        handleDeviceDiscovered(peripheral, rssi: RSSI)
    }
    
    public func centralManager(_ central: CBCentralManager,
                              didConnect peripheral: CBPeripheral) {
        handleConnectionSuccess(peripheral)
    }
    
    public func centralManager(_ central: CBCentralManager,
                              didFailToConnect peripheral: CBPeripheral,
                              error: Error?) {
        handleConnectionFailure(peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager,
                              didDisconnectPeripheral peripheral: CBPeripheral,
                              error: Error?) {
        handleDisconnection(peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral,
                          didDiscoverCharacteristicsFor service: CBService,
                          error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if SensorUUID.allSensorCharacteristics.contains(characteristic.uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
                log("Enabled notifications for characteristic: \(characteristic.uuid)", level: .debug)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral,
                          didUpdateValueFor characteristic: CBCharacteristic,
                          error: Error?) {
        handleCharacteristicUpdate(characteristic, error: error)
    }
} 