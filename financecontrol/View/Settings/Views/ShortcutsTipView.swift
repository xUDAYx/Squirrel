//
//  ShortcutsTipView.swift
//  Squirrel
//
//  Settings page explaining Siri Shortcuts integration.
//

import SwiftUI
import AppIntents

@available(iOS 16.4, *)
struct ShortcutsTipView: View {
    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\"Log expense in Galla\"")
                            .font(.headline)
                        Text("Say this to Siri or add the shortcut to your Home Screen, Back Tap, or Action Button.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Siri")
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log Expense")
                            .font(.headline)
                        Text("Enter amount, pick a category, and save — all without opening the app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Available Shortcuts")
            } footer: {
                Text("Open the Shortcuts app to customize triggers like Back Tap, widgets, or automation.")
            }

            if #available(iOS 17.0, *) {
                Section {
                    ShortcutsLink()
                } header: {
                    Text("Open Shortcuts")
                }
            }
        }
        .navigationTitle("Siri & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
