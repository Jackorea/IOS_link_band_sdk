import Foundation
import CoreBluetooth

// MARK: - Device Models

public struct BluetoothDevice: Identifiable, Equatable, @unchecked Sendable {
    public let id: UUID = UUID()
    public let peripheral: CBPeripheral
    public let name: String
    public let rssi: NSNumber?
    
    public init(peripheral: CBPeripheral, name: String, rssi: NSNumber? = nil) {
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
    }
    
    public static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        return lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}

// MARK: - Sensor Data Models

public struct EEGReading: Sendable {
    public let channel1: Double  // µV
    public let channel2: Double  // µV
    public let ch1Raw: Int32     // Raw ADC value for channel 1
    public let ch2Raw: Int32     // Raw ADC value for channel 2
    public let leadOff: Bool
    public let timestamp: Date
    
    public init(channel1: Double, channel2: Double, ch1Raw: Int32, ch2Raw: Int32, leadOff: Bool, timestamp: Date = Date()) {
        self.channel1 = channel1
        self.channel2 = channel2
        self.ch1Raw = ch1Raw
        self.ch2Raw = ch2Raw
        self.leadOff = leadOff
        self.timestamp = timestamp
    }
}

public struct PPGReading: Sendable {
    public let red: Int
    public let ir: Int
    public let timestamp: Date
    
    public init(red: Int, ir: Int, timestamp: Date = Date()) {
        self.red = red
        self.ir = ir
        self.timestamp = timestamp
    }
}

public struct AccelerometerReading: Sendable {
    public let x: Int16
    public let y: Int16
    public let z: Int16
    public let timestamp: Date
    
    public init(x: Int16, y: Int16, z: Int16, timestamp: Date = Date()) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }
}

public struct BatteryReading: Sendable {
    public let level: UInt8  // 0-100%
    public let timestamp: Date
    
    public init(level: UInt8, timestamp: Date = Date()) {
        self.level = level
        self.timestamp = timestamp
    }
}

// MARK: - Connection State

public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case scanning
    case connecting(String)
    case connected(String)
    case reconnecting(String)
    case failed(BluetoothKitError)
    
    public var description: String {
        switch self {
        case .disconnected:
            return "연결 안됨"
        case .scanning:
            return "스캔 중..."
        case .connecting(let deviceName):
            return "\(deviceName)에 연결 중..."
        case .connected(let deviceName):
            return "\(deviceName)에 연결됨"
        case .reconnecting(let deviceName):
            return "\(deviceName)에 재연결 중..."
        case .failed(let error):
            return "실패: \(error.localizedDescription)"
        }
    }
    
    // 수동 Equatable 구현
    public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected), (.scanning, .scanning):
            return true
        case (.connecting(let lhsName), .connecting(let rhsName)):
            return lhsName == rhsName
        case (.connected(let lhsName), .connected(let rhsName)):
            return lhsName == rhsName
        case (.reconnecting(let lhsName), .reconnecting(let rhsName)):
            return lhsName == rhsName
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Recording State

public enum RecordingState: Sendable {
    case idle
    case recording
    case stopping
    
    public var isRecording: Bool {
        return self == .recording
    }
}

// MARK: - Configuration

/// 센서 데이터 수집 및 디바이스 통신을 위한 구성 설정입니다.
///
/// 이 구조체를 사용하여 BluetoothKit의 기본 동작을 사용자 정의할 수 있습니다.
///
/// ## 예시
///
/// ```swift
/// // 기본 설정
/// let defaultConfig = SensorConfiguration.default
///
/// // 사용자 정의 샘플링 레이트
/// let customConfig = SensorConfiguration(
///     eegSampleRate: 500.0,
///     ppgSampleRate: 100.0,
///     deviceNamePrefix: "MyDevice-"
/// )
/// ```
public struct SensorConfiguration: Sendable {
    
    /// EEG 샘플링 레이트 (Hz).
    ///
    /// 일반적인 값: 125Hz, 250Hz, 500Hz, 1000Hz
    public let eegSampleRate: Double
    
    /// PPG 샘플링 레이트 (Hz).
    ///
    /// 일반적인 값: 25Hz, 50Hz, 100Hz
    public let ppgSampleRate: Double
    
    /// 가속도계 샘플링 레이트 (Hz).
    ///
    /// 일반적인 값: 10Hz, 30Hz, 50Hz, 100Hz
    public let accelerometerSampleRate: Double
    
    /// 검색 가능한 디바이스를 필터링하기 위한 접두사.
    ///
    /// 이 접두사로 시작하는 이름을 가진 디바이스만 스캔 중에 검색됩니다.
    public let deviceNamePrefix: String
    
    /// 연결이 끊어졌을 때 자동으로 재연결할지 여부.
    public let autoReconnectEnabled: Bool
    
    // MARK: - Internal hardware parameters (fixed values)
    
    internal let eegVoltageReference: Double = 4.033
    internal let eegGain: Double = 12.0
    internal let eegResolution: Double = 8388607 // 2^23 - 1
    internal let microVoltMultiplier: Double = 1e6
    internal let timestampDivisor: Double = 32.768
    internal let millisecondsToSeconds: Double = 1000.0
    internal let eegPacketSize: Int = 179
    internal let ppgPacketSize: Int = 172
    internal let eegSamplesPerPacket: Int = 25
    internal let ppgSamplesPerPacket: Int = 28
    internal let eegSampleSize: Int = 7
    internal let ppgSampleSize: Int = 6
    internal let eegValidRange: ClosedRange<Double> = -200.0...200.0
    internal let ppgMaxValue: Int = 16777215
    
    /// 새로운 센서 설정을 생성합니다.
    ///
    /// - Parameters:
    ///   - eegSampleRate: EEG 샘플링 레이트 (Hz). 기본값: 250.0
    ///   - ppgSampleRate: PPG 샘플링 레이트 (Hz). 기본값: 50.0
    ///   - accelerometerSampleRate: 가속도계 샘플링 레이트 (Hz). 기본값: 30.0
    ///   - deviceNamePrefix: 디바이스 이름 필터 접두사. 기본값: "LXB-"
    ///   - autoReconnectEnabled: 자동 재연결 활성화. 기본값: true
    public init(
        eegSampleRate: Double = 250.0,
        ppgSampleRate: Double = 50.0,
        accelerometerSampleRate: Double = 30.0,
        deviceNamePrefix: String = "LXB-",
        autoReconnectEnabled: Bool = true
    ) {
        self.eegSampleRate = eegSampleRate
        self.ppgSampleRate = ppgSampleRate
        self.accelerometerSampleRate = accelerometerSampleRate
        self.deviceNamePrefix = deviceNamePrefix
        self.autoReconnectEnabled = autoReconnectEnabled
    }
    
    /// 일반적인 생체의학 데이터 수집을 위한 기본 설정.
    public static let `default` = SensorConfiguration()
    
    /// 연구 애플리케이션을 위한 고성능 설정.
    public static let highPerformance = SensorConfiguration(
        eegSampleRate: 500.0,
        ppgSampleRate: 100.0,
        accelerometerSampleRate: 100.0
    )
    
    /// 장시간 모니터링을 위한 저전력 설정.
    public static let lowPower = SensorConfiguration(
        eegSampleRate: 125.0,
        ppgSampleRate: 25.0,
        accelerometerSampleRate: 10.0
    )
}

// MARK: - Sensor UUIDs (Internal)

/// Bluetooth 서비스 및 특성 UUID를 포함하는 내부 구조체입니다.
///
/// 이 UUID들은 센서 통신을 위한 Bluetooth Low Energy GATT 프로파일을 정의합니다.
/// 사용되는 센서 하드웨어에 특화되어 있으며 다른 디바이스 제조업체의 경우
/// 업데이트가 필요할 수 있습니다.
internal struct SensorUUID {
    // MARK: - EEG Service
    
    /// EEG 서비스 UUID (알림 및 쓰기 작업을 위한 공유 서비스)
    static var eegService: CBUUID { CBUUID(string: "df7b5d95-3afe-00a1-084c-b50895ef4f95") }
    
    /// EEG 알림 특성 UUID (데이터 수신용)
    static var eegNotifyChar: CBUUID { CBUUID(string: "00ab4d15-66b4-0d8a-824f-8d6f8966c6e5") }
    
    /// EEG 쓰기 특성 UUID (명령 전송용)
    static var eegWriteChar: CBUUID { CBUUID(string: "0065cacb-9e52-21bf-a849-99a80d83830e") }

    // MARK: - PPG Service
    
    /// PPG 서비스 UUID
    static var ppgService: CBUUID { CBUUID(string: "1cc50ec0-6967-9d84-a243-c2267f924d1f") }
    
    /// PPG 특성 UUID (광전 용적 맥파 데이터 수신용)
    static var ppgChar: CBUUID { CBUUID(string: "6c739642-23ba-818b-2045-bfe8970263f6") }

    // MARK: - Accelerometer Service
    
    /// 가속도계 서비스 UUID
    static var accelService: CBUUID { CBUUID(string: "75c276c3-8f97-20bc-a143-b354244886d4") }
    
    /// 가속도계 특성 UUID (모션 데이터 수신용)
    static var accelChar: CBUUID { CBUUID(string: "d3d46a35-4394-e9aa-5a43-e7921120aaed") }

    // MARK: - Battery Service
    
    /// 표준 Bluetooth SIG Battery Service UUID
    static var batteryService: CBUUID { CBUUID(string: "0000180f-0000-1000-8000-00805f9b34fb") }
    
    /// 표준 Bluetooth SIG Battery Level Characteristic UUID
    static var batteryChar: CBUUID { CBUUID(string: "00002a19-0000-1000-8000-00805f9b34fb") }
    
    // MARK: - Convenience Collections
    
    /// 쉬운 반복을 위한 모든 센서 특성 UUID
    static var allSensorCharacteristics: [CBUUID] {
        [eegNotifyChar, ppgChar, accelChar, batteryChar]
    }
}

// MARK: - Logging System

public enum LogLevel: Int, Sendable, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    public var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

public protocol BluetoothKitLogger: Sendable {
    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int)
}

public struct DefaultLogger: BluetoothKitLogger {
    public let minimumLevel: LogLevel
    
    public init(minimumLevel: LogLevel = .info) {
        self.minimumLevel = minimumLevel
    }
    
    public func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        guard level.rawValue >= minimumLevel.rawValue else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("[\(timestamp)] \(level.emoji) \(level.name) [\(fileName):\(line)] \(message)")
    }
}

public struct SilentLogger: BluetoothKitLogger {
    public init() {}
    
    public func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        // 아무것도 하지 않음
    }
}

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Protocols

public protocol SensorDataDelegate: AnyObject, Sendable {
    func didReceiveEEGData(_ reading: EEGReading)
    func didReceivePPGData(_ reading: PPGReading)
    func didReceiveAccelerometerData(_ reading: AccelerometerReading)
    func didReceiveBatteryData(_ reading: BatteryReading)
}

public protocol BluetoothManagerDelegate: AnyObject, Sendable {
    func bluetoothManager(_ manager: AnyObject, didUpdateState state: ConnectionState)
    func bluetoothManager(_ manager: AnyObject, didDiscoverDevice device: BluetoothDevice)
    func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice)
    func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?)
}

public protocol DataRecorderDelegate: AnyObject, Sendable {
    func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date)
    func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL])
    func dataRecorder(_ recorder: AnyObject, didFailWithError error: Error)
}

// MARK: - Errors

public enum BluetoothKitError: LocalizedError, Sendable, Equatable {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed(String)
    case dataParsingFailed(String)
    case recordingFailed(String)
    case fileOperationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available"
        case .deviceNotFound:
            return "Device not found"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .dataParsingFailed(let reason):
            return "Data parsing failed: \(reason)"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
    
    // 수동 Equatable 구현
    public static func == (lhs: BluetoothKitError, rhs: BluetoothKitError) -> Bool {
        switch (lhs, rhs) {
        case (.bluetoothUnavailable, .bluetoothUnavailable), (.deviceNotFound, .deviceNotFound):
            return true
        case (.connectionFailed(let lhsReason), .connectionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.dataParsingFailed(let lhsReason), .dataParsingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.recordingFailed(let lhsReason), .recordingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.fileOperationFailed(let lhsReason), .fileOperationFailed(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
} 