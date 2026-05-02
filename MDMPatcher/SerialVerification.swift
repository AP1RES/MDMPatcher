import Cocoa
import Foundation

class SerialVerificationManager {
    static let shared = SerialVerificationManager()
    
    private let databaseURL = "https://iospay.cc/mdm/device.txt"
    private var cachedSerials: Set<String> = []
    private var isVerifying = false
    
    // MARK: - Serial Verification
    
    /// Verifica se o serial do dispositivo está registado na base de dados
    /// - Parameter serial: Serial number do dispositivo
    /// - Parameter completion: Closure com resultado da verificação (true = registado, false = não registado)
    func verifySerial(_ serial: String, completion: @escaping (Bool) -> Void) {
        // Se o serial está em cache, retorna imediatamente
        if !cachedSerials.isEmpty {
            DispatchQueue.main.async {
                completion(self.cachedSerials.contains(serial.uppercased()))
            }
            return
        }
        
        // Se já está a verificar, aguarda
        if isVerifying {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                self.verifySerial(serial, completion: completion)
            }
            return
        }
        
        // Fetch da base de dados
        fetchDatabaseFromServer { [weak self] success in
            guard let self = self else { return }
            DispatchQueue.main.async {
                completion(self.cachedSerials.contains(serial.uppercased()))
            }
        }
    }
    
    /// Faz fetch da lista de serials registados do servidor
    /// - Parameter completion: Closure com resultado da operação
    private func fetchDatabaseFromServer(completion: @escaping (Bool) -> Void) {
        isVerifying = true
        
        guard let url = URL(string: databaseURL) else {
            isVerifying = false
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer { self?.isVerifying = false }
            
            guard let data = data, error == nil else {
                NSLog("Serial verification error: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            if let serials = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) {
                self?.cachedSerials = Set(serials.map { $0.trimmingCharacters(in: .whitespaces).uppercased() }.filter { !$0.isEmpty })
                completion(true)
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    /// Reseta o cache de serials
    func clearCache() {
        cachedSerials.removeAll()
    }
}

// MARK: - Helper Functions

/// Mostra alerta de serial não registado
func showUnregisteredSerialAlert(serial: String) {
    let alert = NSAlert()
    alert.messageText = "⚠️ Serial Not Registered"
    alert.informativeText = """
    Please register your serial:
    
    \(serial)
    
    Visit: https://iospay.cc/mdm/register
    
    After registration, please restart the app.
    """
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Copy Serial")
    alert.addButton(withTitle: "Open Browser")
    alert.addButton(withTitle: "Close")
    
    let response = alert.runModal()
    
    switch response {
    case .alertFirstButtonReturn:
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(serial, forType: .string)
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "✅ Copied"
        confirmAlert.informativeText = "Serial number copied to clipboard"
        confirmAlert.alertStyle = .informational
        confirmAlert.addButton(withTitle: "OK")
        confirmAlert.runModal()
        
    case .alertSecondButtonReturn:
        if let url = URL(string: "https://iospay.cc/mdm/register") {
            NSWorkspace.shared.open(url)
        }
        
    default:
        break
    }
}

/// Mostra alerta de erro na verificação
func showVerificationErrorAlert() {
    let alert = NSAlert()
    alert.messageText = "⚠️ Verification Error"
    alert.informativeText = """
    Could not verify serial number.
    
    Please check your internet connection and try again.
    """
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
