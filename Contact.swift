//
//  Contact.swift
//  BodyGuard
//
//  Created by AFP Student 33 on 10/11/25.
//
import Foundation
import SwiftData

@Model
final class Contact: Identifiable {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var createdAt: Date

    init(id: UUID = UUID(),
         firstName: String,
         lastName: String,
         phoneNumber: String,
         createdAt: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
    }

    var fullName: String { "\(firstName) \(lastName)" }
}

