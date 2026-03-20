import SwiftUI

// MARK: - Conflict detail sheet

struct ConflictDetailSheet: View {
    let preview: CalendarEventPreview
    let onKeep: () -> Void
    let onCancel: () async -> Void
    let onFindFreeSlots: () async -> [CalendarFreeSlot]
    let onReschedule: (CalendarFreeSlot) async -> Void

    @State private var freeSlots: [CalendarFreeSlot] = []
    @State private var isLoadingSlots = false
    @State private var hasSearched = false
    @State private var isCancelling = false
    @State private var sheetDetent: PresentationDetent = .medium
    @Environment(\.dismiss) private var dismiss

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    conflictsSection
                    Divider()
                    actionsSection
                }
                .padding(20)
            }
            .navigationTitle("Scheduling Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Conflicts section

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Overlapping events", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                ForEach(preview.conflictingEvents, id: \.title) { conflict in
                    conflictRow(conflict)
                }
            }
        }
    }

    private func conflictRow(_ conflict: ConflictingEventSnapshot) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.orange.opacity(0.7))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(conflict.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if conflict.isRecurring {
                        HStack(spacing: 2) {
                            Image(systemName: "repeat")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Recurring")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    }
                }
                if conflict.isAllDay {
                    Text("All day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Self.timeFormatter.string(from: conflict.start)) – \(Self.timeFormatter.string(from: conflict.end))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let cal = conflict.calendarName {
                    Text(cal)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Actions section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What would you like to do?")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 10) {
                keepButton
                findFreeSlotButton
                cancelEventButton
            }

            // Free slot results
            if !freeSlots.isEmpty {
                Divider()
                freeSlotsSection
            } else if hasSearched {
                Text("No free slots found in the next 7 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var keepButton: some View {
        Button {
            onKeep()
            dismiss()
        } label: {
            Label("Keep Anyway", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var findFreeSlotButton: some View {
        Button {
            guard !isLoadingSlots else { return }
            isLoadingSlots = true
            Task { @MainActor in
                freeSlots = await onFindFreeSlots()
                isLoadingSlots = false
                hasSearched = true
                if !freeSlots.isEmpty {
                    withAnimation(.spring(duration: 0.4)) { sheetDetent = .large }
                }
            }
        } label: {
            HStack {
                Label("Find Free Slot", systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                if isLoadingSlots {
                    ProgressView()
                        .controlSize(.small)
                } else if !freeSlots.isEmpty {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoadingSlots)
    }

    private var cancelEventButton: some View {
        Button {
            guard !isCancelling else { return }
            isCancelling = true
            Task {
                await onCancel()
                dismiss()
            }
        } label: {
            HStack {
                Label("Cancel Event", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Spacer()
                if isCancelling {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isCancelling)
    }

    // MARK: - Free slots

    private var freeSlotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available slots — tap to reschedule")
                .font(.subheadline.weight(.semibold))

            ForEach(freeSlots.prefix(5)) { slot in
                Button {
                    Task {
                        await onReschedule(slot)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.dateTimeFormatter.string(from: slot.start))
                                .font(.subheadline.weight(.medium))
                            Text("until \(Self.timeFormatter.string(from: slot.end))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
