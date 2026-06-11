import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var controller: NightKController

    private var text: NightKText {
        controller.language.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            mainToggle
            gradualTransitionToggle
            launchAtLoginToggle
            divider
            languageSection
            divider
            temperatureSection
            divider
            scheduleSection
            divider
            footer
        }
        .padding(18)
        .frame(width: 360)
        .onAppear { controller.refreshLaunchAtLogin() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NightK")
                .font(.title2.bold())

            Text(text.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var mainToggle: some View {
        HStack {
            Text(text.enabled)
                .font(.body.weight(.medium))

            Spacer()

            Toggle("", isOn: $controller.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var gradualTransitionToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(text.gradualTransition)
                    .font(.body.weight(.medium))

                Spacer()

                Toggle("", isOn: $controller.gradualTransitionEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Text(text.gradualTransitionHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var launchAtLoginToggle: some View {
        HStack {
            Text(text.launchAtLogin)
                .font(.body.weight(.medium))

            Spacer()

            Toggle("", isOn: Binding(
                get: { controller.launchAtLogin },
                set: { controller.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.language)
                .font(.headline)

            Picker("", selection: $controller.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(text.temperature)
                    .font(.headline)

                Spacer()

                Text("\(controller.temperatureKelvin)K")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: {
                        Double(controller.temperatureKelvin)
                    },
                    set: { newValue in
                        controller.setTemperatureKelvin(Int(newValue.rounded()))
                    }
                ),
                in: Double(Temperature.range.lowerBound)...Double(Temperature.range.upperBound),
                step: Double(Temperature.step)
            )

            HStack {
                Text("\(Temperature.range.lowerBound)K")
                Spacer()
                Text("\(Temperature.range.upperBound)K")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(text.temperatureHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text.schedule)
                .font(.headline)

            VStack(spacing: 10) {
                timeRow(
                    title: text.start,
                    value: Binding(
                        get: { controller.startTime },
                        set: { controller.setStartTime($0) }
                    )
                )

                timeRow(
                    title: text.end,
                    value: Binding(
                        get: { controller.endTime },
                        set: { controller.setEndTime($0) }
                    )
                )
            }

            Text(text.scheduleHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func timeRow(title: String, value: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))

            Spacer()

            DatePicker("", selection: value, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private var footer: some View {
        HStack {
            statusBadge

            Spacer()

            Button(text.reset) {
                controller.restoreDisplays()
            }

            Button(text.quit) {
                controller.restoreDisplays()
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var statusBadge: some View {
        Text(controller.isCurrentlyActive ? text.active : text.inactive)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary)
            .clipShape(Capsule())
    }

    private var divider: some View {
        Divider()
    }
}

#Preview {
    ContentView()
        .environmentObject(NightKController.shared)
}