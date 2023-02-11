//
//  AlertConfigView.swift
//  Selektor
//
//  Created by Casey Marshall on 12/7/22.
//

import SwiftUI
import RealmSwift
import UserNotifications

struct AlertConfigView: View {
    @Environment(\.realm) private var realm
    @Environment(\.dismiss) private var dismiss
    
    let id: ObjectId
    
    @State var alertType: AlertType = .none
    @State var compareAmount: Decimal = Decimal(0)
    @State var orEquals: Bool = false
    @State var playSound: Bool = false
    @State var timeSensitive: Bool = false
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Text("Alert Config").font(.system(size: 18, weight: .black).lowercaseSmallCaps())
            }
            SwiftUI.List {
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
                        alertType = .none
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
                                        alertType = .everyTime
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
                                        alertType = .valueChanged
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
                                TextField("value", text: ($compareAmount).stringBinding())
                                    .keyboardType(.numberPad)
                                    .onSubmit {
                                        alertType = .valueIsGreaterThan(value: compareAmount, orEquals: equals)
                                    }.frame(maxWidth: 30, alignment: .trailing)
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
                                            compareAmount = Decimal()
                                            alertType = .valueIsGreaterThan(value: compareAmount)
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
                            alertType = .valueIsGreaterThan(value: value, orEquals: !equals)
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
                                TextField("value", text: ($compareAmount).stringBinding())
                                    .keyboardType(.numberPad)
                                    .onSubmit {
                                        alertType = .valueIsLessThan(value: compareAmount, orEquals: equals)
                                    }
                                    .frame(maxWidth: 30, alignment: .trailing)
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
                                            compareAmount = Decimal()
                                            alertType = .valueIsLessThan(value: compareAmount)
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
                    Toggle("Play Sound", isOn: $playSound).toggleStyle(.switch)
                    Toggle("Time Sensitive", isOn: $timeSensitive).toggleStyle(.switch)
                }
            }
        }.onAppear {
            if let config = realm.object(ofType: ConfigV2.self, forPrimaryKey: id) {
                alertType = config.alertType
                switch alertType {
                case let .valueIsLessThan(value, orEq):
                    compareAmount = value
                    orEquals = orEq
                case let .valueIsGreaterThan(value, orEq):
                    compareAmount = value
                    orEquals = orEq
                default: break
                }
            }
        }.onDisappear {
            do {
                try realm.write {
                    if let config = realm.object(ofType: ConfigV2.self, forPrimaryKey: id) {
                        switch alertType {
                        case .none, .everyTime, .valueChanged:
                            config.alertType = alertType
                        case .valueIsGreaterThan(_, let orEquals):
                            config.alertType = .valueIsGreaterThan(value: compareAmount, orEquals: orEquals)
                        case .valueIsLessThan(_, let orEquals):
                            config.alertType = .valueIsLessThan(value: compareAmount, orEquals: orEquals)
                        }
                        config.alertSound = playSound
                        config.alertTimeSensitive = timeSensitive
                    }
                }
            } catch {
                logger.warning("could not save: \(error)")
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
        AlertConfigView(id: ObjectId())
    }
}
