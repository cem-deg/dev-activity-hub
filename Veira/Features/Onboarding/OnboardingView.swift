import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 40)
                    .padding(.top, 36)
                    .padding(.bottom, 24)
            }
            .frame(maxHeight: .infinity)

            Divider()

            navigationBar
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: step1
        case 1: step2
        default: step3
        }
    }

    // MARK: - Step 1

    private var step1: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader(number: 1, title: "Understand Your Work")

            VStack(spacing: 12) {
                infoCard(
                    icon: "chart.bar.fill",
                    title: "What's recorded",
                    body: "Active apps and session durations, broken down per app and session."
                )
                infoCard(
                    icon: "eye.slash.fill",
                    title: "What's never accessed",
                    body: "No keystrokes, screenshots, screen recording, or file access — ever."
                )
                infoCard(
                    icon: "timer",
                    title: "Sessions only",
                    body: "Tracking runs only during an active session. Nothing is recorded in the background."
                )
            }
        }
    }

    // MARK: - Step 2

    private var step2: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader(number: 2, title: "How It Works")

            VStack(alignment: .leading, spacing: 18) {
                iconRow(icon: "play.circle",     text: "Start a session when you begin working")
                iconRow(icon: "chart.bar",       text: "Active app usage is recorded throughout")
                iconRow(icon: "pause.circle",    text: "Pauses after inactivity — idle time is excluded")
                iconRow(icon: "arrow.clockwise", text: "Resume manually when you return")
                iconRow(icon: "clock",           text: "Review your work and recent week in the dashboard")
            }
        }
    }

    // MARK: - Step 3

    private var step3: some View {
        VStack(alignment: .leading, spacing: 28) {
            stepHeader(number: 3, title: "Ready to Start")

            Text("Everything you need is in the menu bar.")
                .font(.title3)
                .fontWeight(.medium)

            VStack(spacing: 12) {
                infoCard(
                    icon: "lock.fill",
                    title: "Local & Private",
                    body: "Your sessions and app usage are stored on your Mac. Nothing leaves your device."
                )

                infoCard(
                    icon: "curlybraces",
                    title: "Open Source",
                    body: "Veira is open source and free to inspect, modify, and contribute to.",
                    link: (label: "github.com/cem-deg/dev-activity-hub",
                           url: URL(string: "https://github.com/cem-deg/dev-activity-hub")!)
                )
            }
        }
    }

    // MARK: - Navigation Bar

    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.15)) { step -= 1 }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if step < 2 {
                Button("Next") {
                    withAnimation(.easeInOut(duration: 0.15)) { step += 1 }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Not now") {
                    appState.markOnboardingComplete()
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("Start Session") {
                    appState.markOnboardingComplete()
                    appState.startSession()
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Helpers

    private func stepHeader(number: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(number) of 3")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title)
                .fontWeight(.semibold)
        }
    }

    private func iconRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.title3)
        }
    }

    private func infoCard(
        icon: String,
        title: String,
        body: String,
        link: (label: String, url: URL)? = nil,
        compact: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: compact ? 10 : 16) {
            Image(systemName: icon)
                .font(compact ? .callout : .title2)
                .foregroundStyle(.secondary)
                .frame(width: compact ? 18 : 28, alignment: .center)

            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                Text(title)
                    .font(compact ? .subheadline : .headline)
                    .fontWeight(.semibold)
                Text(body)
                    .font(compact ? .footnote : .subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let link {
                    Link(destination: link.url) {
                        Label(link.label, systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(compact ? 12 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.secondary.opacity(0.07)))
    }
}
