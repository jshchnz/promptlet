//
//  ReadyPage.swift
//  Promptlet
//
//  Final ready page - pixel-perfect spacing
//

import SwiftUI

struct ReadyPage: View {
    let onTest: () -> Void
    
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top spacing - 30px
            Spacer()
                .frame(height: 30)
            
            // Success checkmark - 60x60
            ZStack {
                Circle()
                    .fill(Color.success.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.success)
                    .scaleEffect(animate ? 1 : 0)
                    .rotationEffect(.degrees(animate ? 0 : -180))
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    animate = true
                }
            }
            
            // Spacing - 25px
            Spacer()
                .frame(height: 25)
            
            // Title - ~45px
            VStack(spacing: 8) {
                Text("You're Ready!")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text("Promptlet is ready to supercharge your workflow")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            
            // Spacing - 35px
            Spacer()
                .frame(height: 35)
            
            // Quick tips - ~80px
            VStack(alignment: .leading, spacing: 12) {
                QuickTip(number: 1, text: "Press your shortcut to open Promptlet")
                QuickTip(number: 2, text: "Type to search your prompts")
                QuickTip(number: 3, text: "Press Enter to insert at cursor")
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondaryBackground.opacity(0.5))
            )
            .frame(height: 80)
            
            // Spacing - 30px
            Spacer()
                .frame(height: 30)
            
            // Test button - ~30px
            Button(action: onTest) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 15))
                    Text("Test it now")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accent, lineWidth: 1.5)
                        )
                )
            }
            .buttonStyle(.plain)
            
            // Bottom spacing - 25px
            Spacer()
                .frame(height: 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QuickTip: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 18, height: 18)
                
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primaryText)
            
            Spacer()
        }
    }
}