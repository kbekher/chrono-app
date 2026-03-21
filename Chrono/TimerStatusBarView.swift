//
//  TimerStatusBarView.swift
//  Chrono
//
//  Created by Ivan on 15.11.25.
//

import SwiftUI

struct TimerStatusBarView: View {
    @ObservedObject var viewModel: TimerViewModel
    
    var body: some View {
        Text(viewModel.formattedTime())
            .font(.system(size: 13, weight: .medium, design: .default))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                Capsule()
                    .fill(Color(red: 0x76/255.0, green: 0x76/255.0, blue: 0x80/255.0).opacity(0.60))
            )
            .fixedSize(horizontal: true, vertical: false)
    }
}
