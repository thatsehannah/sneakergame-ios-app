//
//  SneakerRepository.swift
//  
//
//  Created by Elliot Hannah III on 4/25/23.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

protocol SneakerRepositoryProtocol {
    func fetchSneakers() async throws -> [Sneaker]
    func add(_ sneaker: Sneaker) async throws
    func update(_ sneaker: Sneaker) async throws
    func delete(_ sneaker: Sneaker) async throws
    func toggleFavorite(_ sneaker: Sneaker) async throws
}

struct SneakerCollectionRepository: SneakerRepositoryProtocol {
    let sneakerCollectionRef = Firestore.firestore().collection("sneaker_collection")
    
    func fetchSneakers() async throws -> [Sneaker] {
        let snapshot = try await sneakerCollectionRef.order(by: "sneakerHistory.dateAdded", descending: true).getDocuments()
        let sneakers = snapshot.documents.compactMap { document in
            try! document.data(as: Sneaker.self)
        }
        return sneakers
    }
    
    func add(_ sneaker: Sneaker) async throws -> Void {
        let document = sneakerCollectionRef.document(sneaker.id.uuidString)
        try await document.setData(from: sneaker)
    }
    
    func update(_ sneaker: Sneaker) async throws -> Void {
        let document = sneakerCollectionRef.document(sneaker.id.uuidString)
        try await document.setData(from: sneaker, merge: true)
    }
    
    func delete(_ sneaker: Sneaker) async throws -> Void {
        let document = sneakerCollectionRef.document(sneaker.id.uuidString)
        try await document.delete()
    }
    
    func toggleFavorite(_ sneaker: Sneaker) async throws {
        let value = sneaker.isFavorite ? true : false
        let document = sneakerCollectionRef.document(sneaker.id.uuidString)
        try await document.setData(["isFavorite": value], merge: true)
    }
}

#if DEBUG
struct SneakerRepositoryStub: SneakerRepositoryProtocol {
    let state: SneakerListViewModel.SneakerCollectionState
    
    private func simulate() async throws -> [Sneaker] {
        switch self.state {
        case .loading:
            try await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            fatalError("Timeout exceeded for 'loading' case preview")
        case .error(let error):
            throw error
        case .data(let sneakers):
            return sneakers
        case .empty:
            return [Sneaker]()
        }
    }
    
    func fetchSneakers() async throws -> [Sneaker] {
        return try await simulate()
    }
    
    func add(_ sneaker: Sneaker) async throws {}
    
    func delete(_ sneaker: Sneaker) async throws {}
    
    func update(_ sneaker: Sneaker) async throws {}
    
    func toggleFavorite(_ sneaker: Sneaker) async throws {}
}
#endif

private extension DocumentReference {
    
    //Creates an async wrapper for the setData(from:) method in Cloud Firestore SDK to account for any possible errors that the setData function throws
    func setData<T: Encodable>(from value: T, merge: Bool = false) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            try! setData(from: value) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }
}
