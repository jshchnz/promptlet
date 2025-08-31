//
//  ReadyPage.swift
//  Promptlet
//
//  Final ready page - no scrolling, fixed layout
//

import SwiftUI

struct ReadyPage: View {
    let onTest: () -> Void
    
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 50)
            
            // Success checkmark - 60x60
            ZStack {
                Circle()
                    .fill(Color.success.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.success)
                    .scaleEffect(animate ? 1 : 0)
                    .rotationEffect(.degrees(animate ? 0 : -180))
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    animate = true
                }
            }
            
            Spacer()
                .frame(height: 24)
            
            // Title
            VStack(spacing: 8) {
                Text("You're Ready!")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text("Promptlet is ready to supercharge your workflow")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
                .frame(height: 40)
            
            // Quick tips
            VStack(alignment: .leading, spacing: 16) {
                QuickTip(number: 1, text: "Press your shortcut to open Promptlet")
                QuickTip(number: 2, text: "Type to search your prompts")
                QuickTip(number: 3, text: "Press Enter to insert at cursor")
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondaryBackground.opacity(0.5))
            )
            
            Spacer()
                .frame(height: 32)
            
            // Test button
            Button(action: onTest) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                    Text("Test it now")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accent, lineWidth: 1.5)
                        )
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(width: 600, height: 390)
    }
}

struct QuickTip: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 20, height: 20)
                
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primaryText)
            
            Spacer()
        }
    }
}