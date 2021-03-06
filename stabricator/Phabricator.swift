//
//  Phabricator.swift
//  weatherbar
//
//  Created by Dan Hill on 10/10/17.
//  Copyright © 2017 Dan Hill. All rights reserved.
//

import Foundation

class Phabricator {

    let API_URL: URL
    let API_TOKEN: String
    let PATH_DIFFS_SEARCH = "differential.revision.search"
    let PATH_USER_SELF = "user.whoami"
    let errorHandler: (Error) -> Void
    let jsonDecoder = JSONDecoder()

    init(phabricatorUrl: String, apiToken: String, errorHandler: @escaping (Error) -> Void) {
        self.API_URL = URL(string: phabricatorUrl)!
        self.API_TOKEN = apiToken
        self.errorHandler = errorHandler
    }
    
    func getDiffWebUrl(diff: Diff) -> URL {
        return getDiffWebUrl(diffId: diff.id)
    }
    
    func getDiffWebUrl(diffId: Int) -> URL {
        return API_URL.deletingLastPathComponent()
            .appendingPathComponent("D\(diffId)")
    }

    func fetchUser(success: @escaping (Response<User>) -> Void) {
        var request = getRequest(url: API_URL.appendingPathComponent(PATH_USER_SELF))
        request.httpBody = "api.token=\(API_TOKEN)".data(using: .utf8)
        execute(request: request, type: Response<User>.self, success: success)
    }

    func fetchActiveDiffs(success: @escaping (DiffArrayResponse) -> Void) {
        var request = getRequest(url: API_URL.appendingPathComponent(PATH_DIFFS_SEARCH))
        request.httpBody = "api.token=\(API_TOKEN)&queryKey=active&attachments[reviewers]=true".data(using: .utf8)
        execute(request: request, type: DiffArrayResponse.self, success: success)
    }
    
    func getRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        return request
    }
    
    func execute<T: Decodable>(request: URLRequest, type: T.Type, success: @escaping (T) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, response, err in

            // first check for a hard error
            if let error = err {
                print("Phabricator api error: \(error)")
                DispatchQueue.main.async() {
                    self.errorHandler(error)
                }
            }
            
            // then check the response code
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {

                case 200:
                    if let dataString = String(data: data!, encoding: .utf8) {
                        if let response = self.parseJsonResponse(jsonString: dataString, type: type) {
                            DispatchQueue.main.async() {
                                success(response)
                            }
                        }
                    }

                default:
                    print("Phabricator api returned response: %d %@", httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                }
            }
        }
        task.resume()
    }
    
    func parseJsonResponse<T: Decodable>(jsonString: String, type: T.Type) -> T? {
        let jsonData = jsonString.data(using: .utf8)!
        return try! jsonDecoder.decode(type, from: jsonData)
    }
}
