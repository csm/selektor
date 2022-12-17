//
//  AlertConfigView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/7/22.
//

import SwiftUI

struct AlertConfigView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var config: Config
    
    @State var alertType: AlertType = .none
    @State var compareAmount: String = ""
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Text("Alert Config").font(.system(size: 18, weight: .black).lowercaseSmallCaps())
            }
            List {
                Section {
                    HStack {
                        Text("None")
                        Spacer()
                        switch alertType{
                        case .none:
                            Image(systemName: "checkmark")
                                .resizable()
                                .frame(width: 12, height: 12)
                        default: EmptyView()
                        }
                    }.onTapGesture {
                        withAnimation {
                            alertType = .none
                        }
                    }
                    
                    HStack {
                        Text("On Every Update")
                        Spacer()
                        switch alertType{
                        case .everyTime:
                            Image(systemName: "checkmark")
                                .resizable()
                                .frame(width: 12, height: 12)
                        default: EmptyView()
                        }
                    }.onTapGesture {
                        Task() {
                            do {
                                if try await checkNotificationPermission() {
                                    DispatchQueue.main.async {
                                        withAnimation {
                                            alertType = .everyTime
                                        }
                                    }
                                }
                            } catch {
                                logger.error("error updating alert type \(error)")
                            }
                        }
                    }
                    
                    HStack {
                        Text("When Value Changes")
                        Spacer()
                        switch alertType {
                        case .valueChanged:
                            Image(systemName: "checkmark")
                                .resizable()
                                .frame(width: 12, height: 12)
                            
                        default:
                            EmptyView()
                        }
                    }.onTapGesture {
                        Task() {
                            do {
                                if try await checkNotificationPermission() {
                                    DispatchQueue.main.async {
                                        withAnimation {
                                            alertType = .valueChanged
                                        }
                                    }
                                }
                            } catch {
                                logger.error("error updating alert type \(error)")
                            }
                        }
                    }
                    
                    HStack {
                        Text("When Value is Greater Than")
                        Spacer()
                        switch alertType {
                        case let .valueIsGreaterThan(_, equals):
                            HStack {
                                TextField("value", text: $compareAmount)
                                    .keyboardType(.numberPad)
                                    .onSubmit {
                                        if let f = Float(compareAmount) {
                                            alertType = .valueIsGreaterThan(value: f, orEquals: equals)
                                        }
                                    }
                                Image(systemName: "checkmark")
                                    .frame(width: 12, height: 12)
                            }
                        default:
                            EmptyView()
                        }
                    }.onTapGesture {
                        switch alertType {
                        case .valueIsGreaterThan: break
                        default:
                            Task() {
                                do {
                                    if try await checkNotificationPermission() {
                                        DispatchQueue.main.async {
                                            withAnimation {
                                                compareAmount = "0"
                                                alertType = .valueIsGreaterThan(value: 0.0)
                                            }
                                        }
                                    }
                                } catch {
                                    logger.error("error updating alert type \(error)")
                                }
                            }
                        }
                    }
                    
                    switch alertType {
                    case let .valueIsGreaterThan(value, equals):
                        HStack {
                            Text("Or Equal To?").padding(.leading, 18)
                            Spacer()
                            if equals {
                                Image(systemName: "checkmark")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                            } else {
                                EmptyView()
                            }
                        }.onTapGesture {
                            withAnimation {
                                alertType = .valueIsGreaterThan(value: value, orEquals: !equals)
                            }
                        }
                    default:
                        EmptyView()
                    }
                    
                    HStack {
                        Text("When Value is Less Than")
                        Spacer()
                        switch alertType {
                        case let .valueIsLessThan(_, equals):
                            HStack {
                                TextField("value", text: $compareAmount)
                                    .keyboardType(.numberPad)
                                    .onSubmit {
                                        if let f = Float(compareAmount) {
                                            alertType = .valueIsLessThan(value: f, orEquals: equals)
                                        }
                                    }.frame(maxWidth: 30, alignment: .trailing)
                                Image(systemName: "checkmark")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                            }
                        default:
                            EmptyView()
                        }
                    }.onTapGesture {
                        switch alertType {
                        case .valueIsLessThan: break
                        default:
                            Task() {
                                do {
                                    if try await checkNotificationPermission() {
                                        DispatchQueue.main.async {
                                            withAnimation {
                                                compareAmount = "0"
                                                alertType = .valueIsLessThan(value: 0.0)
                                            }
                                        }
                                    }
                                } catch {
                                    logger.error("error updating alert type \(error)")
                                }
                            }
                        }
                    }
                    
                    switch alertType {
                    case let .valueIsLessThan(value, equals):
                        HStack {
                            Text("Or Equal To?").padding(.leading, 18)
                            Spacer()
                            if equals {
                                Image(systemName: "checkmark")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                            } else {
                                EmptyView()
                            }
                        }.onTapGesture {
                            alertType = .valueIsLessThan(value: value, orEquals: !equals)
                        }
                    default:
                        EmptyView()
                    }
                }
                
                Section {
                    Toggle("Play Sound", isOn: $config.alertSound).toggleStyle(.switch)
                }
            }.onAppear {
                alertType = config.alertType
            }.onDisappear {
                config.alertType = alertType
            }
        }
    }
    
    func checkNotificationPermission() async throws -> Bool {
        switch alertType {
        case .none:
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        default:
            return true
        }
    }
}

struct AlertConfigView_Previews: PreviewProvider {
    static var previews: some View {
        AlertConfigView(config: Config(context: PersistenceController.preview.container.viewContext)).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
