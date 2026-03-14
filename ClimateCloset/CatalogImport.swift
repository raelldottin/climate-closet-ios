import Foundation

protocol CatalogImporting: Sendable {
  func importCatalog(from url: URL) async throws -> [ImportedCatalogItem]
}

enum CatalogImportPageKind: String, Sendable {
  case product
  case category

  var title: String {
    switch self {
    case .product:
      "Product page"
    case .category:
      "Category page"
    }
  }
}

enum CatalogImportReadiness: Equatable, Sendable {
  case empty
  case invalidURL
  case unsupportedScheme
  case nonWardrobeSource(host: String)
  case needsCatalogPage(host: String)
  case ready(kind: CatalogImportPageKind, host: String)

  var canImport: Bool {
    if case .ready = self {
      return true
    }
    return false
  }

  var title: String {
    switch self {
    case .empty:
      "Paste a source"
    case .invalidURL:
      "Invalid URL"
    case .unsupportedScheme:
      "Use a web URL"
    case .nonWardrobeSource:
      "Not a wardrobe source"
    case .needsCatalogPage:
      "Needs a product or category page"
    case .ready(let kind, _):
      kind.title
    }
  }

  var message: String {
    return switch self {
    case .empty:
      "Product pages are safest. Category pages work when they expose real product cards."
    case .invalidURL:
      "Enter a full web URL before importing."
    case .unsupportedScheme:
      "Use an http or https URL."
    case .nonWardrobeSource(let host):
      "\(host) looks like a beauty or non-apparel storefront. Paste a clothing page instead."
    case .needsCatalogPage(let host):
      "The link points to a general \(host) landing page. Paste a specific product or category URL."
    case .ready(let kind, let host):
      kind == .product
        ? "\(host) looks import-ready for a single wardrobe piece."
        : "\(host) looks import-ready for a multi-item wardrobe pull."
    }
  }

  var symbolName: String {
    return switch self {
    case .empty:
      "tray"
    case .invalidURL, .unsupportedScheme, .nonWardrobeSource:
      "exclamationmark.triangle"
    case .needsCatalogPage:
      "arrow.trianglehead.branch"
    case .ready(let kind, _):
      kind == .product ? "checkmark.seal" : "square.grid.2x2"
    }
  }
}

enum CatalogImportError: LocalizedError {
  case invalidResponse
  case unsupportedSource(String)
  case needsCatalogPage
  case noCatalogItems

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "The page could not be read right now."
    case .unsupportedSource(let host):
      "\(host) did not resolve to a wardrobe-friendly catalog."
    case .needsCatalogPage:
      "Use a clothing product or category page instead of a general brand homepage."
    case .noCatalogItems:
      "No wardrobe-ready items were detected on that page."
    }
  }
}

struct CatalogImportURLClassifier: Sendable {
  private let homeTokens: Set<String> = [
    "", "home", "homepage", "index", "index.html", "default", "default.aspx",
  ]
  private let blockedPathTokens = [
    "about", "accessibility", "account", "bag", "beauty", "blog", "brand", "brands", "campaign",
    "careers", "cart", "checkout", "contact", "faq", "find-a-store", "gift", "gift-card", "help",
    "journal", "login", "lookbook", "magazine", "news", "policy", "press", "privacy", "search",
    "sign-in", "signin", "stores", "story", "support", "terms",
  ]
  private let productPathTokens = [
    "/p/", "/product", "/products", "pid=", "product.do", "sku", "style=", "item=",
  ]
  private let categoryTokens = [
    "accessories", "apparel", "bottoms", "browse", "category", "clothing", "coats",
    "collections", "denim", "dresses", "jackets", "jeans", "knitwear", "men", "new-arrivals",
    "outerwear", "pants", "polos", "sale", "shirts", "shoes", "shop", "shorts", "skirts",
    "suiting", "sweaters", "tops", "women",
  ]
  private let nonWardrobeHostTokens = [
    "beauty", "cosmetic", "cosmetics", "fragrance", "makeup", "skin",
  ]

  func classify(text: String) -> CatalogImportReadiness {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return .empty
    }
    guard let url = URL(string: trimmed), url.host != nil else {
      return .invalidURL
    }
    return classify(url: url)
  }

  func classify(url: URL) -> CatalogImportReadiness {
    guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
      return .unsupportedScheme
    }

    let host = url.hostDisplayName
    let loweredHost = url.host?.lowercased() ?? ""
    if nonWardrobeHostTokens.contains(where: loweredHost.contains) {
      return .nonWardrobeSource(host: host)
    }

    let pathComponents = url.pathComponents
      .filter { !$0.isEmpty && $0 != "/" }
      .map { $0.lowercased() }
    let path = url.path.lowercased()
    let queryKeys = queryItemKeys(for: url)
    let lastComponent = pathComponents.last ?? ""

    if pathComponents.isEmpty || homeTokens.contains(lastComponent) {
      return .needsCatalogPage(host: host)
    }

    let hasBlockedPath = blockedPathTokens.contains(where: { token in
      pathComponents.contains(token) || path.contains("/\(token)") || queryKeys.contains(token)
    })
    if hasBlockedPath && !hasProductSignal(url: url, path: path, queryKeys: queryKeys) {
      return .needsCatalogPage(host: host)
    }

    if hasProductSignal(url: url, path: path, queryKeys: queryKeys) {
      return .ready(kind: .product, host: host)
    }

    if hasCategorySignal(pathComponents: pathComponents, queryKeys: queryKeys) {
      return .ready(kind: .category, host: host)
    }

    return .needsCatalogPage(host: host)
  }

  private func hasProductSignal(url: URL, path: String, queryKeys: Set<String>) -> Bool {
    if productPathTokens.contains(where: path.contains) {
      return true
    }

    if queryKeys.contains("pid") || queryKeys.contains("sku") || queryKeys.contains("style") {
      return true
    }

    let lastComponent = url.pathComponents.last?.lowercased() ?? ""
    if lastComponent.hasSuffix(".html") || lastComponent.contains(".htm") {
      return true
    }

    return false
  }

  private func hasCategorySignal(pathComponents: [String], queryKeys: Set<String>) -> Bool {
    if queryKeys.contains("cid") || queryKeys.contains("category") || queryKeys.contains("dept") {
      return true
    }

    if pathComponents.contains("browse") || pathComponents.contains("collections") {
      return true
    }

    if categoryTokens.contains(where: pathComponents.contains) {
      return true
    }

    return pathComponents.count >= 2
  }

  private func queryItemKeys(for url: URL) -> Set<String> {
    Set(
      URLComponents(url: url, resolvingAgainstBaseURL: true)?
        .queryItems?
        .map { $0.name.lowercased() } ?? []
    )
  }
}

struct CatalogWearabilityFilter: Sendable {
  private let wardrobeTokens = [
    "accessory", "ankle boot", "bag", "ballet", "beanie", "belt", "blazer", "blouse", "boot",
    "briefcase", "button-down", "button up", "cap", "cardigan", "coat", "crewneck", "denim",
    "dress", "eyewear", "frames", "glove", "hat", "heel", "hoodie", "jacket", "jean", "jumper",
    "knit", "loafer", "moccasin", "outerwear", "oxford", "pant", "parka", "polo", "pullover",
    "robe", "sandal", "scarf", "shirt", "shoe", "short", "skirt", "slipper", "sneaker",
    "sock", "suit", "sunglass", "sweater", "sweatshirt", "tee", "top", "tote", "trouser",
    "vest", "wallet", "watch",
  ]
  private let nonWardrobeTokens = [
    "aftershave", "blush", "body spray", "brow", "brush", "candle", "cleanser", "cologne",
    "concealer", "cosmetic", "eau de parfum", "eau de toilette", "eyeliner", "eyeshadow",
    "foundation", "fragrance", "gel eyeliner", "highlighter", "lip", "lipstick", "liner",
    "makeup", "mascara", "moisturizer", "nail", "palette", "parfum", "powder", "primer",
    "serum", "shampoo", "skin", "skincare", "soap", "spray",
  ]

  func isWearable(_ item: ImportedCatalogItem) -> Bool {
    let haystack = [
      item.title, item.categoryHint ?? "", item.notes ?? "", item.sourceURL.path,
    ]
    .joined(separator: " ")
    .lowercased()

    if nonWardrobeTokens.contains(where: haystack.contains) {
      return false
    }

    if looksLikeStorefrontTitle(item.title) {
      return false
    }

    if wardrobeTokens.contains(where: haystack.contains) {
      return true
    }

    return item.priceText != nil && item.imageURL != nil
  }

  private func looksLikeStorefrontTitle(_ title: String) -> Bool {
    let lowered = title.lowercased()
    return lowered.contains("online store")
      || lowered.contains("official site")
      || lowered.contains("new arrivals")
      || lowered.contains("shop now")
  }
}

struct HTMLCatalogImporter: CatalogImporting {
  private let httpClient: any HTTPClient
  private let parser: HTMLCatalogParser
  private let classifier = CatalogImportURLClassifier()

  init(httpClient: any HTTPClient, parser: HTMLCatalogParser = HTMLCatalogParser()) {
    self.httpClient = httpClient
    self.parser = parser
  }

  func importCatalog(from url: URL) async throws -> [ImportedCatalogItem] {
    switch classifier.classify(url: url) {
    case .ready:
      break
    case .nonWardrobeSource(let host):
      throw CatalogImportError.unsupportedSource(host)
    case .needsCatalogPage:
      throw CatalogImportError.needsCatalogPage
    case .unsupportedScheme, .invalidURL, .empty:
      throw CatalogImportError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
    request.setValue(
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
      forHTTPHeaderField: "User-Agent"
    )

    let (data, response) = try await httpClient.data(for: request)
    guard let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
      throw CatalogImportError.invalidResponse
    }

    let finalURL = response.url ?? url
    switch classifier.classify(url: finalURL) {
    case .ready:
      break
    case .nonWardrobeSource(let host):
      throw CatalogImportError.unsupportedSource(host)
    case .needsCatalogPage:
      throw CatalogImportError.needsCatalogPage
    case .unsupportedScheme, .invalidURL, .empty:
      throw CatalogImportError.invalidResponse
    }

    guard isLikelyHTML(response: response, data: data) else {
      throw CatalogImportError.invalidResponse
    }

    let html = decodeHTML(from: data)
    let items = parser.parse(html: html, sourceURL: finalURL)
    guard !items.isEmpty else {
      throw CatalogImportError.noCatalogItems
    }
    return Array(items.prefix(24))
  }

  private func isLikelyHTML(response: HTTPURLResponse, data: Data) -> Bool {
    if let mimeType = response.mimeType?.lowercased(), mimeType.contains("html") {
      return true
    }

    let prefix = String(decoding: data.prefix(128), as: UTF8.self).lowercased()
    return prefix.contains("<!doctype html") || prefix.contains("<html")
  }

  private func decodeHTML(from data: Data) -> String {
    let encodings: [String.Encoding] = [.utf8, .unicode, .windowsCP1252, .isoLatin1]
    for encoding in encodings {
      if let value = String(data: data, encoding: encoding), !value.isEmpty {
        return value
      }
    }
    return String(decoding: data, as: UTF8.self)
  }
}

struct HTMLCatalogParser: Sendable {
  private let classifier = CatalogImportURLClassifier()
  private let wearabilityFilter = CatalogWearabilityFilter()

  func parse(html: String, sourceURL: URL) -> [ImportedCatalogItem] {
    let pageMetadata = metadata(in: html, sourceURL: sourceURL)
    let pageReadiness = classifier.classify(url: sourceURL)

    let structuredItems = parseJSONLDBlocks(in: html, sourceURL: sourceURL)
    let anchorItems = parseAnchorCandidates(in: html, sourceURL: sourceURL)
    let metaItems = parseMetaFallback(
      in: html,
      sourceURL: pageMetadata.canonicalURL ?? sourceURL,
      pageMetadata: pageMetadata,
      pageReadiness: pageReadiness
    )

    let combined = (structuredItems + anchorItems + metaItems)
      .filter { wearabilityFilter.isWearable($0) }

    var deduped: [String: ImportedCatalogItem] = [:]
    for item in combined {
      let key = "\(item.sourceURL.normalizedCatalogKey)|\(normalizedTitle(item.title))"
      guard let existing = deduped[key] else {
        deduped[key] = item
        continue
      }

      if shouldPrefer(item, over: existing) {
        deduped[key] = item
      }
    }

    return deduped.values.sorted { lhs, rhs in
      if lhs.confidence != rhs.confidence {
        return lhs.confidence > rhs.confidence
      }

      let lhsCompleteness = completenessScore(lhs)
      let rhsCompleteness = completenessScore(rhs)
      if lhsCompleteness != rhsCompleteness {
        return lhsCompleteness > rhsCompleteness
      }

      return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
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
      candidate: firstString(from: dictionary["image"]),
      relativeTo: sourceURL
    )
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
      notes: notes,
      confidence: .verified
    )
  }

  private func parseMetaFallback(
    in html: String,
    sourceURL: URL,
    pageMetadata: PageMetadata,
    pageReadiness: CatalogImportReadiness
  ) -> [ImportedCatalogItem] {
    let isLikelyProductPage: Bool = {
      if case .ready(let kind, _) = pageReadiness, kind == .product {
        return true
      }

      if let ogType = pageMetadata.ogType?.lowercased(), ogType.contains("product") {
        return true
      }

      return pageMetadata.priceAmount != nil
    }()

    guard isLikelyProductPage, let title = pageMetadata.title, !looksLikeStorefrontTitle(title)
    else {
      return []
    }

    let imageURL = resolveURL(candidate: pageMetadata.imageURL, relativeTo: sourceURL)
    let priceText = formattedPrice(
      amount: pageMetadata.priceAmount,
      currency: pageMetadata.priceCurrency
    )

    return [
      ImportedCatalogItem(
        title: title,
        brand: sourceURL.hostDisplayName,
        priceText: priceText,
        categoryHint: nil,
        imageURL: imageURL,
        sourceURL: sourceURL,
        notes: pageMetadata.description,
        confidence: .fallback
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
        guard let resolvedURL = resolveURL(candidate: href, relativeTo: sourceURL),
          sameCatalogHost(resolvedURL, sourceURL)
        else {
          return nil
        }

        let title = cleanText(
          firstAttribute(named: "aria-label", in: block.fullMatch)
            ?? firstAttribute(named: "title", in: block.fullMatch)
            ?? firstAttribute(named: "alt", in: body)
            ?? stripHTML(body)
        )
        guard let title, title.count > 3, !looksLikeNavigationTitle(title) else {
          return nil
        }

        let priceText = firstMatch(pattern: #"\$[0-9][0-9,]*(?:\.[0-9]{2})?"#, in: body)
        guard priceText != nil || looksLikeCatalogLink(resolvedURL: resolvedURL) else {
          return nil
        }

        let imageURL = resolveURL(candidate: imageCandidate(in: body), relativeTo: sourceURL)

        return ImportedCatalogItem(
          title: title,
          brand: sourceURL.hostDisplayName,
          priceText: priceText,
          categoryHint: nil,
          imageURL: imageURL,
          sourceURL: resolvedURL,
          notes: nil,
          confidence: imageURL != nil || priceText != nil ? .likely : .fallback
        )
      }
  }

  private func looksLikeCatalogLink(resolvedURL: URL) -> Bool {
    if case .ready(let kind, _) = classifier.classify(url: resolvedURL) {
      return kind == .product
    }
    return false
  }

  private func metadata(in html: String, sourceURL: URL) -> PageMetadata {
    PageMetadata(
      title:
        metaValue(property: "og:title", in: html)
        ?? metaValue(property: "twitter:title", in: html)
        ?? cleanText(firstMatch(pattern: #"<title>(.*?)</title>"#, in: html)),
      ogType: metaValue(property: "og:type", in: html),
      imageURL:
        metaValue(property: "og:image", in: html)
        ?? metaValue(property: "twitter:image", in: html),
      canonicalURL: resolveURL(
        candidate:
          firstMatch(
            pattern: #"<link[^>]*rel=["']canonical["'][^>]*href=["'](.*?)["'][^>]*>"#,
            in: html
          )
          ?? firstMatch(
            pattern: #"<link[^>]*href=["'](.*?)["'][^>]*rel=["']canonical["'][^>]*>"#,
            in: html
          ),
        relativeTo: sourceURL
      ),
      description:
        metaValue(property: "og:description", in: html)
        ?? metaValue(property: "description", in: html),
      priceAmount: metaValue(property: "product:price:amount", in: html),
      priceCurrency: metaValue(property: "product:price:currency", in: html)
    )
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
    if let dictionary = value as? [String: Any] {
      return dictionary["url"] as? String ?? dictionary["contentUrl"] as? String
    }
    if let array = value as? [[String: Any]] {
      return array.compactMap { firstString(from: $0) }.first
    }
    return nil
  }

  private func resolveURL(candidate: String?, relativeTo sourceURL: URL) -> URL? {
    guard let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
      !candidate.isEmpty
    else {
      return nil
    }

    let resolvedURL: URL?
    if let absolute = URL(string: candidate), absolute.scheme != nil {
      resolvedURL = absolute
    } else {
      resolvedURL = URL(string: candidate, relativeTo: sourceURL)?.absoluteURL
    }

    guard
      var components = resolvedURL.flatMap({
        URLComponents(url: $0, resolvingAgainstBaseURL: true)
      })
    else {
      return resolvedURL
    }
    components.fragment = nil
    return components.url
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
    return captureGroups(pattern: pattern, in: text).first?.decodingHTMLEntities
  }

  private func firstMatch(pattern: String, in text: String) -> String? {
    captureGroups(pattern: pattern, in: text).first
  }

  private func matches(pattern: String, in text: String) -> [(fullMatch: String, body: String)] {
    guard
      let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
      )
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
        pattern: pattern,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
      )
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

  private func normalizedTitle(_ value: String) -> String {
    value
      .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func completenessScore(_ item: ImportedCatalogItem) -> Int {
    var score = 0
    if item.priceText != nil {
      score += 2
    }
    if item.imageURL != nil {
      score += 2
    }
    if item.notes?.isEmpty == false {
      score += 1
    }
    if item.categoryHint?.isEmpty == false {
      score += 1
    }
    return score
  }

  private func shouldPrefer(_ lhs: ImportedCatalogItem, over rhs: ImportedCatalogItem) -> Bool {
    if lhs.confidence != rhs.confidence {
      return lhs.confidence > rhs.confidence
    }
    return completenessScore(lhs) > completenessScore(rhs)
  }

  private func looksLikeStorefrontTitle(_ title: String) -> Bool {
    let lowered = title.lowercased()
    return lowered.contains("online store")
      || lowered.contains("official store")
      || lowered.contains("new arrivals")
      || lowered.contains("shop now")
  }

  private func looksLikeNavigationTitle(_ title: String) -> Bool {
    let lowered = title.lowercased()
    return lowered == "shop"
      || lowered == "sale"
      || lowered == "details"
      || lowered == "view all"
      || lowered == "new"
      || lowered == "men"
      || lowered == "women"
  }

  private func imageCandidate(in html: String) -> String? {
    if let src = firstAttribute(named: "src", in: html) {
      return src
    }

    if let srcset = firstAttribute(named: "srcset", in: html) {
      let primarySource = srcset.split(separator: ",").first
      let primaryCandidate = primarySource?.split(separator: " ").first.map(String.init)
      return primaryCandidate
    }

    return nil
  }

  private func sameCatalogHost(_ lhs: URL, _ rhs: URL) -> Bool {
    domainRoot(for: lhs.host) == domainRoot(for: rhs.host)
  }

  private func domainRoot(for host: String?) -> String {
    guard let host else {
      return ""
    }

    let parts = host.lowercased().split(separator: ".")
    guard parts.count >= 2 else {
      return host.lowercased()
    }
    return parts.suffix(2).joined(separator: ".")
  }
}

private struct PageMetadata {
  var title: String?
  var ogType: String?
  var imageURL: String?
  var canonicalURL: URL?
  var description: String?
  var priceAmount: String?
  var priceCurrency: String?
}

extension String {
  fileprivate var decodingHTMLEntities: String {
    replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
      .replacingOccurrences(of: "&nbsp;", with: " ")
  }
}
