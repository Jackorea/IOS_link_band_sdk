import Foundation
import CoreBluetooth

// MARK: - BluetoothKit Main Interface

/// 센서 디바이스 연결 및 생체의학 데이터 수집을 위한 포괄적인 Bluetooth Low Energy (BLE) 라이브러리입니다.
///
/// `BluetoothKit`은 다음을 위한 간단한 인터페이스를 제공합니다:
/// - Bluetooth 디바이스 스캔 및 연결
/// - 실시간 센서 데이터 수신 (EEG, PPG, 가속도계, 배터리)
/// - 파일로 데이터 기록
/// - 자동 재연결을 통한 연결 상태 관리
///
/// ## 사용법
///
/// ```swift
/// import SwiftUI
/// import BluetoothKit
///
/// struct ContentView: View {
///     @StateObject private var bluetoothKit = BluetoothKit()
///     
///     var body: some View {
///         VStack {
///             Text("상태: \(bluetoothKit.connectionStatusDescription)")
///             
///             Button("스캔 시작") {
///                 bluetoothKit.startScanning()
///             }
///             .disabled(!bluetoothKit.isConnected && bluetoothKit.isScanning)
///             
///             if let eegReading = bluetoothKit.latestEEGReading {
///                 Text("EEG: \(eegReading.channel1) µV")
///             }
///         }
///     }
/// }
/// ```
///
/// ## 설정
///
/// `SensorConfiguration`을 사용하여 동작을 사용자 정의할 수 있습니다:
///
/// ```swift
/// let config = SensorConfiguration(
///     eegSampleRate: 500.0,
///     deviceNamePrefix: "MyDevice-"
/// )
/// let bluetoothKit = BluetoothKit(configuration: config)
/// ```
@available(iOS 13.0, macOS 10.15, *)
public class BluetoothKit: ObservableObject, @unchecked Sendable {
    
    // MARK: - Public Properties
    
    /// 스캔 중 발견된 Bluetooth 디바이스 목록.
    ///
    /// 이 배열은 스캔 중 새 디바이스가 발견될 때 자동으로 업데이트됩니다.
    /// 디바이스는 설정된 디바이스 이름 접두사로 필터링됩니다.
    @Published public var discoveredDevices: [BluetoothDevice] = []
    
    /// 현재 연결 상태의 사용자 친화적인 설명.
    ///
    /// 연결 상태를 사용자에게 표시하기 위한 한국어 문자열입니다:
    /// - "연결 안됨": 활성 연결 없음
    /// - "스캔 중...": 현재 디바이스 스캔 중  
    /// - "[디바이스명]에 연결 중...": 디바이스 연결 시도 중
    /// - "[디바이스명]에 연결됨": 디바이스에 성공적으로 연결됨
    /// - "[디바이스명]에 재연결 중...": 연결 해제 후 재연결 시도 중
    /// - "실패: [오류 메시지]": 연결 또는 작업 실패
    @Published public var connectionStatusDescription: String = "연결 안됨"
    
    /// 라이브러리가 현재 디바이스를 스캔 중인지 여부.
    @Published public var isScanning: Bool = false
    
    /// 데이터 기록이 현재 활성화되어 있는지 여부.
    ///
    /// `true`일 때, 수신된 모든 센서 데이터가 파일에 저장됩니다.
    @Published public var isRecording: Bool = false
    
    /// auto-reconnection이 현재 활성화되어 있는지 여부.
    ///
    /// `true`일 때, 연결이 끊어지면 라이브러리가 자동으로 재연결을 시도합니다.
    @Published public var isAutoReconnectEnabled: Bool = true
    
    // 최신 센서 읽기값
    
    /// 가장 최근의 EEG (뇌전도) 읽기값.
    ///
    /// 마이크로볼트(µV) 단위의 2채널 뇌 활동 데이터와 lead-off 상태를 포함합니다.
    /// 아직 EEG 데이터를 받지 못한 경우 `nil`입니다.
    @Published public var latestEEGReading: EEGReading?
    
    /// 가장 최근의 PPG (광전 용적 맥파) 읽기값.
    ///
    /// 심박수 모니터링을 위한 적색 및 적외선 LED 값을 포함합니다.
    /// 아직 PPG 데이터를 받지 못한 경우 `nil`입니다.
    @Published public var latestPPGReading: PPGReading?
    
    /// 가장 최근의 가속도계 읽기값.
    ///
    /// 모션 감지를 위한 3축 가속도 데이터를 포함합니다.
    /// 아직 가속도계 데이터를 받지 못한 경우 `nil`입니다.
    @Published public var latestAccelerometerReading: AccelerometerReading?
    
    /// 가장 최근의 배터리 레벨 읽기값.
    ///
    /// 연결된 디바이스의 배터리 백분율(0-100%)을 포함합니다.
    /// 아직 배터리 데이터를 받지 못한 경우 `nil`입니다.
    @Published public var latestBatteryReading: BatteryReading?
    
    /// 기록된 데이터 파일 목록.
    ///
    /// 기록이 완료되면 자동으로 업데이트됩니다.
    /// 각 기록 세션은 여러 CSV 파일(센서 타입당 하나)을 생성합니다.
    @Published public var recordedFiles: [URL] = []
    
    /// Bluetooth가 현재 비활성화되어 있는지 여부.
    ///
    /// Bluetooth가 꺼지면 자동으로 `true`로 설정됩니다.
    @Published public var isBluetoothDisabled: Bool = false
    
    // MARK: - Internal Properties
    
    /// 내부 연결 상태 (SDK 내부 사용만).
    internal var connectionState: ConnectionState = .disconnected
    
    // MARK: - Private Components
    
    private let bluetoothManager: BluetoothManager
    private let dataRecorder: DataRecorder
    private let configuration: SensorConfiguration
    private let logger: InternalLogger
    
    // MARK: - Initialization
    
    /// 새로운 BluetoothKit 인스턴스를 생성합니다.
    /// 
    /// 이 생성자는 센서 데이터 수집을 위한 BluetoothKit을 초기화합니다.
    /// 모든 설정이 기본값으로 설정되며, 바로 사용할 수 있는 상태가 됩니다.
    ///
    /// ## 초기 설정값
    /// - 로깅: 비활성화 (성능 최적화)
    /// - 자동 재연결: 활성화
    /// - 디바이스 필터: LXB- 접두사
    ///
    /// ## 사용법
    /// ```swift
    /// // 인스턴스 생성
    /// let bluetoothKit = BluetoothKit()
    /// 
    /// // 생성 후 필요한 설정 변경
    /// bluetoothKit.setAutoReconnect(enabled: false)
    /// ```
    public init() {
        self.configuration = .default
        self.logger = InternalLogger(isEnabled: false)  // 프로덕션 최적화
        self.bluetoothManager = BluetoothManager(configuration: configuration, logger: logger)
        self.dataRecorder = DataRecorder(logger: logger)
        
        // 기본값: auto-reconnect 활성화 (대부분의 경우 유용함)
        self.isAutoReconnectEnabled = true
        
        setupDelegates()
        updateRecordedFiles()
        
        // BluetoothManager에 초기 auto-reconnect 설정 전달
        bluetoothManager.enableAutoReconnect(true)
    }
    
    // MARK: - Public Interface
    
    /// Bluetooth 디바이스 스캔을 시작합니다.
    ///
    /// 설정된 `deviceNamePrefix`와 일치하는 디바이스만 검색됩니다.
    /// 디바이스가 발견되면 `discoveredDevices` 배열이 업데이트됩니다.
    ///
    /// - Note: 이 메서드를 호출하기 전에 Bluetooth가 활성화되어 있는지 확인하세요.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// bluetoothKit.startScanning()
    /// 
    /// // 스캔 상태 모니터링
    /// if bluetoothKit.isScanning {
    ///     print("스캔 진행 중...")
    /// }
    /// ```
    public func startScanning() {
        bluetoothManager.startScanning()
    }
    
    /// Bluetooth 디바이스 스캔을 중지합니다.
    ///
    /// 진행 중인 모든 디바이스 검색 프로세스를 취소합니다.
    public func stopScanning() {
        bluetoothManager.stopScanning()
    }
    
    /// 특정 Bluetooth 디바이스에 연결합니다.
    ///
    /// - Parameter device: `discoveredDevices`에서 얻은 연결할 디바이스.
    ///
    /// 연결 진행 상황은 `connectionStatusDescription`을 통해 모니터링할 수 있습니다.
    /// 연결 성공 시, 센서 데이터가 자동으로 스트리밍을 시작합니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// if let device = bluetoothKit.discoveredDevices.first {
    ///     bluetoothKit.connect(to: device)
    /// }
    /// 
    /// // 연결 상태 모니터링
    /// Text("연결 상태: \(bluetoothKit.connectionStatusDescription)")
    /// 
    /// // 연결 완료 확인
    /// if bluetoothKit.isConnected {
    ///     Text("데이터 수신 준비 완료")
    /// }
    /// ```
    public func connect(to device: BluetoothDevice) {
        bluetoothManager.connect(to: device)
    }
    
    /// 현재 연결된 디바이스에서 연결을 해제합니다.
    ///
    /// 기록이 활성화되어 있다면, 연결 해제 전에 자동으로 중지됩니다.
    /// 이 연결 해제에 대해 auto-reconnection을 비활성화합니다.
    public func disconnect() {
        if isRecording {
            stopRecording()
        }
        bluetoothManager.disconnect()
    }
    
    /// 센서 데이터를 파일로 기록하기 시작합니다.
    ///
    /// documents 디렉토리에 각 센서 타입별로 타임스탬프가 찍힌 CSV 파일을 생성합니다.
    /// `stopRecording()`이 호출될 때까지 기록이 계속됩니다.
    ///
    /// - Note: 기록이 의미를 갖기 위해서는 디바이스가 연결되어 데이터를 스트리밍해야 합니다.
    ///
    /// ## 파일 형식
    ///
    /// 다음 CSV 파일들이 생성됩니다:
    /// - `YYYYMMDD_HHMMSS_eeg.csv`: 타임스탬프, channel1, channel2, leadOff가 포함된 EEG 데이터
    /// - `YYYYMMDD_HHMMSS_ppg.csv`: 타임스탬프, red, ir이 포함된 PPG 데이터
    /// - `YYYYMMDD_HHMMSS_accel.csv`: 타임스탬프, x, y, z가 포함된 가속도계 데이터
    /// - `YYYYMMDD_HHMMSS_raw.json`: JSON 형식의 완전한 세션 데이터
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 기록 시작
    /// bluetoothKit.startRecording()
    /// 
    /// // 기록 상태 모니터링
    /// if bluetoothKit.isRecording {
    ///     print("센서 데이터 기록 중...")
    /// }
    /// 
    /// // 30초 후 중지
    /// DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    ///     bluetoothKit.stopRecording()
    /// }
    /// ```
    public func startRecording() {
        dataRecorder.startRecording()
    }
    
    /// 센서 데이터 기록을 중지합니다.
    ///
    /// 모든 데이터 파일을 마무리하고 저장합니다. `recordedFiles` 배열이
    /// 저장된 파일들의 URL로 업데이트됩니다.
    public func stopRecording() {
        dataRecorder.stopRecording()
    }
    
    /// 기록이 저장되는 디렉토리를 가져옵니다.
    ///
    /// - Returns: CSV 및 JSON 파일이 저장되는 documents 디렉토리의 URL.
    ///
    /// 기록된 파일에 프로그래밍적으로 접근하거나 공유 기능을 위해 사용하세요.
    public var recordingsDirectory: URL {
        return dataRecorder.recordingsDirectory
    }
    
    /// 현재 디바이스에 연결되어 있는지 확인합니다.
    ///
    /// - Returns: 디바이스가 연결되어 데이터 스트리밍 준비가 되었으면 `true`.
    public var isConnected: Bool {
        return bluetoothManager.isConnected
    }
    
    /// auto-reconnection을 활성화하거나 비활성화합니다.
    ///
    /// - Parameter enabled: 연결이 끊어졌을 때 자동으로 재연결할지 여부.
    ///
    /// 활성화되면, 연결이 예기치 않게 끊어졌을 때(사용자 작업이 아닌 경우)
    /// 라이브러리가 자동으로 마지막에 연결된 디바이스에 재연결을 시도합니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 견고한 연결을 위해 auto-reconnect 활성화
    /// bluetoothKit.setAutoReconnect(enabled: true)
    /// 
    /// // 수동 연결 제어를 위해 비활성화
    /// bluetoothKit.setAutoReconnect(enabled: false)
    /// ```
    public func setAutoReconnect(enabled: Bool) {
        isAutoReconnectEnabled = enabled
        bluetoothManager.enableAutoReconnect(enabled)
    }
    
    // MARK: - Private Setup
    
    private func setupDelegates() {
        bluetoothManager.delegate = self
        bluetoothManager.sensorDataDelegate = self
        dataRecorder.delegate = self
    }
    
    private func updateRecordedFiles() {
        recordedFiles = dataRecorder.getRecordedFiles()
    }
}

// MARK: - BluetoothManagerDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: BluetoothManagerDelegate {
    
    internal func bluetoothManager(_ manager: AnyObject, didUpdateState state: ConnectionState) {
        connectionState = state
        connectionStatusDescription = state.description
        isScanning = bluetoothManager.isScanning
        
        if case .failed(let error) = state,
           error.localizedDescription.contains("Bluetooth is not available") {
            isBluetoothDisabled = true
        } else {
            isBluetoothDisabled = false
        }
    }
    
    internal func bluetoothManager(_ manager: AnyObject, didDiscoverDevice device: BluetoothDevice) {
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == device.peripheral.identifier }) {
            discoveredDevices.append(device)
        }
    }
    
    internal func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice) {
        // 연결 성공 로그 제거
    }
    
    internal func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?) {
        if let error = error {
            log("Disconnected from \(device.name) with error: \(error.localizedDescription)")
        }
        // 정상 연결 해제는 로그하지 않음
    }
}

// MARK: - SensorDataDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: SensorDataDelegate {
    
    internal func didReceiveEEGData(_ reading: EEGReading) {
        latestEEGReading = reading
        
        if isRecording {
            dataRecorder.recordEEGData([reading])
        }
    }
    
    internal func didReceivePPGData(_ reading: PPGReading) {
        latestPPGReading = reading
        
        if isRecording {
            dataRecorder.recordPPGData([reading])
        }
    }
    
    internal func didReceiveAccelerometerData(_ reading: AccelerometerReading) {
        latestAccelerometerReading = reading
        
        if isRecording {
            dataRecorder.recordAccelerometerData([reading])
        }
    }
    
    internal func didReceiveBatteryData(_ reading: BatteryReading) {
        latestBatteryReading = reading
        
        if isRecording {
            dataRecorder.recordBatteryData(reading)
        }
    }
}

// MARK: - DataRecorderDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: DataRecorderDelegate {
    
    internal func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date) {
        isRecording = true
    }
    
    internal func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL]) {
        isRecording = false
        recordedFiles = savedFiles
    }
    
    internal func dataRecorder(_ recorder: AnyObject, didFailWithError error: Error) {
        isRecording = false
        log("Recording failed: \(error.localizedDescription)")
    }
    
    // MARK: - Private Logging
    
    private func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger.log(message, file: file, function: function, line: line)
    }
} 