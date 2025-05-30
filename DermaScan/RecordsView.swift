import SwiftUI
import SwiftCSV

struct ScanRecord: Identifiable, Hashable {
    let id: String
    let imagePath: String
    let resultCount: Int
    let modelVersion: String
    let type: String
    let confidence: Double
    let timestamp: String
}

func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
}

class RecordsManager: ObservableObject {
    @Published var records: [ScanRecord] = []
    
    private let fileManager = FileManager.default
    private let csvPath: URL
    
    init(isPreview: Bool = false) {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.csvPath = documentsDirectory.appendingPathComponent("DermaScanRecords/records.csv")
        
        if isPreview {
            self.records = [
                ScanRecord(id: "20250307104530",
                           imagePath: "Melanoma",
                           resultCount: 1,
                           modelVersion: "1.0",
                           type: "Melanoma",
                           confidence: 0.96,
                           timestamp: "2025-03-07  15:32"),
                ScanRecord(id: "20250307104645",
                           imagePath: "Melanoma",
                           resultCount: 0,
                           modelVersion: "1.0",
                           type: "",
                           confidence: 0,
                           timestamp: "2025-03-07  10:08")
            ]
        } else {
            loadRecords()
        }
    }
    
    func loadRecords() {
        guard fileManager.fileExists(atPath: csvPath.path) else { return }

        do {
            let csvContent = try String(contentsOf: csvPath, encoding: .utf8)
            let csv = try CSV<Named>(string: csvContent)

            let parsedRecords: [ScanRecord] = csv.rows.compactMap { row in
                guard let id = row["ID"],
                      let imagePath = row["ImagePath"],
                      let resultCountString = row["ResultCount"], let resultCount = Int(resultCountString),
                      let modelVersion = row["Model"],
                      let type = row["Type"],
                      let confidenceString = row["Confidence"], let confidence = Double(confidenceString),
                      let timestamp = row["Timestamp"] else {
                    return nil
                }

                return ScanRecord(
                    id: id,
                    imagePath: imagePath,
                    resultCount: resultCount,
                    modelVersion: modelVersion,
                    type: type,
                    confidence: confidence,
                    timestamp: timestamp
                )
            }
            
            DispatchQueue.main.async {
                self.records = parsedRecords
            }
            
        } catch {
            print("CSV parsing failed: \(error)")
        }
    }
    
    func clearCSV() {
        do {
            // Delete CSV File
            if FileManager.default.fileExists(atPath: csvPath.path) {
                try FileManager.default.removeItem(at: csvPath)
            }

            // Delete Image Directory
            let recordsDirectory = csvPath.deletingLastPathComponent()
            let imagesDirectory = recordsDirectory.appendingPathComponent("Images")

            if FileManager.default.fileExists(atPath: imagesDirectory.path) {
                try FileManager.default.removeItem(at: imagesDirectory)
            }

            records.removeAll()
        } catch {
            print("Fail to Clear CSV & Image: \(error)")
        }
    }
}

struct RecordsView: View {
    @StateObject private var navigationManager = NavigationManager()
    @EnvironmentObject var recordsManager: RecordsManager
    @State private var sheetHeight: CGFloat = 400
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            VStack {
                ZStack {
                    Text("Records")
                        .foregroundColor(.white)
                        .font(.system(size: 23, weight: .semibold))
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            recordsManager.clearCSV()
                        }) {
                            ZStack {
                                Circle()
                                    .frame(width: 35, height: 35)
                                    .foregroundColor(Color.black.opacity(0.3))
                                Image("clear")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 22)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 30)
                
                AutoScrollView(maxHeight: availableHeight * 0.75) {
                    VStack(spacing: 20) {
                        ForEach(recordsManager.records.filter { !$0.id.isEmpty }, id: \.id) { record in
                            recordCard(record: record)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 32)
                }
                
                Text(recordsManager.records.isEmpty ? "No Result Found" : "\(recordsManager.records.count) Scan Results")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 18, weight: .medium))
                    .padding(.bottom, 15)
            }
            .onAppear {
                recordsManager.loadRecords()
                sheetHeight = availableHeight
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func recordCard(record: ScanRecord) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
                .frame(height: 87)
            
            HStack(spacing: 17) {
                let imagePath = getDocumentsDirectory().appendingPathComponent("DermaScanRecords/Images/\(record.imagePath)").path
                if let uiImage = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .padding(.top, 2)
                        .padding(.leading, 19)
                } else {
                    Color.gray
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.6))
                        )
                        .padding(.top, 2)
                        .padding(.leading, 19)
                }
                
                VStack(alignment: .leading) {
                    Text(record.resultCount == 0 ? "No Result" : record.type)
                        .foregroundColor(.white)
                        .font(.system(size: 23, weight: .semibold))
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Spacer().frame(height: 3)
                    
                    HStack {
                        if record.resultCount > 0 {
                            Text("\(Int(record.confidence * 100))%")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(record.confidence > 0.85 ? Color(hex: "87C100") :
                                                    (record.confidence > 0.7 ? Color(hex: "FFB545") : Color(hex: "F37878")))
                                .fixedSize(horizontal: true, vertical: false)
                            
                            Spacer().frame(width: 15)
                        }
                        
                        Text(record.timestamp)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                
                Spacer()
            }
        }
        .contentShape(Rectangle())
    }
}

struct AutoScrollView<Content: View>: View {
    let content: Content
    let maxHeight: CGFloat
    @State private var contentHeight: CGFloat = 0
    
    init(maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if contentHeight > maxHeight {
                    ScrollView {
                        content
                            .background(HeightGetter())
                            .onPreferenceChange(ViewHeightKey.self) { newHeight in
                                self.contentHeight = newHeight
                            }
                    }
                } else {
                    content
                        .background(HeightGetter())
                        .onPreferenceChange(ViewHeightKey.self) { newHeight in
                            self.contentHeight = newHeight
                        }
                }
            }
            .frame(width: geometry.size.width, height: min(contentHeight, maxHeight))
        }
    }
}

struct HeightGetter: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: ViewHeightKey.self, value: proxy.size.height)
        }
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    RecordsView()
        .environmentObject(RecordsManager(isPreview: true))
}
