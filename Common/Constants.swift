//
//  Constants.swift
//  Selektor
//
//  Created by Casey Marshall on 12/5/22.
//

import Foundation

let backgroundId = "org.metastatic.selektor.refresh"
let configIdHeaderKey = "X-Selektor-ID"
#if os(iOS)
let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1"
#else
let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15"
#endif
let lynxUserAgent = "Lynx/2.8.9rel.1 libwww-FM/2.14 SSL-MM/1.4.1 OpenSSL/3.0.7"

enum WatchUpdateOperation: String {
    case update = "update"
    case delete = "delete"
}

enum WatchPayloadKey: String {
    case configId = "configId"
    case configName = "configName"
    case resultString = "resultString"
    case updatedDate = "updatedDate"
    case operation = "operation"
    case index = "index"
}

let emptyHtml = """
<!DOCTYPE html>

<html>
    <head></head>
    <body></body>
</html>
"""


