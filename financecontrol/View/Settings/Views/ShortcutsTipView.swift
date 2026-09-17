//
//  ShortcutsTipView.swift
//  Galla
//
//  Explains how to use Galla's App Shortcut with Siri and Back Tap.
//

import SwiftUI
import AppIntents

@available(iOS 16.4, *)
struct ShortcutsTipView: View {
    var body: some View {
        List {
            Section("Siri") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\"Log expense in Galla\"")
                            .font(.headline)
                        Text("Say this to Siri or use Log Expense from the Shortcuts app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)
            }

            Section("Double Back Tap") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assign Log Expense")
                            .font(.headline)
                        Text("In iPhone Settings, open Accessibility → Touch → Back Tap → Double Tap, then choose Log Expense.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hand.tap.fill")
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log Expense")
                            .font(.headline)
                        Text("Enter an amount, choose a category, and save without opening Galla.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Available Shortcut")
            } footer: {
                Text("Open Galla once after installing an update so iOS can refresh its available App Shortcuts.")
            }

            if #available(iOS 17.0, *) {
                Section("Open Shortcuts") {
                    ShortcutsLink()
                }
            }
        }
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
