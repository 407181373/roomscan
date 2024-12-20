//
//  CaptureRoomExtensions.swift
//  SpaceScanner
//
//  Created by Niranjan Ravichandran on 8/29/22.
//

import Foundation
import RoomPlan

extension CapturedRoom {

    var isValidScan: Bool {
        !walls.isEmpty && !doors.isEmpty && !objects.isEmpty && !windows.isEmpty && !openings.isEmpty
    }

}

extension CapturedRoom.Object.Category: CaseIterable {

    public static var normalObjectCases: [CapturedRoom.Object.Category] {
        [
            .storage,
            .refrigerator,
            .stove,
//            .bed,
//            .table,
//            .sofa,
//            .chair,
            .sink,
            .washerDryer,
            .toilet,
            .bathtub,
            .oven,
            .dishwasher,
            .fireplace,
            .television,
            .stairs,
        ]
    }
    
    public static var spicalObjectCases: [CapturedRoom.Object.Category] {
        [
            .bed,
            .table,
            .sofa,
            .chair,
        ]
    }

    public var detail: String {
        "\(self)"
    }

}
