//
//  IdentificationInfo.swift
//  BundesIdent
//
//  Created by Urs Kahmann on 10.05.23.
//

import ComposableArchitecture
import SwiftUI

struct IdentificationInfo: ReducerProtocol {
    enum Action: Equatable {
        case triggerIdentificationLoading
    }

    struct State: Equatable {
        
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce<State, Action> { state, action in
            switch action {
            case .triggerIdentificationLoading:
                return .none
            }
        }
    }
}

struct IdentificationInfoView: View {
    let store: Store<IdentificationInfo.State, IdentificationInfo.Action>
    
    
    @ViewBuilder
    private var textPlaceholder: some View {
        VStack(alignment: .leading) {
            Color.gray
                .frame(width: 200, height: 30)
                .padding(.bottom, 8)
                .cornerRadius(1)
            Color.gray
                .frame(width: 300, height: 30)
                .padding(.bottom)
                .cornerRadius(1)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
                VStack {
                    Image(asset: Asset.homeIcon)
                        .padding(24)
                    Text("So funktioniert das Identifizieren")
                        .headingL(color: .blue800)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 36)
                }
                Spacer()
            }
            
            textPlaceholder
                .padding()
            textPlaceholder
                .padding()
            textPlaceholder
                .padding()
            
            Spacer()
            Button("Identifizieren") {
                
            }
            .buttonStyle(BundButtonStyle())
        }
        .padding(8)
       
        
    }
}

struct IdentificationInfo_Previews: PreviewProvider {
    static var previews: some View {
        IdentificationInfoView(
            store: Store(
                initialState: IdentificationInfo.State(),
                reducer: IdentificationInfo())
        )
    }
}
