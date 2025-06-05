import Foundation
import CoreBluetooth

// MARK: - Device Models

/// Bluetooth Low Energy 디바이스를 나타내는 구조체입니다.
///
/// 이 구조체는 스캔 중 발견된 BLE 디바이스의 정보를 캡슐화합니다.
/// 각 디바이스는 고유한 식별자를 가지며, Core Bluetooth 페리페럴 객체와
/// 디바이스의 표시 이름, 신호 강도 정보를 포함합니다.
///
/// ## 예시
///
/// ```swift
/// let device = BluetoothDevice(
///     peripheral: cbPeripheral,
///     name: "LXB-001",
///     rssi: -45
/// )
/// print("디바이스: \(device.name), 신호강도: \(device.rssi)dBm")
/// ```
public struct BluetoothDevice: Identifiable, Equatable, @unchecked Sendable {
    /// SwiftUI 목록에서 사용되는 고유 식별자입니다.
    public let id: UUID = UUID()
    
    /// Core Bluetooth 페리페럴 객체입니다.
    ///
    /// 실제 BLE 통신을 위해 사용되는 CBPeripheral 인스턴스입니다.
    /// 연결, 서비스 검색, 특성 읽기/쓰기 등의 작업에 사용됩니다.
    /// SDK 내부에서만 접근 가능합니다.
    internal let peripheral: CBPeripheral
    
    /// 디바이스의 표시 이름입니다.
    ///
    /// BLE 광고에서 가져온 디바이스 이름 또는 사용자 정의 이름입니다.
    /// 일반적으로 "LXB-" 접두사를 가진 형태입니다.
    public let name: String
    
    /// 수신 신호 강도 표시값(RSSI)입니다.
    ///
    /// dBm 단위로 측정된 신호 강도를 나타냅니다.
    /// 값이 0에 가까울수록 신호가 강하며, 일반적으로 -30에서 -100 범위입니다.
    /// 디바이스가 스캔 중이 아닐 때는 `nil`일 수 있습니다.
    public let rssi: NSNumber?
    
    /// 새로운 BluetoothDevice 인스턴스를 생성합니다.
    ///
    /// - Parameters:
    ///   - peripheral: Core Bluetooth peripheral
    ///   - name: 디바이스 이름
    ///   - rssi: 신호 강도 (선택사항)
    internal init(peripheral: CBPeripheral, name: String, rssi: NSNumber? = nil) {
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
    }
    
    /// 두 BluetoothDevice가 동일한지 비교합니다.
    ///
    /// 페리페럴의 식별자를 기준으로 동등성을 판단합니다.
    public static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        return lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}

// MARK: - Sensor Data Models

/// EEG(뇌전도) 센서 읽기값을 나타내는 구조체입니다.
///
/// 이 구조체는 2채널 EEG 데이터와 관련 메타데이터를 포함합니다.
/// 전압 값은 마이크로볼트(µV) 단위로 표현되며, 원시 ADC 값도 함께 제공됩니다.
///
/// ## 예시
///
/// ```swift
/// let eegReading = EEGReading(
///     channel1: 15.3,
///     channel2: -8.7,
///     ch1Raw: 125043,
///     ch2Raw: -67834,
///     leadOff: false
/// )
/// ```
public struct EEGReading: Sendable {
    /// 채널 1의 EEG 전압값 (마이크로볼트 단위)
    ///
    /// 첫 번째 EEG 전극에서 측정된 전압입니다. 일반적으로 -200µV에서 +200µV 범위입니다.
    public let channel1: Double  // µV
    
    /// 채널 2의 EEG 전압값 (마이크로볼트 단위)
    ///
    /// 두 번째 EEG 전극에서 측정된 전압입니다. 일반적으로 -200µV에서 +200µV 범위입니다.
    public let channel2: Double  // µV
    
    /// 채널 1의 원시 ADC 값입니다.
    ///
    /// 아날로그-디지털 변환기에서 직접 얻은 24비트 정수값입니다.
    /// 디버깅이나 고급 신호 처리에 사용될 수 있습니다.
    public let ch1Raw: Int32     // Raw ADC value for channel 1
    
    /// 채널 2의 원시 ADC 값입니다.
    ///
    /// 아날로그-디지털 변환기에서 직접 얻은 24비트 정수값입니다.
    /// 디버깅이나 고급 신호 처리에 사용될 수 있습니다.
    public let ch2Raw: Int32     // Raw ADC value for channel 2
    
    /// 전극 연결 해제 상태를 나타냅니다.
    ///
    /// `true`일 때 전극이 피부에서 분리되었거나 접촉이 불량함을 의미합니다.
    /// 이 상태에서는 EEG 데이터가 신뢰할 수 없습니다.
    public let leadOff: Bool
    
    /// 데이터가 측정된 시간입니다.
    public let timestamp: Date
    
    /// 새로운 EEGReading 인스턴스를 생성합니다.
    ///
    /// - Parameters:
    ///   - channel1: 채널 1 전압값 (µV)
    ///   - channel2: 채널 2 전압값 (µV)
    ///   - ch1Raw: 채널 1 원시 ADC 값
    ///   - ch2Raw: 채널 2 원시 ADC 값
    ///   - leadOff: 전극 연결 해제 상태
    ///   - timestamp: 측정 시간 (기본값: 현재 시간)
    internal init(channel1: Double, channel2: Double, ch1Raw: Int32, ch2Raw: Int32, leadOff: Bool, timestamp: Date = Date()) {
        self.channel1 = channel1
        self.channel2 = channel2
        self.ch1Raw = ch1Raw
        self.ch2Raw = ch2Raw
        self.leadOff = leadOff
        self.timestamp = timestamp
    }
}

/// PPG(광전 용적 맥파) 센서 읽기값을 나타내는 구조체입니다.
///
/// PPG는 심박수와 혈류량 모니터링에 사용되는 광학 센서입니다.
/// 적색(Red)과 적외선(IR) LED를 사용하여 혈액의 산소 포화도와
/// 심박수를 측정할 수 있습니다.
///
/// ## 예시
///
/// ```swift
/// let ppgReading = PPGReading(
///     red: 125043,
///     ir: 134567
/// )
/// ```
public struct PPGReading: Sendable {
    /// 적색 LED의 측정값입니다.
    ///
    /// 660nm 적색 LED에서 반사된 빛의 강도를 나타냅니다.
    /// 값의 범위는 0에서 16,777,215 (24비트) 사이입니다.
    public let red: Int
    
    /// 적외선 LED의 측정값입니다.
    ///
    /// 940nm 적외선 LED에서 반사된 빛의 강도를 나타냅니다.
    /// 값의 범위는 0에서 16,777,215 (24비트) 사이입니다.
    public let ir: Int
    
    /// 데이터가 측정된 시간입니다.
    public let timestamp: Date
    
    /// 새로운 PPGReading 인스턴스를 생성합니다.
    ///
    /// - Parameters:
    ///   - red: 적색 LED 측정값
    ///   - ir: 적외선 LED 측정값
    ///   - timestamp: 측정 시간 (기본값: 현재 시간)
    internal init(red: Int, ir: Int, timestamp: Date = Date()) {
        self.red = red
        self.ir = ir
        self.timestamp = timestamp
    }
}

/// 3축 가속도계 센서 읽기값을 나타내는 구조체입니다.
///
/// 이 구조체는 디바이스의 움직임과 방향을 감지하기 위한
/// X, Y, Z축의 가속도 데이터를 포함합니다. 값은 중력 단위(g)의
/// 정수 표현으로 제공됩니다.
///
/// ## 예시
///
/// ```swift
/// let accelReading = AccelerometerReading(
///     x: 1024,   // 약 1g
///     y: 0,      // 0g
///     z: 0       // 0g
/// )
/// ```
public struct AccelerometerReading: Sendable {
    /// X축 가속도 값입니다.
    ///
    /// 디바이스의 좌우 방향 가속도를 나타냅니다.
    /// 값의 범위는 일반적으로 -32,768에서 +32,767 사이입니다.
    public let x: Int16
    
    /// Y축 가속도 값입니다.
    ///
    /// 디바이스의 전후 방향 가속도를 나타냅니다.
    /// 값의 범위는 일반적으로 -32,768에서 +32,767 사이입니다.
    public let y: Int16
    
    /// Z축 가속도 값입니다.
    ///
    /// 디바이스의 상하 방향 가속도를 나타냅니다.
    /// 값의 범위는 일반적으로 -32,768에서 +32,767 사이입니다.
    public let z: Int16
    
    /// 데이터가 측정된 시간입니다.
    public let timestamp: Date
    
    /// 새로운 AccelerometerReading 인스턴스를 생성합니다.
    ///
    /// - Parameters:
    ///   - x: X축 가속도값
    ///   - y: Y축 가속도값
    ///   - z: Z축 가속도값
    ///   - timestamp: 측정 시간 (기본값: 현재 시간)
    internal init(x: Int16, y: Int16, z: Int16, timestamp: Date = Date()) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }
}

/// 디바이스 배터리 상태를 나타내는 구조체입니다.
///
/// 연결된 센서 디바이스의 배터리 잔량을 백분율로 제공합니다.
/// 이 정보는 사용자에게 충전 필요성을 알리고 데이터 수집
/// 세션을 계획하는 데 도움이 됩니다.
///
/// ## 예시
///
/// ```swift
/// let batteryReading = BatteryReading(level: 85)
/// print("배터리 잔량: \(batteryReading.level)%")
/// ```
public struct BatteryReading: Sendable {
    /// 배터리 잔량 백분율입니다.
    ///
    /// 0%에서 100% 사이의 값으로 배터리 충전 상태를 나타냅니다.
    /// 0은 완전 방전, 100은 완전 충전을 의미합니다.
    public let level: UInt8  // 0-100%
    
    /// 데이터가 측정된 시간입니다.
    public let timestamp: Date
    
    /// 새로운 BatteryReading 인스턴스를 생성합니다.
    ///
    /// - Parameters:
    ///   - level: 배터리 잔량 (0-100%)
    ///   - timestamp: 측정 시간 (기본값: 현재 시간)
    internal init(level: UInt8, timestamp: Date = Date()) {
        self.level = level
        self.timestamp = timestamp
    }
}

// MARK: - Connection State

/// Bluetooth 연결의 현재 상태를 나타내는 열거형입니다.
///
/// 이 열거형은 연결 프로세스의 다양한 단계를 추적하며,
/// 사용자 인터페이스에서 적절한 상태 표시를 제공합니다.
/// 
/// **⚠️ 중요: 이 상태들은 SDK에서 자동으로 관리됩니다.**
/// **사용자가 직접 생성하지 마세요. 읽기 전용으로만 사용하세요.**
///
/// ## 사용 예시
///
/// ```swift
/// // ✅ 올바른 사용법 - 상태 읽기
/// switch bluetoothKit.connectionState {
/// case .disconnected:
///     showDisconnectedUI()
/// case .connected(let deviceName):
///     showConnectedUI(for: deviceName)
/// default:
///     break
/// }
/// 
/// // ❌ 잘못된 사용법 - 직접 생성하지 마세요
/// // bluetoothKit.connectionState = .connected("FakeDevice")
/// ```
public enum ConnectionState: Sendable, Equatable {
    /// 어떤 디바이스에도 연결되지 않은 상태입니다.
    case disconnected
    
    /// 현재 디바이스를 스캔하고 있는 상태입니다.
    case scanning
    
    /// 특정 디바이스에 연결을 시도하고 있는 상태입니다.
    ///
    /// - Parameter deviceName: 연결을 시도하는 디바이스의 이름
    case connecting(String)
    
    /// 특정 디바이스에 성공적으로 연결된 상태입니다.
    ///
    /// - Parameter deviceName: 연결된 디바이스의 이름
    case connected(String)
    
    /// 연결이 끊어진 후 자동으로 재연결을 시도하고 있는 상태입니다.
    ///
    /// - Parameter deviceName: 재연결을 시도하는 디바이스의 이름
    case reconnecting(String)
    
    /// 연결 또는 작업이 실패한 상태입니다.
    ///
    /// - Parameter error: 실패 원인을 나타내는 오류
    case failed(BluetoothKitError)
    
    /// 연결 상태의 사용자 친화적인 한국어 설명입니다.
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

/// 데이터 기록의 현재 상태를 나타내는 열거형입니다.
///
/// 이 열거형은 센서 데이터의 파일 기록 상태를 추적합니다.
/// 기록 시작, 진행 중, 종료 등의 상태를 구분하여
/// 사용자 인터페이스와 내부 로직에서 활용됩니다.
///
/// **⚠️ 중요: 이 상태들은 SDK에서 자동으로 관리됩니다.**
/// **사용자가 직접 생성하지 마세요. 읽기 전용으로만 사용하세요.**
///
/// ## 사용 예시
///
/// ```swift
/// // ✅ 올바른 사용법 - 상태 확인
/// if bluetoothKit.isRecording {
///     showRecordingIndicator()
/// }
/// 
/// // ❌ 잘못된 사용법 - 직접 상태 생성하지 마세요
/// // let fakeState = RecordingState.recording
/// ```
public enum RecordingState: Sendable {
    /// 기록이 비활성화된 유휴 상태입니다.
    case idle
    
    /// 현재 데이터를 기록하고 있는 상태입니다.
    case recording
    
    /// 기록을 중지하는 과정에 있는 상태입니다.
    case stopping
    
    /// 현재 기록 중인지 여부를 나타내는 편의 속성입니다.
    public var isRecording: Bool {
        return self == .recording
    }
}

// MARK: - Configuration

/// 센서 데이터 수집을 위한 기본 구성 설정입니다.
///
/// 이 구조체를 사용하여 BluetoothKit의 기본 동작을 사용자 정의할 수 있습니다.
/// 대부분의 경우 기본 설정으로 충분하며, 필요에 따라 디바이스 이름 필터나
/// 자동 재연결 설정만 변경하면 됩니다.
///
/// ## 예시
///
/// ```swift
/// // 기본 설정 사용
/// let bluetoothKit = BluetoothKit()
///
/// // 커스텀 디바이스 이름 필터
/// let config = SensorConfiguration(deviceNamePrefix: "MyDevice-")
/// let bluetoothKit = BluetoothKit(configuration: config)
/// ```
public struct SensorConfiguration: Sendable {
    
    /// 검색 가능한 디바이스를 필터링하기 위한 접두사.
    ///
    /// 이 접두사로 시작하는 이름을 가진 디바이스만 스캔 중에 검색됩니다.
    /// 기본값: "LXB-"
    public let deviceNamePrefix: String
    
    /// 연결이 끊어졌을 때 자동으로 재연결할지 여부.
    ///
    /// 기본값: true
    public let autoReconnectEnabled: Bool
    
    // MARK: - Internal Configuration (Fixed Values)
    
    /// EEG 샘플링 레이트 (Hz) - 고정값
    internal let eegSampleRate: Double = 250.0
    
    /// PPG 샘플링 레이트 (Hz) - 고정값
    internal let ppgSampleRate: Double = 50.0
    
    /// 가속도계 샘플링 레이트 (Hz) - 고정값
    internal let accelerometerSampleRate: Double = 30.0
    
    // MARK: - Internal hardware parameters (Fixed Values)
    
    internal let eegVoltageReference: Double = 4.033
    internal let eegGain: Double = 12.0
    internal let eegResolution: Double = 8388607 // 2^23 - 1
    internal let microVoltMultiplier: Double = 1e6
    internal let timestampDivisor: Double = 32.768
    internal let millisecondsToSeconds: Double = 1000.0
    internal let eegPacketSize: Int = 179
    internal let ppgPacketSize: Int = 172
    internal let eegSampleSize: Int = 7
    internal let ppgSampleSize: Int = 6
    
    /// 새로운 센서 설정을 생성합니다.
    ///
    /// - Parameters:
    ///   - deviceNamePrefix: 디바이스 이름 필터 접두사. 기본값: "LXB-"
    ///   - autoReconnectEnabled: 자동 재연결 활성화. 기본값: true
    public init(
        deviceNamePrefix: String = "LXB-",
        autoReconnectEnabled: Bool = true
    ) {
        self.deviceNamePrefix = deviceNamePrefix
        self.autoReconnectEnabled = autoReconnectEnabled
    }
    
    /// 일반적인 사용을 위한 기본 설정.
    public static let `default` = SensorConfiguration()
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

/// 로그 메시지의 중요도 레벨을 나타내는 열거형입니다.
///
/// BluetoothKit 내부의 로깅 시스템에서 사용되며,
/// 개발자가 필요한 레벨의 로그만 필터링하여 볼 수 있도록 합니다.
/// 각 레벨은 이모지와 함께 시각적으로 구분됩니다.
///
/// ## 예시
///
/// ```swift
/// // 정보 레벨 이상의 로그만 표시
/// let logger = DefaultLogger(minimumLevel: .info)
/// 
/// // 로그 레벨 확인
/// print("에러 레벨: \(LogLevel.error.emoji) \(LogLevel.error.name)")
/// ```
public enum LogLevel: Int, Sendable, CaseIterable {
    /// 디버깅 정보를 위한 가장 상세한 로그 레벨입니다.
    ///
    /// 개발 중 상세한 실행 흐름을 추적할 때 사용됩니다.
    case debug = 0
    
    /// 일반적인 정보성 메시지를 위한 로그 레벨입니다.
    ///
    /// 정상적인 동작 상태와 주요 이벤트를 기록할 때 사용됩니다.
    case info = 1
    
    /// 주의가 필요한 상황을 나타내는 로그 레벨입니다.
    ///
    /// 오류는 아니지만 예상치 못한 상황이나 잠재적 문제를 알릴 때 사용됩니다.
    case warning = 2
    
    /// 오류 상황을 나타내는 가장 높은 로그 레벨입니다.
    ///
    /// 실패한 작업이나 예외 상황을 기록할 때 사용됩니다.
    case error = 3
    
    /// 로그 레벨을 시각적으로 구분하기 위한 이모지입니다.
    public var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    /// 로그 레벨의 문자열 표현입니다.
    public var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

/// BluetoothKit의 로깅을 담당하는 프로토콜입니다.
///
/// 이 프로토콜을 구현하여 사용자 정의 로깅 동작을 제공할 수 있습니다.
/// 기본 구현체로 `DefaultLogger`와 `SilentLogger`가 제공됩니다.
///
/// ## 예시
///
/// ```swift
/// struct CustomLogger: BluetoothKitLogger {
///     func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
///         // 사용자 정의 로깅 로직
///         writeToFile("[\(level.name)] \(message)")
///     }
/// }
/// ```
public protocol BluetoothKitLogger: Sendable {
    /// 로그 메시지를 기록합니다.
    ///
    /// - Parameters:
    ///   - message: 기록할 메시지
    ///   - level: 로그 레벨
    ///   - file: 로그가 호출된 파일명
    ///   - function: 로그가 호출된 함수명
    ///   - line: 로그가 호출된 라인 번호
    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int)
}

/// 콘솔에 로그를 출력하는 기본 로거 구현체입니다.
///
/// 설정된 최소 로그 레벨 이상의 메시지만 출력하며,
/// 타임스탬프, 로그 레벨, 파일 정보와 함께 메시지를 표시합니다.
///
/// ## 예시
///
/// ```swift
/// // 정보 레벨 이상만 출력
/// let logger = DefaultLogger(minimumLevel: .info)
/// 
/// // 모든 레벨 출력 (디버그 포함)
/// let debugLogger = DefaultLogger(minimumLevel: .debug)
/// ```
public struct DefaultLogger: BluetoothKitLogger {
    /// 출력할 최소 로그 레벨입니다.
    ///
    /// 이 레벨보다 낮은 우선순위의 로그는 무시됩니다.
    public let minimumLevel: LogLevel
    
    /// 새로운 DefaultLogger 인스턴스를 생성합니다.
    ///
    /// - Parameter minimumLevel: 출력할 최소 로그 레벨 (기본값: .info)
    public init(minimumLevel: LogLevel = .info) {
        self.minimumLevel = minimumLevel
    }
    
    /// 로그 메시지를 콘솔에 출력합니다.
    public func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        guard level.rawValue >= minimumLevel.rawValue else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("[\(timestamp)] \(level.emoji) \(level.name) [\(fileName):\(line)] \(message)")
    }
}

/// 로그 출력을 완전히 비활성화하는 로거 구현체입니다.
///
/// 프로덕션 환경이나 로그가 필요하지 않은 상황에서 사용됩니다.
/// 모든 로그 메시지를 무시하여 성능 오버헤드를 최소화합니다.
///
/// ## 예시
///
/// ```swift
/// let bluetoothKit = BluetoothKit(logger: SilentLogger())
/// ```
public struct SilentLogger: BluetoothKitLogger {
    /// 새로운 SilentLogger 인스턴스를 생성합니다.
    public init() {}
    
    /// 로그 메시지를 무시합니다 (아무 동작도 하지 않음).
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

/// 센서 데이터 수신을 처리하는 델리게이트 프로토콜입니다.
///
/// 이 프로토콜을 구현하여 BluetoothKit에서 수신되는
/// 각종 센서 데이터에 대한 사용자 정의 처리 로직을 제공할 수 있습니다.
/// 실시간 데이터 처리나 커스텀 분석에 유용합니다.
///
/// ## 예시
///
/// ```swift
/// class DataProcessor: SensorDataDelegate {
///     func didReceiveEEGData(_ reading: EEGReading) {
///         // EEG 데이터 처리 로직
///         processEEGSignal(reading.channel1, reading.channel2)
///     }
///     
///     func didReceivePPGData(_ reading: PPGReading) {
///         // PPG 데이터로부터 심박수 계산
///         calculateHeartRate(red: reading.red, ir: reading.ir)
///     }
/// }
/// ```
internal protocol SensorDataDelegate: AnyObject, Sendable {
    /// EEG 데이터가 수신되었을 때 호출됩니다.
    ///
    /// - Parameter reading: 수신된 EEG 읽기값
    func didReceiveEEGData(_ reading: EEGReading)
    
    /// PPG 데이터가 수신되었을 때 호출됩니다.
    ///
    /// - Parameter reading: 수신된 PPG 읽기값
    func didReceivePPGData(_ reading: PPGReading)
    
    /// 가속도계 데이터가 수신되었을 때 호출됩니다.
    ///
    /// - Parameter reading: 수신된 가속도계 읽기값
    func didReceiveAccelerometerData(_ reading: AccelerometerReading)
    
    /// 배터리 데이터가 수신되었을 때 호출됩니다.
    ///
    /// - Parameter reading: 수신된 배터리 읽기값
    func didReceiveBatteryData(_ reading: BatteryReading)
}

/// Bluetooth 연결 상태 변화를 처리하는 델리게이트 프로토콜입니다.
///
/// BluetoothManager의 연결 이벤트를 모니터링하고
/// 사용자 정의 로직을 실행할 수 있도록 합니다.
/// 연결 상태에 따른 UI 업데이트나 알림 처리에 유용합니다.
///
/// ## 예시
///
/// ```swift
/// class ConnectionHandler: BluetoothManagerDelegate {
///     func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice) {
///         showConnectionSuccessMessage(device.name)
///     }
///     
///     func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?) {
///         if let error = error {
///             handleConnectionError(error)
///         }
///     }
/// }
/// ```
internal protocol BluetoothManagerDelegate: AnyObject, Sendable {
    /// Bluetooth 연결 상태가 변경되었을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - manager: 상태 변경을 보고하는 BluetoothManager
    ///   - state: 새로운 연결 상태
    func bluetoothManager(_ manager: AnyObject, didUpdateState state: ConnectionState)
    
    /// 새로운 디바이스가 발견되었을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - manager: 디바이스를 발견한 BluetoothManager
    ///   - device: 발견된 디바이스 정보
    func bluetoothManager(_ manager: AnyObject, didDiscoverDevice device: BluetoothDevice)
    
    /// 디바이스에 성공적으로 연결되었을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - manager: 연결을 수행한 BluetoothManager
    ///   - device: 연결된 디바이스 정보
    func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice)
    
    /// 디바이스와의 연결이 해제되었을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - manager: 연결 해제를 보고하는 BluetoothManager
    ///   - device: 연결이 해제된 디바이스 정보
    ///   - error: 연결 해제 원인 (자발적 해제인 경우 nil)
    func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?)
}

/// 데이터 기록 이벤트를 처리하는 델리게이트 프로토콜입니다.
///
/// DataRecorder의 기록 시작, 완료, 오류 이벤트를 모니터링하여
/// 사용자에게 적절한 피드백을 제공할 수 있습니다.
/// 기록 상태에 따른 UI 업데이트나 파일 관리에 유용합니다.
///
/// ## 예시
///
/// ```swift
/// class RecordingHandler: DataRecorderDelegate {
///     func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date) {
///         updateUIForRecordingStart()
///     }
///     
///     func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL]) {
///         showRecordingComplete(fileCount: savedFiles.count)
///     }
/// }
/// ```
internal protocol DataRecorderDelegate: AnyObject, Sendable {
    /// 데이터 기록이 시작되었을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - recorder: 기록을 시작한 DataRecorder
    ///   - at: 기록 시작 시간
    func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date)
    
    /// 데이터 기록이 완료되었을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - recorder: 기록을 완료한 DataRecorder
    ///   - at: 기록 완료 시간
    ///   - savedFiles: 저장된 파일들의 URL 목록
    func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL])
    
    /// 데이터 기록 중 오류가 발생했을 때 호출됩니다.
    ///
    /// - Parameters:
    ///   - recorder: 오류가 발생한 DataRecorder
    ///   - error: 발생한 오류 정보
    func dataRecorder(_ recorder: AnyObject, didFailWithError error: Error)
}

// MARK: - Errors

/// BluetoothKit에서 발생할 수 있는 오류들을 정의하는 열거형입니다.
///
/// 각 오류는 구체적인 실패 원인을 나타내며,
/// 사용자에게 적절한 오류 메시지를 제공하는 데 사용됩니다.
/// 모든 오류는 현지화된 설명을 제공합니다.
///
/// **⚠️ 중요: 이 오류들은 SDK에서 자동으로 생성됩니다.**
/// **사용자가 직접 생성하지 마세요. catch 블록에서만 처리하세요.**
///
/// ## 사용 예시
///
/// ```swift
/// // ✅ 올바른 사용법 - 오류 처리
/// switch bluetoothKit.connectionState {
/// case .failed(let error):
///     switch error {
///     case .bluetoothUnavailable:
///         showBluetoothOffAlert()
///     case .connectionFailed(let reason):
///         showConnectionError(reason)
///     default:
///         showGenericError(error.localizedDescription)
///     }
/// default:
///     break
/// }
/// 
/// // ❌ 잘못된 사용법 - 직접 오류 생성하지 마세요
/// // let fakeError = BluetoothKitError.connectionFailed("fake")
/// ```
public enum BluetoothKitError: LocalizedError, Sendable, Equatable {
    /// Bluetooth가 비활성화되어 있거나 사용할 수 없는 상태입니다.
    case bluetoothUnavailable
    
    /// 요청된 디바이스를 찾을 수 없습니다.
    case deviceNotFound
    
    /// 디바이스 연결에 실패했습니다.
    ///
    /// - Parameter reason: 연결 실패 원인에 대한 상세 설명
    case connectionFailed(String)
    
    /// 수신된 데이터의 파싱에 실패했습니다.
    ///
    /// - Parameter reason: 파싱 실패 원인에 대한 상세 설명
    case dataParsingFailed(String)
    
    /// 데이터 기록에 실패했습니다.
    ///
    /// - Parameter reason: 기록 실패 원인에 대한 상세 설명
    case recordingFailed(String)
    
    /// 파일 작업에 실패했습니다.
    ///
    /// - Parameter reason: 파일 작업 실패 원인에 대한 상세 설명
    case fileOperationFailed(String)
    
    /// 오류에 대한 현지화된 설명을 제공합니다.
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