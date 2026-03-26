import SwiftUI

struct CreateEventSheet: View {
    let draft: SiriPendingEvent
    let onConfirm: (String, Date, Date, Bool, String?, String?) throws -> Void

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var location = ""
    @State private var notes = ""
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(draft: SiriPendingEvent, onConfirm: @escaping (String, Date, Date, Bool, String?, String?) throws -> Void) {
        self.draft = draft
        self.onConfirm = onConfirm
        _title = State(initialValue: draft.title)
        let start = draft.date
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    Toggle("All Day", isOn: $isAllDay)
                }

                Section("Time") {
                    if isAllDay {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    } else {
                        DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Optional") {
                    TextField("Location", text: $location)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { createEvent() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: isAllDay) { _, allDay in
                if allDay {
                    startDate = Calendar.current.startOfDay(for: startDate)
                    endDate = startDate
                } else {
                    endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                }
            }
            .onChange(of: startDate) { _, newStart in
                if !isAllDay && endDate <= newStart {
                    endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
                }
            }
        }
        .presentationDetents([.large])
    }

    private func createEvent() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        do {
            try onConfirm(
                trimmed,
                startDate,
                isAllDay ? startDate : endDate,
                isAllDay,
                location.isEmpty ? nil : location,
                notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
