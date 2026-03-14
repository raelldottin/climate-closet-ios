import Foundation
import XCTest

@testable import ClimateCloset

final class HTMLCatalogParserTests: XCTestCase {
  func testParserReadsJSONLDProduct() {
    let parser = HTMLCatalogParser()
    let html = """
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Product",
              "name": "Relaxed Linen Shirt",
              "brand": { "@type": "Brand", "name": "J.Crew" },
              "category": "shirts",
              "url": "https://www.jcrew.com/p/linen-shirt",
              "image": ["https://cdn.example.com/linen-shirt.jpg"],
              "offers": { "@type": "Offer", "price": "89.50", "priceCurrency": "USD" }
            }
          </script>
        </head>
      </html>
      """

    let items = parser.parse(
      html: html, sourceURL: URL(string: "https://www.jcrew.com/p/linen-shirt")!)

    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items.first?.title, "Relaxed Linen Shirt")
    XCTAssertEqual(items.first?.brand, "J.Crew")
    XCTAssertEqual(items.first?.priceText, "$89.50")
  }

  func testParserFallsBackToMetaTags() {
    let parser = HTMLCatalogParser()
    let html = """
      <html>
        <head>
          <meta property="og:title" content="Classic Trench Coat" />
          <meta property="og:image" content="https://example.com/trench.jpg" />
          <meta property="product:price:amount" content="198.00" />
          <meta property="product:price:currency" content="USD" />
        </head>
      </html>
      """

    let items = parser.parse(
      html: html, sourceURL: URL(string: "https://www2.hm.com/en_us/trench")!)

    XCTAssertEqual(items.first?.title, "Classic Trench Coat")
    XCTAssertEqual(items.first?.priceText, "$198.00")
  }

  func testParserReadsAnchorCatalogCards() {
    let parser = HTMLCatalogParser()
    let html = """
      <html>
        <body>
          <a href="/products/relaxed-denim-jacket">
            <img src="/images/jacket.jpg" alt="Relaxed Denim Jacket" />
            <span>$128.00</span>
          </a>
        </body>
      </html>
      """

    let items = parser.parse(html: html, sourceURL: URL(string: "https://www.levi.com/US/en_US/")!)

    XCTAssertEqual(items.first?.title, "Relaxed Denim Jacket")
    XCTAssertEqual(
      items.first?.sourceURL.absoluteString, "https://www.levi.com/products/relaxed-denim-jacket")
  }

  func testParserIgnoresStorefrontMetaFallbackForHomepages() {
    let parser = HTMLCatalogParser()
    let html = """
      <html>
        <head>
          <title>TOM FORD Online Store</title>
          <meta property="og:title" content="TOM FORD Online Store" />
          <meta property="og:type" content="website" />
          <meta property="og:description" content="Discover the world of TOM FORD." />
        </head>
      </html>
      """

    let items = parser.parse(html: html, sourceURL: URL(string: "https://www.tomford.com")!)

    XCTAssertTrue(items.isEmpty)
  }

  func testClassifierRejectsHomepagesAndAcceptsCategoryURLs() {
    let classifier = CatalogImportURLClassifier()

    XCTAssertEqual(
      classifier.classify(url: URL(string: "https://www.tomford.com")!),
      .needsCatalogPage(host: "TOM FORD")
    )
    XCTAssertEqual(
      classifier.classify(url: URL(string: "https://bananarepublic.gap.com/browse/women/jackets")!),
      .ready(kind: .category, host: "Banana Republic")
    )
  }

  func testWearabilityFilterRejectsBeautyProducts() {
    let filter = CatalogWearabilityFilter()
    let eyeliner = ImportedCatalogItem(
      title: "Gel Eyeliner",
      brand: "TOM FORD BEAUTY",
      priceText: "$55.00",
      categoryHint: "Makeup",
      imageURL: URL(string: "https://example.com/eyeliner.png"),
      sourceURL: URL(string: "https://www.tomfordbeauty.com/product/gel-eyeliner")!,
      notes: "Long-wear eye product"
    )
    let jacket = ImportedCatalogItem(
      title: "Relaxed Denim Jacket",
      brand: "Levi's",
      priceText: "$128.00",
      categoryHint: "Outerwear",
      imageURL: URL(string: "https://example.com/jacket.png"),
      sourceURL: URL(string: "https://www.levi.com/products/relaxed-denim-jacket")!,
      notes: "Wardrobe staple"
    )

    XCTAssertFalse(filter.isWearable(eyeliner))
    XCTAssertTrue(filter.isWearable(jacket))
  }
}
