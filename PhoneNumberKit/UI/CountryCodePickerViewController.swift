
#if os(iOS)

import UIKit

@available(iOS 11.0, *)
public protocol CountryCodePickerDelegate: AnyObject {
    func countryCodePickerViewControllerDidPickCountry(picker: CountryCodePickerViewController, country: CountryCodePickerViewController.Country)
}

public protocol CountryCodePickerCell: UITableViewCell {
    func setup(flag: String, name: String, code: String)
}

@available(iOS 11.0, *)
public struct CountryCodePickerConfiguration {
    public let screenTitle: String
    public let screenBgColor: UIColor
    public let searchPlaceholder: String
    public let searchPlaceholderFont: UIFont
    public let cell: CountryCodePickerCell.Type
    public let cancelTitle: String

    public static let common: CountryCodePickerConfiguration = {
        CountryCodePickerConfiguration(
            screenTitle: NSLocalizedString(
                "PhoneNumberKit.CountryCodePicker.Title",
                value: "Choose your country",
                comment: "Title of CountryCodePicker ViewController"
            ),
            screenBgColor: UIColor.white,
            searchPlaceholder: NSLocalizedString(
                "PhoneNumberKit.CountryCodePicker.SearchBarPlaceholder",
                value: "Search Country Codes",
                comment: "Placeholder for country code search field"
            ),
            searchPlaceholderFont: UIFont.systemFont(ofSize: 14),
            cell: CountryCodePickerViewController.Cell.self,
            cancelTitle: "Cancel"
        )
    }()

    public init(
        screenTitle: String,
        screenBgColor: UIColor,
        searchPlaceholder: String,
        searchPlaceholderFont: UIFont,
        cell: CountryCodePickerCell.Type,
        cancelTitle: String
    ) {
        self.screenTitle = screenTitle
        self.screenBgColor = screenBgColor
        self.searchPlaceholder = searchPlaceholder
        self.searchPlaceholderFont = searchPlaceholderFont
        self.cell = cell
        self.cancelTitle = cancelTitle
    }
}

@available(iOS 11.0, *)
public class CountryCodePickerViewController: UITableViewController {

    private let configuration: CountryCodePickerConfiguration

    lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.placeholder = configuration.searchPlaceholder
        if #available(iOS 13.0, *) {
            searchController.searchBar.searchTextField.font = configuration.searchPlaceholderFont
        }
        return searchController
    }()

    public let phoneNumberKit: PhoneNumberKit

    let commonCountryCodes: [String]

    var shouldRestoreNavigationBarToHidden = false

    lazy var allCountries = phoneNumberKit
        .allCountries()
        .compactMap({ Country(for: $0, with: self.phoneNumberKit) })
        .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })

    var filteredCountries: [Country] = []

    public weak var delegate: CountryCodePickerDelegate?

    lazy var cancelButton = UIBarButtonItem(
        title: configuration.cancelTitle,
        style: .plain,
        target: self,
        action: #selector(dismissAnimated)
    )

    /**
     Init with a phone number kit instance. Because a PhoneNumberKit initialization is expensive you can must pass a pre-initialized instance to avoid incurring perf penalties.

     - parameter phoneNumberKit: A PhoneNumberKit instance to be used by the text field.
     - parameter commonCountryCodes: An array of country codes to display in the section below the current region section. defaults to `PhoneNumberKit.CountryCodePicker.commonCountryCodes`
     */
    public init(
        phoneNumberKit: PhoneNumberKit,
        commonCountryCodes: [String] = PhoneNumberKit.CountryCodePicker.commonCountryCodes,
        configuration: CountryCodePickerConfiguration
    )
    {
        self.phoneNumberKit = phoneNumberKit
        self.commonCountryCodes = commonCountryCodes
        self.configuration = configuration
        super.init(style: .grouped)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        self.phoneNumberKit = PhoneNumberKit()
        self.commonCountryCodes = PhoneNumberKit.CountryCodePicker.commonCountryCodes
        self.configuration = CountryCodePickerConfiguration.common
        super.init(coder: aDecoder)
        self.commonInit()
    }

    func commonInit() {
        self.title = configuration.screenTitle
        self.view.backgroundColor = configuration.screenBgColor
        tableView.estimatedRowHeight = 66
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.register(configuration.cell, forCellReuseIdentifier: Cell.reuseIdentifier)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.backgroundColor = .clear
      
        #if os(iOS) || os(macOS) || os(watchOS)
        navigationItem.searchController = searchController
        #endif

        definesPresentationContext = true
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let nav = navigationController {
            shouldRestoreNavigationBarToHidden = nav.isNavigationBarHidden
            nav.setNavigationBarHidden(false, animated: true)
        }
        if let nav = navigationController, nav.isBeingPresented && nav.viewControllers.count == 1 {
            navigationItem.setRightBarButton(cancelButton, animated: true)
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(shouldRestoreNavigationBarToHidden, animated: true)
    }

    @objc func dismissAnimated() {
        dismiss(animated: true)
    }

    func country(for indexPath: IndexPath) -> Country {
        isFiltering ? filteredCountries[indexPath.row] : allCountries[indexPath.row]
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isFiltering ? filteredCountries.count : allCountries.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Cell.reuseIdentifier, for: indexPath)
        let country = self.country(for: indexPath)

        if let cell = cell as? CountryCodePickerCell {
            cell.setup(flag: country.flag, name: country.name, code: country.prefix)
        }

        return cell
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let country = self.country(for: indexPath)
        if isFiltering { searchController.dismiss(animated: false) }

        delegate?.countryCodePickerViewControllerDidPickCountry(picker: self, country: country)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

@available(iOS 11.0, *)
extension CountryCodePickerViewController: UISearchResultsUpdating {

    var isFiltering: Bool {
        searchController.isActive && !isSearchBarEmpty
    }

    var isSearchBarEmpty: Bool {
        searchController.searchBar.text?.isEmpty ?? true
    }

    public func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filteredCountries = allCountries.filter { country in
            country.name.lowercased().contains(searchText.lowercased()) ||
                country.code.lowercased().contains(searchText.lowercased()) ||
                country.prefix.lowercased().contains(searchText.lowercased())
        }
        tableView.reloadData()
    }
}


// MARK: Types

@available(iOS 11.0, *)
public extension CountryCodePickerViewController {

    struct Country {
        public var code: String
        public var flag: String
        public var name: String
        public var prefix: String

        public init?(for countryCode: String, with phoneNumberKit: PhoneNumberKit) {
            let flagBase = UnicodeScalar("🇦").value - UnicodeScalar("A").value
            guard
                let name = (Locale.current as NSLocale).localizedString(forCountryCode: countryCode),
                let prefix = phoneNumberKit.countryCode(for: countryCode)?.description
            else {
                return nil
            }

            self.code = countryCode
            self.name = name
            self.prefix = "+" + prefix
            self.flag = ""
            countryCode.uppercased().unicodeScalars.forEach {
                if let scaler = UnicodeScalar(flagBase + $0.value) {
                    flag.append(String(describing: scaler))
                }
            }
            if flag.count != 1 { // Failed to initialize a flag ... use an empty string
                return nil
            }
        }
    }

    class Cell: UITableViewCell, CountryCodePickerCell {
        public func setup(flag: String, name: String, code: String) {
            textLabel?.text = code + " " + flag
            detailTextLabel?.text = name
            textLabel?.font = .preferredFont(forTextStyle: .callout)
            detailTextLabel?.font = .preferredFont(forTextStyle: .body)
        }

        static let reuseIdentifier = "Cell"

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: .value2, reuseIdentifier: Self.reuseIdentifier)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

#endif
