//
//  ContentView.swift
//  Project SITNU
//
//  Created by Nils Bergmann on 18/09/2020.
//

import SwiftUI

class AddNavigationController: ObservableObject {
    @Published var addsAccount: Bool = false;
}

struct RootView: View {
    @EnvironmentObject var store: WatchStore
    @ObservedObject var addNavigationController: AddNavigationController = AddNavigationController();
    @State private var editMode = EditMode.inactive
    @State var isSearchViewActive: Bool = false
    let throttler = Throttler(minimumDelay: 1.0)
    
    var body: some View {
        NavigationView {
            if !self.store.available {
                Text("Watch App is not available")
                    .padding()
            } else {
                List {
                    ForEach(self.store.accounts) { (acc: UntisAccount) in
                        if acc.primary {
                            Text("\(acc.displayName) (Primary)")
                        } else {
                            Text(acc.displayName)
                        }
                    }
                    .onDelete { (index) in
                        self.store.accounts.remove(atOffsets: index);
                        if self.store.accounts.firstIndex(where: { $0.primary }) == nil && self.store.accounts.count > 0 {
                            self.store.accounts[0].primary = true;
                        }
                        self.store.sync();
                    }
                }
                    .environment(\.editMode, $editMode)
                .navigationBarItems(leading: Button(action: {
                    if self.editMode == .inactive {
                        self.editMode = .active;
                    } else {
                        self.editMode = .inactive;
                    }
                }) {
                    Text("Edit")
                        .frame(height: 44)
                }, trailing: self.addButton)
                    .navigationBarTitle("WebUntis Accounts")
            }
        }
    }
    
    private var addButton: some View {
        switch editMode {
        case .inactive:
            return AnyView(
                Button(action: {
                    self.addNavigationController.addsAccount = true;
                }) {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }.sheet(isPresented: self.$addNavigationController.addsAccount) {
                    SchoolSearchView()
                        .environmentObject(self.addNavigationController)
                        .environmentObject(self.store)
                }
            )
        default:
            return AnyView(EmptyView())
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
