import Foundation

protocol CatalogImporting: Sendable {
  func importCatalog(from url: URL) async throws -> [ImportedCatalogItem]
}

enum CatalogImportError: LocalizedError {
  case invalidResponse
  case noCatalogItems

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "The storefront page could not be imported."
    case .noCatalogItems:
      "No clothing items were detected on that page. Try a product or category URL."
    }
  }
}

struct HTMLCatalogImporter: CatalogImporting {
  private let httpClient: any HTTPClient
  private let parser: HTMLCatalogParser

  init(httpClient: any HTTPClient, parser: HTMLCatalogParser = HTMLCatalogParser()) {
    self.httpClient = httpClient
    self.parser = parser
  }

  func importCatalog(from url: URL) async throws -> [ImportedCatalogItem] {
    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
      forHTTPHeaderField: "User-Agent"
    )
    let (data, response) = try await httpClient.data(for: request)
    guard let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
      throw CatalogImportError.invalidResponse
    }
    let html = String(decoding: data, as: UTF8.self)
    let items = parser.parse(html: html, sourceURL: url)
    guard !items.isEmpty else {
      throw CatalogImportError.noCatalogItems
    }
    return Array(items.prefix(24))
  }
}

struct HTMLCatalogParser: Sendable {
  func parse(html: String, sourceURL: URL) -> [ImportedCatalogItem] {
    let jsonLDItems = parseJSONLDBlocks(in: html, sourceURL: sourceURL)
    let anchorItems = parseAnchorCandidates(in: html, sourceURL: sourceURL)
    let metaItems = parseMetaFallback(in: html, sourceURL: sourceURL)

    let combined = jsonLDItems + anchorItems + metaItems
    var deduped: [String: ImportedCatalogItem] = [:]
    for item in combined {
      let key = "\(item.sourceURL.absoluteString)|\(item.title.lowercased())"
      deduped[key] = item
    }
    return deduped.values.sorted { $0.title < $1.title }
  }

  private func parseJSONLDBlocks(in html: String, sourceURL: URL) -> [ImportedCatalogItem] {
    matches(
      pattern: #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#,
      in: html
    )
    .compactMap { block -> Any? in
      guard let data = block.body.decodingHTMLEntities.data(using: .utf8) else {
        return nil
      }
      return try? JSONSerialization.jsonObject(with: data)
    }
    .flatMap { products(from: $0, sourceURL: sourceURL) }
  }

  private func products(from json: Any, sourceURL: URL) -> [ImportedCatalogItem] {
    switch json {
    case let dictionary as [String: Any]:
      if let graph = dictionary["@graph"] {
        return products(from: graph, sourceURL: sourceURL)
      }
      if let itemList = dictionary["itemListElement"] {
        return products(from: itemList, sourceURL: sourceURL)
      }
      if let item = dictionary["item"] {
        return products(from: item, sourceURL: sourceURL)
      }
      if isProduct(dictionary) {
        return product(from: dictionary, sourceURL: sourceURL).map { [$0] } ?? []
      }
      return dictionary.values.flatMap { products(from: $0, sourceURL: sourceURL) }
    case let array as [Any]:
      return array.flatMap { products(from: $0, sourceURL: sourceURL) }
    default:
      return []
    }
  }

  private func isProduct(_ dictionary: [String: Any]) -> Bool {
    let rawType = dictionary["@type"]
    if let type = rawType as? String {
      return type.lowercased().contains("product")
    }
    if let types = rawType as? [String] {
      return types.contains { $0.lowercased().contains("product") }
    }
    return false
  }

  private func product(from dictionary: [String: Any], sourceURL: URL) -> ImportedCatalogItem? {
    guard let title = cleanText(dictionary["name"] as? String ?? dictionary["title"] as? String),
      title.count > 2
    else {
      return nil
    }
    let brand: String = {
      if let brand = dictionary["brand"] as? String {
        return cleanText(brand) ?? sourceURL.hostDisplayName
      }
      if let brand = dictionary["brand"] as? [String: Any], let brandName = brand["name"] as? String
      {
        return cleanText(brandName) ?? sourceURL.hostDisplayName
      }
      return sourceURL.hostDisplayName
    }()
    let imageURL = resolveURL(
      candidate: firstString(from: dictionary["image"]), relativeTo: sourceURL)
    let canonicalURL =
      resolveURL(
        candidate: dictionary["url"] as? String
          ?? offerValue(from: dictionary["offers"], key: "url"),
        relativeTo: sourceURL
      ) ?? sourceURL
    let category = cleanText(dictionary["category"] as? String)
    let notes = cleanText(dictionary["description"] as? String)
    let priceText = priceText(from: dictionary["offers"])
    return ImportedCatalogItem(
      title: title,
      brand: brand,
      priceText: priceText,
      categoryHint: category,
      imageURL: imageURL,
      sourceURL: canonicalURL,
      notes: notes
    )
  }

  private func parseMetaFallback(in html: String, sourceURL: URL) -> [ImportedCatalogItem] {
    guard
      let title = metaValue(property: "og:title", in: html)
        ?? metaValue(property: "twitter:title", in: html)
        ?? cleanText(firstMatch(pattern: #"<title>(.*?)</title>"#, in: html))
    else {
      return []
    }
    let imageURL = resolveURL(
      candidate: metaValue(property: "og:image", in: html)
        ?? metaValue(property: "twitter:image", in: html),
      relativeTo: sourceURL
    )
    let priceAmount = metaValue(property: "product:price:amount", in: html)
    let currency = metaValue(property: "product:price:currency", in: html)
    let priceText = formattedPrice(amount: priceAmount, currency: currency)
    return [
      ImportedCatalogItem(
        title: title,
        brand: sourceURL.hostDisplayName,
        priceText: priceText,
        categoryHint: nil,
        imageURL: imageURL,
        sourceURL: sourceURL,
        notes: nil
      )
    ]
  }

  private func parseAnchorCandidates(in html: String, sourceURL: URL) -> [ImportedCatalogItem] {
    matches(pattern: #"<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#, in: html)
      .compactMap { block -> ImportedCatalogItem? in
        let groups = captureGroups(
          pattern: #"<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#,
          in: block.fullMatch
        )
        guard groups.count >= 2 else {
          return nil
        }
        let href = groups[0]
        let body = groups[1]
        guard let resolvedURL = resolveURL(candidate: href, relativeTo: sourceURL) else {
          return nil
        }
        let title = cleanText(
          firstAttribute(named: "aria-label", in: block.fullMatch)
            ?? firstAttribute(named: "title", in: block.fullMatch)
            ?? firstAttribute(named: "alt", in: body)
            ?? stripHTML(body)
        )
        guard let title, title.count > 3 else {
          return nil
        }
        let priceText = firstMatch(pattern: #"\$[0-9][0-9,]*(?:\.[0-9]{2})?"#, in: body)
        guard priceText != nil || looksLikeCatalogLink(resolvedURL: resolvedURL) else {
          return nil
        }
        let imageURL = resolveURL(
          candidate: firstAttribute(named: "src", in: body), relativeTo: sourceURL)
        return ImportedCatalogItem(
          title: title,
          brand: sourceURL.hostDisplayName,
          priceText: priceText,
          categoryHint: nil,
          imageURL: imageURL,
          sourceURL: resolvedURL,
          notes: nil
        )
      }
  }

  private func looksLikeCatalogLink(resolvedURL: URL) -> Bool {
    let value = resolvedURL.absoluteString.lowercased()
    return value.contains("product")
      || value.contains("/p/")
      || value.contains("pid=")
      || value.contains("sku")
  }

  private func metaValue(property: String, in html: String) -> String? {
    let patterns = [
      #"<meta[^>]*(?:property|name)=["']\#(property)["'][^>]*content=["'](.*?)["'][^>]*>"#,
      #"<meta[^>]*content=["'](.*?)["'][^>]*(?:property|name)=["']\#(property)["'][^>]*>"#,
    ]
    for pattern in patterns {
      if let value = captureGroups(pattern: pattern, in: html).first {
        return cleanText(value)
      }
    }
    return nil
  }

  private func priceText(from offers: Any?) -> String? {
    guard let offers else {
      return nil
    }
    if let dictionary = offers as? [String: Any] {
      let amount = dictionary["price"] as? String ?? (dictionary["price"] as? NSNumber)?.stringValue
      let currency = dictionary["priceCurrency"] as? String
      return formattedPrice(amount: amount, currency: currency)
    }
    if let array = offers as? [[String: Any]] {
      for offer in array {
        if let price = priceText(from: offer) {
          return price
        }
      }
    }
    return nil
  }

  private func offerValue(from offers: Any?, key: String) -> String? {
    if let dictionary = offers as? [String: Any] {
      return dictionary[key] as? String
    }
    if let array = offers as? [[String: Any]] {
      return array.compactMap { $0[key] as? String }.first
    }
    return nil
  }

  private func formattedPrice(amount: String?, currency: String?) -> String? {
    guard let amount else {
      return nil
    }
    if let value = Double(amount) {
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.currencyCode = currency ?? "USD"
      return formatter.string(from: NSNumber(value: value))
    }
    if amount.hasPrefix("$") {
      return amount
    }
    return currency.map { "\($0) \(amount)" } ?? amount
  }

  private func firstString(from value: Any?) -> String? {
    if let string = value as? String {
      return string
    }
    if let array = value as? [String] {
      return array.first
    }
    return nil
  }

  private func resolveURL(candidate: String?, relativeTo sourceURL: URL) -> URL? {
    guard let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
      !candidate.isEmpty
    else {
      return nil
    }
    if let absolute = URL(string: candidate), absolute.scheme != nil {
      return absolute
    }
    return URL(string: candidate, relativeTo: sourceURL)?.absoluteURL
  }

  private func cleanText(_ value: String?) -> String? {
    guard let value else {
      return nil
    }
    let cleaned = value
      .decodingHTMLEntities
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
  }

  private func stripHTML(_ value: String) -> String {
    value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
  }

  private func firstAttribute(named name: String, in text: String) -> String? {
    let pattern = #"\#(name)=["'](.*?)["']"#
    return captureGroups(pattern: pattern, in: text).first
  }

  private func firstMatch(pattern: String, in text: String) -> String? {
    captureGroups(pattern: pattern, in: text).first
  }

  private func matches(pattern: String, in text: String) -> [(fullMatch: String, body: String)] {
    guard
      let regex = try? NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    else {
      return []
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, options: [], range: range).compactMap { match in
      guard let fullRange = Range(match.range(at: 0), in: text) else {
        return nil
      }
      let bodyRange = match.numberOfRanges > 1 ? Range(match.range(at: 1), in: text) : nil
      return (
        fullMatch: String(text[fullRange]),
        body: bodyRange.map { String(text[$0]) } ?? String(text[fullRange])
      )
    }
  }

  private func captureGroups(pattern: String, in text: String) -> [String] {
    guard
      let regex = try? NSRegularExpression(
        pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    else {
      return []
    }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range) else {
      return []
    }
    return (1..<match.numberOfRanges).compactMap { index in
      guard let groupRange = Range(match.range(at: index), in: text) else {
        return nil
      }
      return String(text[groupRange])
    }
  }
}

extension String {
  fileprivate var decodingHTMLEntities: String {
    replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
      .replacingOccurrences(of: "&nbsp;", with: " ")
  }
}
