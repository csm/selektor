//
//  ConfigView.swift
//  SelektorMac
//
//  Created by Casey Marshall on 1/4/23.
//

import SwiftUI

struct ConfigView: View {
    @ObservedObject var config: Config

    var body: some View {
        HStack(alignment: .top) {
            Text(config.name ?? "New Config")
            Spacer()
            Text(config.result?.description() ?? "").lineLimit(nil).foregroundColor(.gray).font(.system(size: 12))
        }
    }
}

struct ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigView(config: Config())
    }
}
