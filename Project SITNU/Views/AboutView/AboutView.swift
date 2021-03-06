//
//  AboutView.swift
//  Project SITNU
//
//  Created by Nils Bergmann on 27/09/2020.
//

import SwiftUI
import WatchConnectivity

struct AboutView: View {
    @EnvironmentObject var store: WatchStore
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String ?? "-")
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary!["CFBundleVersion"] as? String ?? "-")
                    }
                    HStack {
                        Text("Log files")
                        NavigationLink(destination: LogFileListView(logFiles: self.store.logFiles)) {
                            Spacer()
                            Text("\(store.logFiles.count)")
                                .foregroundColor(Color(UIColor.systemGray))
                        }
                    }
                    Button("Copy Apple Watch logs") {
                        log.info("Copy watch logs request")
                        WCSession.default.sendMessage(["action": "copyLogs"], replyHandler: nil);
                    }
                        .disabled(!store.canSendMessages)
                }
            }
            .navigationBarTitle("About")
            .onAppear {
                store.updateLogFiles();
            }
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
