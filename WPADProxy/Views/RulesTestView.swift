import SwiftUI

struct RulesTestView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var testURL = ""
    @State private var testResult = ""
    @State private var isTesting = false
    @State private var testHistory: [(url: String, result: String)] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                testInputSection
                
                if !testResult.isEmpty {
                    resultSection
                }
                
                historySection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Test PAC Rules")
        }
    }
    
    private var testInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test URL")
                .font(.headline)
            
            HStack {
                TextField("https://example.com", text: $testURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                
                Button(action: testURL) {
                    if isTesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Text("Test")
                    }
                }
                .disabled(testURL.isEmpty || isTesting)
            }
            
            Text("Enter a URL to test which proxy will be used")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Result")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: resultIcon)
                        .foregroundColor(resultColor)
                    Text(testResult)
                        .font(.system(.body, design: .monospaced))
                }
                
                if testResult.contains("PROXY") {
                    Text("Traffic will be routed through the proxy server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if testResult.contains("DIRECT") {
                    Text("Traffic will bypass the proxy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Test History")
                    .font(.headline)
                Spacer()
                if !testHistory.isEmpty {
                    Button("Clear") {
                        testHistory.removeAll()
                    }
                    .font(.caption)
                }
            }
            
            if testHistory.isEmpty {
                Text("No tests performed yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(testHistory.indices, id: \.self) { index in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(testHistory[index].url)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(testHistory[index].result)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: testHistory[index].result.contains("PROXY") ? "arrow.right.circle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(testHistory[index].result.contains("PROXY") ? .orange : .green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    private func testURL() {
        guard !testURL.isEmpty else { return }
        
        isTesting = true
        
        vpnManager.evaluatePACForURL(testURL) { result in
            DispatchQueue.main.async {
                self.testResult = result ?? "Error evaluating PAC"
                self.testHistory.insert((url: testURL, result: self.testResult), at: 0)
                if self.testHistory.count > 10 {
                    self.testHistory.removeLast()
                }
                self.isTesting = false
            }
        }
    }
    
    private var resultIcon: String {
        if testResult.contains("PROXY") {
            return "arrow.right.circle.fill"
        } else if testResult.contains("DIRECT") {
            return "checkmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var resultColor: Color {
        if testResult.contains("PROXY") {
            return .orange
        } else if testResult.contains("DIRECT") {
            return .green
        } else {
            return .red
        }
    }
}