//
//  DoorAuditApp.swift
//  DoorAuditApp
//
//  Main app entry point with Clean Architecture
//  Created by Derek Punaro on 12/23/25.
//

import SwiftUI
import SwiftData


@main
struct DoorAuditApp: App {
    
    // MARK: - Properties
    
    /// Dependency injection container
    private var dependencies: DependencyContainer {
        DependencyContainer.shared
    }
    
    // MARK: - Initialization
    
    init() {
        Logger.shared.info("🚀 DoorAuditApp Starting...")
        Logger.shared.info("App Version: \(AppConstants.fullVersion)")
        Logger.shared.info("Store: \(AppConstants.Store.fullName)")
        
        // Log system info
        #if DEBUG
        Logger.shared.debug("Running in DEBUG mode")
        #else
        Logger.shared.info("Running in RELEASE mode")
        #endif
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(dependencies.modelContainer)
                .environment(\.dependencies, dependencies)
                .onAppear {
                    Logger.shared.success("✅ App launched successfully")
                }
        }
    }
}

// MARK: - Environment Key for Dependencies
@MainActor
private struct DependencyContainerKey: EnvironmentKey {
    static var defaultValue: DependencyContainer {
        DependencyContainer.shared
    }
}

extension EnvironmentValues {
    @MainActor
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// Access dependencies from environment
    func withDependencies(_ action: @escaping (DependencyContainer) -> Void) -> some View {
        self.task {
            action(DependencyContainer.shared)
        }
    }
}
