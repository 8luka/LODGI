require "ferrum"
require "nokogiri"

class ScrapePropertiesService
  def self.call(urls)
    new(urls).call
  end

  def initialize(urls)
    @urls = Array(urls)
  end

  def call
    @urls.map.with_index(1) do |url, i|
      puts "\n[#{i}/#{@urls.size}] Scraping: #{url}"
      result = scrape(url)
      pp result
      result
    end
  end

  private

  def browser
    @browser ||= begin
      b = Ferrum::Browser.new(
        headless: true,
        browser_path: "/usr/bin/brave-browser",
        timeout: 60,
        pending_connection_errors: false
      )

      b.network.intercept
      b.on(:request) do |request|
        if request.url.match?(/posthog\.com|googletagmanager\.com|hotjar\.com|google-analytics\.com|maps\.googleapis\.com|gstatic\.com/)
          request.abort
        else
          request.continue
        end
      end

      b
    end
  end

  def scrape(url)
    browser.go_to(url)
    browser.network.wait_for_idle
    sleep 2

    doc = Nokogiri::HTML(browser.body)

    {
      name: extract_name(doc),
      neighborhood: extract_neighborhood(doc),
      latitude: extract_latitude(doc),
      longitude: extract_longitude(doc),
      price: extract_price(doc),
      layout: extract_layout(doc),
      bedrooms: extract_bedrooms(doc),
      size: extract_size(doc),
      floors: extract_floor(doc),
      description: extract_description(doc),
      rules: extract_rules(doc),
      vendor: extract_vendor_name(doc),
      vendor_image: extract_vendor_image(doc),
      features: extract_features(doc),
      all_amenities: extract_amenities(doc),
      matterport_url: extract_matterport_url(doc),
      images: extract_images(doc),
      stations: extract_stations(doc)
    }
  end

  ### EXTRACTORS ### EXTRACTORS ### EXTRACTORS ### EXTRACTORS ### EXTRACTORS ###

  def extract_name(doc)
    doc.at_css("h1")&.text&.strip
  end

  def extract_neighborhood(doc)
    doc.at_css("h2.text-black-dark.text-2xl.font-medium")&.text&.strip
  end

  def extract_coordinates(doc)
    href = doc.at_css("a[href*='google.com/maps/search']")&.[]("href")
    href&.match(/query=([-\d.]+),([-\d.]+)/)&.captures || [nil, nil]
  end

  def extract_latitude(doc)  = extract_coordinates(doc).first&.to_f
  def extract_longitude(doc) = extract_coordinates(doc).last&.to_f

  def extract_column_value(doc, label)
    doc.css("div.hidden.lg\\:block")
       .find { |element| element.text.strip == label }
       &.parent
       &.at_css(".text-black-dark")
       &.text
       &.strip
  end

  def extract_price(doc)
    extract_column_value(doc, "Rent")&.gsub(/[^0-9]/, "")&.to_i
  end

  def extract_layout(doc)
    extract_column_value(doc, "Layout")
  end

  def extract_bedrooms(doc)
    extract_column_value(doc, "Bedrooms")&.to_i
  end

  def extract_size(doc)
    extract_column_value(doc, "Size")&.gsub(/[^0-9]/, "")&.to_i
  end

  def extract_floor(doc)
    extract_column_value(doc, "Floor")&.gsub(/[^0-9]/, "")&.to_i
  end

  def extract_section_text(doc, heading)
    doc.css("h3")
       .find { |element| element.text.strip == heading }
       &.next_element
       &.at_css("p")
       &.text
       &.strip
  end

  def extract_description(doc)
    extract_section_text(doc, "Property information")
  end

  def extract_rules(doc)
    extract_section_text(doc, "Important note")
  end

  def vendor_section(doc)
    doc.css("h3")
       .find { |element| element.text.strip == "Vendor" }
       &.parent
  end

  def extract_vendor_name(doc)
    vendor_section(doc)&.at_css("div.font-semibold.text-black")&.text&.strip
  end

  def extract_vendor_image(doc)
    vendor_section(doc)&.at_css("img[alt='profile']")&.[]("src")
  end

  # def extract_tag_list(doc, heading)
  #   doc.css("h3")
  #      .find { |element| element.text.strip == heading }
  #      &.next_element
  #      &.css("span")
  #      &.map { |span| span.text.strip } || []
  # end

  # def extract_features(doc)  = extract_tag_list(doc, "Property features")
  # def extract_amenities(doc) = extract_tag_list(doc, "Property appliances")

  EXCLUDED_FEATURES = ["Maisonette", "Designer apartment", "Auto lock", "LGBT Friendly"].freeze

  def extract_tag_list(doc, heading, exclude: [])
    doc.css("h3")
       .find { |element| element.text.strip == heading }
       &.next_element
       &.css("span")
       &.map { |span| span.text.strip }
       &.reject { |tag| exclude.include?(tag) } || []
  end

  def extract_features(doc)  = extract_tag_list(doc, "Property features", exclude: EXCLUDED_FEATURES)
  def extract_amenities(doc) = extract_tag_list(doc, "Property appliances")

  def extract_matterport_url(doc)
    doc.css("h3")
       .find { |element| element.text.strip == "3D Tour" }
       &.parent
       &.at_css("iframe")
      &.[]("src")
  end

  def extract_images(doc)
    doc.css(".single-property-image-slider a[data-fancybox='gallery']")
       .select { |a| a.at_css("img[alt='Banner']") }
       .first(8)
       .map { |a| a["href"] }
  end

  def extract_stations(doc)
    doc.css(".space-y-1\\.5 .flex.items-start.gap-2")
       .map { |row| row.css("div").last&.text&.gsub(/[[:space:]]+/, " ")&.strip }
       .compact
  end
end
