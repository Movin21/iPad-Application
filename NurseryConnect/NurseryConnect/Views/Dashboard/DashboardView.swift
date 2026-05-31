// Views/Dashboard/DashboardView.swift
// NurseryConnect — Clinical Sanctuary Dashboard
// Gradient hero header · colorful stats · notification bell · Add Child button

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var allChildren: [Child]

    @State private var vm            = DashboardViewModel()
    @State private var showingAddChild = false
    @State private var appeared        = false

    private var children: [Child] { vm.filteredChildren(allChildren) }

    /// Children with allergies or medical notes
    private var medicalAlertCount: Int {
        children.filter { $0.hasActiveAlerts }.count
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ncBg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {

                        // MARK: Logo + Add Child row
                        HStack(alignment: .center) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 68)

                            Spacer()

                            Button {
                                HapticFeedback.medium()
                                showingAddChild = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.subheadline.weight(.bold))
                                    Text("Add Child")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(LinearGradient.ncPrimaryCTA, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                        // MARK: Hero Greeting Card
                        heroHeader
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)

                        // MARK: Colorful Stats Strip
                        statsStrip
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)

                        // MARK: Search
                        searchBar
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // MARK: Children list
                        Section {
                            if children.isEmpty {
                                emptyState.padding(.top, 60)
                            } else {
                                ForEach(children) { child in
                                    NavigationLink(value: child) {
                                        ChildCardView(child: child)
                                            .padding(.horizontal, 20)
                                            .padding(.bottom, 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            sectionHeader("My Key Children")
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Child.self) { ChildDetailView(child: $0) }
            .sheet(isPresented: $showingAddChild) { AddChildView() }
            .onAppear {
                guard !appeared else { return }
                vm.seedSampleDataIfNeeded(context: context)
                appeared = true
            }
        }
        .tint(Color.ncAccent)
    }

    // MARK: - Hero Greeting Card

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient.ncPrimaryCTA
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // Decorative blurred circles
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 180)
                .blur(radius: 2)
                .offset(x: 220, y: -10)

            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 90)
                .blur(radius: 1)
                .offset(x: 280, y: 40)

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))

                Text("Keyworker")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 118)
        .ncGlassShadow()
    }

    // MARK: - Colorful Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 10) {
            ColorStatPill(
                value: "\(children.count)",
                label: "Children",
                symbol: "figure.and.child.holdinghands",
                accent: Color(hex: "2a6677")
            )
            ColorStatPill(
                value: "\(vm.todayObservationCount(for: allChildren))",
                label: "Obs. Today",
                symbol: "pencil.and.list.clipboard",
                accent: Color(hex: "3b6850")
            )
            ColorStatPill(
                value: "\(medicalAlertCount)",
                label: "Medical",
                symbol: "cross.circle.fill",
                accent: medicalAlertCount > 0
                    ? Color(hex: "a83836")
                    : Color(hex: "5e5f5f")
            )
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.ncOnSurfaceVariant)
                .font(.subheadline)
            TextField("Search children…", text: $vm.searchText)
                .autocorrectionDisabled()
                .foregroundStyle(Color.ncOnSurface)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.ncSurfaceLow, in: RoundedRectangle(cornerRadius: NCRadius.input))
    }

    // MARK: - Section Header (Accented)

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.ncAccent)
                .frame(width: 3, height: 14)
            Text(title.uppercased())
                .font(NCFont.sectionHeader())
                .foregroundStyle(Color.ncAccent)
            Spacer()
            if !children.isEmpty {
                Text("\(children.count) children")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.ncOnSurfaceVariant)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.ncBg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 52))
                .foregroundStyle(Color.ncAccent.opacity(0.5))
            Text("No Children Assigned")
                .font(NCFont.title())
                .foregroundStyle(Color.ncOnSurface)
            Text("Tap Add Child to add a child to your key group.")
                .font(NCFont.body())
                .foregroundStyle(Color.ncOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Coloured Stat Pill

private struct ColorStatPill: View {
    let value: String
    let label: String
    let symbol: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(height: 24)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ncOnSurface)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: NCRadius.badge))
    }
}
