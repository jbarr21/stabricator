//
//  Models.swift
//  stabricator
//
//  Created by Dan Hill on 10/14/17.
//  Copyright © 2017 Dan Hill. All rights reserved.
//

import Foundation

typealias ProjectArrayResponse = Response<ListResult<Project>>
typealias DiffArrayResponse = Response<ListResult<Diff>>
typealias DiffStatusArrayResponse = ListResponse<DiffStatus>
typealias ReviewerMapResponse = MapResponse<UberReviewer>

struct Response<T: Codable> : Codable {
    var result: T
    let error_code: String?
    let error_info: String?
}

struct ListResponse<T: Codable> : Codable {
    let result: [T]
    let error_code: String?
    let error_info: String?
}

struct MapResponse<T: Codable> : Codable {
    let result: [String : [T]]
    let error_code: String?
    let error_info: String?
}

struct ListResult<T: Codable> : Codable {
    var data: [T]
}

struct Project : Codable {
    let id: Int
    let phid: String
    let fields: ProjectFields
}

struct ProjectFields : Codable {
    let name: String
}

struct Diff : Codable {
    let id: Int
    let phid: String
    let fields: Fields
    let attachments: Attachments?
    var uberReviewers: [UberReviewer]?
    var uberStatus: String?
    
    func isActionable(userPhid: String, projects: ProjectMap) -> Bool {
        let selfAuthored = isAuthoredBy(userPhid)
        let acceptedByUser = isAcceptedBy(userPhid, projects)
        switch self.status() {
        case Status.NEEDS_REVIEW:
            return !selfAuthored && !acceptedByUser
        case Status.NEEDS_REVISION:
            return selfAuthored
        case Status.ACCEPTED:
            return selfAuthored
        case Status.CHANGES_PLANNED:
            return selfAuthored
        case Status.DRAFT:
            return false
        default:
            return false
        }
    }
    
    func isStatus(_ statuses: String...) -> Bool {
        for status in statuses {
            if (status == self.status()) {
                return true
            }
        }
        return false
    }
    
    func isAuthoredBy(_ userPhid: String) -> Bool {
        return fields.authorPHID == userPhid
    }
    
    func isBlockingReviewer(_ userPhid: String, _ projects: ProjectMap) -> Bool {
        return (diffReviewer(userPhid)?.isBlocker() ?? false)
                || projects.projects.keys.contains { projectPhid in diffReviewer(projectPhid)?.isBlocker() ?? false }
    }
    
    func isAcceptedBy(_ userPhid: String, _ projects: ProjectMap) -> Bool {
        return diffReviewer(userPhid)?.hasAccepted()
                ?? projects.projects.keys.contains { projectPhid in diffReviewer(projectPhid)?.hasAccepted() ?? false }
    }

    func status() -> String {
        return fields.status?.value ?? uberStatus?.lowercased().replacingOccurrences(of: " ", with: "-") ?? "error"
    }

    func diffReviewer(_ userPhid: String) -> DiffReviewer? {
        let diffReviewers: [DiffReviewer]? = attachments?.reviewers?.reviewers ?? uberReviewers
        return diffReviewers?.first { reviewer in reviewer.reviewerPHID == userPhid }
    }
}

struct DiffStatus : Codable {
    let id: String
    let phid: String
    let statusName: String
    let status: String
}

struct Fields : Codable {
    let title: String
    let authorPHID: String
    let status: Status? = nil
    let dateCreated: Date
    let dateModified: Date
}

struct Status : Codable {
    static let NEEDS_REVIEW = "needs-review"
    static let NEEDS_REVISION = "needs-revision"
    static let ACCEPTED = "accepted"
    static let CHANGES_PLANNED = "changes-planned"
    static let DRAFT = "draft"
    
    let value: String
    let name: String
    let closed: Bool
}

struct Attachments : Codable {
    let reviewers: Reviewers?
}

struct Reviewers : Codable {
    let reviewers: [Reviewer]
}

struct Reviewer : Codable, DiffReviewer {
    let reviewerPHID: String
    // added, accepted, or rejected
    let status: String
    let isBlocking: Bool
    let actorPHID: String?

    func isBlocker() -> Bool {
        return isBlocking
    }

    func hasAccepted() -> Bool {
        return status == "accepted"
    }
}

struct UberReviewer : Codable, DiffReviewer {
    let reviewerPHID: String
    let userName: String
    // added, accepted, commented, blocking, rejected, rejected-older
    let status: String

    func isBlocker() -> Bool {
        return status == "blocking" || status == "rejected" || status == "rejected-older"
    }

    func hasAccepted() -> Bool {
        return status == "accepted"
    }
}

struct ProjectMap: Codable {
    let projects: [String: Project]
}

struct User: Codable {
    let phid: String
    let userName: String
    let realName: String
    let image: String
    let uri: String
    let primaryEmail: String
}

protocol DiffReviewer {
    var reviewerPHID: String { get }
    func isBlocker() -> Bool
    func hasAccepted() -> Bool
}
