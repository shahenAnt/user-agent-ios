/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

import Shared

private func migrate(urls: [URL]) -> [URL] {
    return urls.compactMap { url in
        var url = url
        let port = AppInfo.webserverPort
        [("http://localhost:\(port)/errors/error.html?url=", "\(InternalURL.baseUrl)/\(SessionRestoreHandler.path)?url=")
            // TO DO : handle reader pages ("http://localhost:6571/reader-mode/page?url=", "\(InternalScheme.url)/\(ReaderModeHandler.path)?url=")
            ].forEach {
            oldItem, newItem in
            if url.absoluteString.hasPrefix(oldItem) {
                var urlStr = url.absoluteString.replacingOccurrences(of: oldItem, with: newItem)
                let comp = urlStr.components(separatedBy: newItem)
                if comp.count > 2 {
                    // get the last instance of incorrectly nested urls
                    urlStr = newItem + (comp.last ?? "")
                    assertionFailure("SessionData urls have nested internal links, investigate: [\(url.absoluteString)]")
                }
                url = URL(string: urlStr) ?? url
            }
        }

        if let internalUrl = InternalURL(url), internalUrl.isAuthorized, let stripped = URL(string: internalUrl.stripAuthorization) {
            return stripped
        }

        return url
    }
}

class SessionData: NSObject, NSCoding {
    let currentPage: Int
    let urls: [URL]
    let lastUsedTime: Timestamp

    var jsonDictionary: [String: Any] {
        return [
            "currentPage": String(self.currentPage),
            "lastUsedTime": String(self.lastUsedTime),
            "urls": urls.map { $0.absoluteString },
        ]
    }

    /**
        Creates a new SessionData object representing a serialized tab.

        - parameter currentPage:     The active page index. Must be in the range of (-N, 0],
                                where 1-N is the first page in history, and 0 is the last.
        - parameter urls:            The sequence of URLs in this tab's session history.
        - parameter lastUsedTime:    The last time this tab was modified.
    **/
    init(currentPage: Int, urls: [URL], lastUsedTime: Timestamp) {
        self.currentPage = currentPage
        self.urls = migrate(urls: urls)
        self.lastUsedTime = lastUsedTime

        assert(!urls.isEmpty, "Session has at least one entry")
        assert(currentPage > -urls.count && currentPage <= 0, "Session index is valid")
    }

    required init?(coder: NSCoder) {
        self.currentPage = coder.decodeAsInt(forKey: "currentPage")
        self.urls = migrate(urls: coder.decodeObject(forKey: "urls") as? [URL] ?? [URL]())
        self.lastUsedTime = coder.decodeAsUInt64(forKey: "lastUsedTime")
    }

    func encode(with coder: NSCoder) {
        coder.encode(currentPage, forKey: "currentPage")
        coder.encode(migrate(urls: urls), forKey: "urls")
        coder.encode(Int64(lastUsedTime), forKey: "lastUsedTime")
    }
}
