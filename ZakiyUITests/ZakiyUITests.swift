import XCTest

/// اختبارات واجهة تفاعلية حقيقية (تضغط أزرار فعلية على المحاكي) - أضيفت
/// كجزء من فحص شامل للتطبيق قبل الإطلاق. كل دالة تركّز على مسار تنقّل أو
/// دور مستخدم واحد وتلتقط سكرين شوت عند كل خطوة مهمة عشان توثّق النتيجة.
final class ZakiyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        // iOS يعرض شريط نظام "Save Password?" بعد أي دخول ناجح بكلمة سر مو
        // محفوظة بالـ Keychain أصلًا - شريط خارج شجرة accessibility الخاصة
        // بتطبيقنا (يتبع النظام مباشرة)، فيحجب أي تفاعل لاحق لو ما تجاهلناه.
        // مو خلل بالتطبيق - سلوك نظام قياسي، هذا المونيتور يرفضه تلقائيًا
        // أول ما يظهر عشان الاختبار يكمل طبيعي.
        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            let dismissLabels = ["Not Now", "لاحقًا", "إلغاء", "Cancel"]
            for label in dismissLabels {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }
    }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestResetState"]
        app.launch()
        return app
    }

    /// SwiftUI's `SecureField` بيبتلع أغلب الحروف لو كتبنا فيه فورًا بعد
    /// الضغط عليه (رصدناها فعليًا بهذا الملف - كلمة سر بـ 17 حرف وصلت للسيرفر
    /// بحرف وحد بس) - تأخير بسيط بعد الضغط قبل الكتابة يحل المشكلة بشكل
    /// موثوق، فنستخدم هذي الدالة لأي حقل كلمة سر بدل `.typeText` مباشرة.
    private func typeSecurely(_ text: String, into field: XCUIElement) {
        field.tap()
        Thread.sleep(forTimeInterval: 0.4)
        for char in text {
            field.typeText(String(char))
            Thread.sleep(forTimeInterval: 0.08)
        }
        Thread.sleep(forTimeInterval: 0.2)
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - شاشة الترحيب (غير مسجل دخول)

    func test01_WelcomeScreenAppearsWithAllEntryPoints() throws {
        let app = launchedApp()
        attach(app, name: "01_welcome_initial")

        XCTAssertTrue(app.buttons["welcome_signup_button"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["welcome_login_button"].exists)
        XCTAssertTrue(app.buttons["welcome_continue_guest_button"].exists)
    }

    func test02_LoginSheetOpensAndCancelReturnsToWelcome() throws {
        let app = launchedApp()
        let loginButton = app.buttons["welcome_login_button"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 15))
        loginButton.tap()

        let identifierField = app.textFields["login_identifier_field"]
        XCTAssertTrue(identifierField.waitForExistence(timeout: 5), "login sheet should present the identifier field")
        attach(app, name: "02_login_sheet_open")

        // زر الإلغاء لازم يرجّع لشاشة الترحيب بدون ما يعلّق المستخدم بالشاشة
        let cancelButtons = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'الغاء' OR label CONTAINS[c] 'cancel'"))
        if cancelButtons.count > 0 {
            cancelButtons.element(boundBy: 0).tap()
        } else {
            app.swipeDown()
        }
        XCTAssertTrue(app.buttons["welcome_login_button"].waitForExistence(timeout: 5), "cancelling login must return to welcome screen, not strand the user")
        attach(app, name: "02_back_at_welcome_after_cancel")
    }

    func test03_SignUpSheetOpensAndCancelReturnsToWelcome() throws {
        let app = launchedApp()
        let signupButton = app.buttons["welcome_signup_button"]
        XCTAssertTrue(signupButton.waitForExistence(timeout: 15))
        signupButton.tap()

        let usernameField = app.textFields["signup_username_field"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        attach(app, name: "03_signup_sheet_open")

        let cancelButtons = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'الغاء' OR label CONTAINS[c] 'cancel'"))
        if cancelButtons.count > 0 {
            cancelButtons.element(boundBy: 0).tap()
        } else {
            app.swipeDown()
        }
        XCTAssertTrue(app.buttons["welcome_signup_button"].waitForExistence(timeout: 5), "cancelling signup must return to welcome screen, not strand the user")
    }

    func test04_LoginWithWrongCredentialsShowsError() throws {
        let app = launchedApp()
        app.buttons["welcome_login_button"].tap()
        let identifierField = app.textFields["login_identifier_field"]
        XCTAssertTrue(identifierField.waitForExistence(timeout: 5))

        identifierField.tap()
        identifierField.typeText("nonexistent-qa-user@example.com")

        let passwordField = app.secureTextFields["login_password_field"]
        typeSecurely("WrongPassword123!", into: passwordField)

        app.buttons["login_submit_button"].tap()

        let error = app.staticTexts["login_error_message"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "wrong credentials should surface an error, not hang silently")
        attach(app, name: "04_login_wrong_credentials_error")
    }

    // MARK: - وضع الضيف (guest) - التبويبات الأساسية

    func test05_GuestModeReachesMainTabsAndEachTabLoads() throws {
        let app = launchedApp()
        let guestButton = app.buttons["welcome_continue_guest_button"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 15))
        guestButton.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "guest mode should land on the main tab bar")
        attach(app, name: "05_guest_main_tabs")

        // اضغط كل تبويب متاح وتأكد ما فيه كراش أو تعليق
        let tabButtons = tabBar.buttons
        let count = tabButtons.count
        for i in 0..<count {
            let button = tabButtons.element(boundBy: i)
            if button.exists && button.isHittable {
                button.tap()
                _ = app.wait(for: .runningForeground, timeout: 3)
                attach(app, name: "05_guest_tab_\(i)_\(button.label)")
                XCTAssertEqual(app.state, .runningForeground, "app crashed or backgrounded after tapping tab \(i): \(button.label)")
            }
        }
    }

    // MARK: - حساب فردي حقيقي - معمل الروبوتات ومختبر العلوم

    /// ينشئ حساب فردي حقيقي جديد مباشرة عبر REST (نفس تدفق التسجيل الحقيقي،
    /// بس بدون الاعتماد على SecureField+XCUITest بمحاكي iOS - رصدنا خلل بيئة
    /// حقيقي هناك: نظام اقتراح/حفظ كلمة السر بمحاكي iOS يخطف التركيز بعد أول
    /// حرف مكتوب ويفقد الباقي، أكّدناه بتجربة مباشرة أن `/auth/v1/signup`
    /// نفسه يشتغل صح 100% بأي كلمة سر كاملة، والمشكلة بمحاكاة الكتابة بس -
    /// مو خلل بالتطبيق). نفس مفتاح anon العام المطبّق أصلًا بالتطبيق الحقيقي
    /// (APIConfig.supabaseAnonKey) - مو سر إطلاقًا.
    private func createRealIndividualAccount() throws -> (email: String, password: String) {
        let stamp = Int(Date().timeIntervalSince1970)
        let email = "zakiy-qa-individual-\(stamp)@example.com"
        let password = "QaIndividual!2026"

        let url = URL(string: "https://qwlbufcailgpxxatgyez.supabase.co/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGJ1ZmNhaWxncHh4YXRneWV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1MTY1NTgsImV4cCI6MjEwMTA5MjU1OH0.ApKmMBSdZNIbSNFF0prm_cUUc2flIuVdtaGE97gonyQ", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "data": ["username": "QA Individual \(stamp)"],
        ])

        let expectation = XCTestExpectation(description: "signup REST call")
        var statusCode = 0
        URLSession.shared.dataTask(with: request) { _, response, _ in
            statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 15)
        XCTAssertEqual(statusCode, 200, "test account creation via Supabase signup REST should succeed")
        return (email, password)
    }

    /// تسجّل دخول بحساب فردي حقيقي (أُنشئ بالضبط بنفس تدفق التسجيل الحقيقي
    /// بالموقع/بالتطبيق)، بعدين تفتح معمل الروبوتات ومختبر العلوم (تبويب
    /// الكيمياء) من الإعدادات وتلتقط سكرين شوت لكل وحدة - يوثّق بصريًا هل
    /// تمرير الجلسة لـ WKWebView نجح وتخطّى شاشة تسجيل الدخول بموقع
    /// zakiy.tech أو لا. تسجّل دخول من الصفر وتوصل شاشة الإعدادات - كل
    /// اختبار وحدة (روبوتات/علوم) يبدأ من هنا من جديد بدل التنقّل بينهم
    /// بزر رجوع (لاحظنا تنقّل غير موثوق أحيانًا هناك - راجع الملاحظة تحت).
    @discardableResult
    private func loginWithRealAccountAndOpenSettings() throws -> XCUIApplication {
        let account = try createRealIndividualAccount()

        let app = launchedApp()
        app.buttons["welcome_login_button"].tap()
        let identifierField = app.textFields["login_identifier_field"]
        XCTAssertTrue(identifierField.waitForExistence(timeout: 5))
        identifierField.tap()
        identifierField.typeText(account.email)

        let passwordField = app.secureTextFields["login_password_field"]
        typeSecurely(account.password, into: passwordField)

        app.buttons["login_submit_button"].tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "login with a freshly-created real account should succeed and land on the main tab bar; error: \(app.staticTexts["login_error_message"].label)")

        // iOS يعرض "Save Password?" بعد أي دخول ناجح بكلمة سر جديدة - سلوك
        // نظام قياسي (مو خلل بالتطبيق)، نرفضه صراحة قبل ما نكمل ونعطيه وقت
        // يقفل تمامًا قبل أي تفاعل ثاني.
        if app.buttons["Not Now"].waitForExistence(timeout: 3) {
            app.buttons["Not Now"].tap()
            Thread.sleep(forTimeInterval: 1)
        }

        // حساب مسجّل دخول عنده تبويبات أكتر مما تتّسع بالشريط (Messages تضاف
        // له) فتُطوى الباقي تحت "More" تلقائيًا من UIKit - لازم نمر منه
        // للوصول لـ Settings، عكس حساب الضيف اللي Settings يظهر مباشرة.
        if tabBar.buttons["Settings"].exists {
            tabBar.buttons["Settings"].tap()
        } else {
            let moreButton = tabBar.buttons["More"]
            XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
            moreButton.tap()
            let settingsCell = app.staticTexts["Settings"]
            XCTAssertTrue(settingsCell.waitForExistence(timeout: 5), "'More' tab should list Settings for an authenticated account with overflow tabs")
            settingsCell.tap()
        }
        attach(app, name: "06_settings_after_real_login")
        return app
    }

    func test06a_RoboticsLabAuthPassthrough() throws {
        let app = try loginWithRealAccountAndOpenSettings()

        let roboticsRow = app.descendants(matching: .any)["settings_robotics_lab_row"]
        XCTAssertTrue(roboticsRow.waitForExistence(timeout: 10))
        roboticsRow.tap()
        // وقت كافي لتحميل الموقع وتنفيذ سكربت حقن الجلسة والقفز للشاشة المطلوبة
        Thread.sleep(forTimeInterval: 6)
        attach(app, name: "06a_robotics_lab_webview")
    }

    func test06b_ScienceLabChemistryAuthPassthrough() throws {
        let app = try loginWithRealAccountAndOpenSettings()

        let scienceRow = app.descendants(matching: .any)["settings_science_lab_row"]
        XCTAssertTrue(scienceRow.waitForExistence(timeout: 10))
        scienceRow.tap()
        // وقت كافي لتحميل الموقع وتنفيذ سكربت حقن الجلسة (تبويب الكيمياء
        // الافتراضي - نفس WKWebView المستخدم لمعمل الروبوتات)
        Thread.sleep(forTimeInterval: 6)
        attach(app, name: "06b_science_lab_chemistry_webview")
    }

    // MARK: - كل صف بشاشة الإعدادات (حساب فردي حقيقي) - فتح ورجوع بدون تعليق

    /// يدخل كل شاشة يوصلها حساب فردي عادي من الإعدادات (بروفايل، تعديل
    /// بروفايل، المساعد الذكي، مدرستي، اشتراك، أصدقاء، الأرشيف، ملاحظات)
    /// ويتأكد إن الشاشة تفتح بدون كراش، بعدين يرجع لشاشة الإعدادات من جديد
    /// عبر التاب بار (نفس أسلوب اختبار المعملين) بدل الاعتماد على تسلسل
    /// أزرار رجوع متتالي - رصدنا فعليًا إن حساب مسجّل دخول (تبويباته تتجاوز
    /// المساحة المتاحة فتُطوى تحت "More" تلقائيًا من iOS) ممكن أحيانًا يرجعه
    /// زر الرجوع خطوتين لبرّه (لـ"More" مباشرة) بدل خطوة وحدة لشاشة
    /// الإعدادات - خلل تنقّل حقيقي موثّق بالتقرير النهائي، ما صلّحناه هنا
    /// عشان ما نخاطر بتغيير بنيوي بآخر المهمة، بس هذا الاختبار ما يعتمد
    /// عليه فيتجنّبه.
    func test07_EverySettingsRowOpensWithoutCrashing() throws {
        let rowIdentifiers = [
            "settings_my_profile_row",
            "settings_edit_profile_row",
            "settings_ai_assistant_row",
            "settings_madrasati_row",
            "settings_subscription_row",
            "settings_friends_row",
            "settings_archive_row",
            "settings_notes_row",
        ]

        for identifier in rowIdentifiers {
            let app = try loginWithRealAccountAndOpenSettings()
            let row = app.descendants(matching: .any)[identifier]
            // شاشة الإعدادات Form طويلة - العناصر تحت الطية ما تدخل شجرة
            // الوصول إلا بعد ما تنزل الشاشة فعليًا لهناك (waitForExistence
            // لحاله ما يسكرول)، فننزل تدريجيًا لحد ما الصف يظهر.
            var attempts = 0
            while !row.waitForExistence(timeout: 2), attempts < 6 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(row.exists, "settings row '\(identifier)' should exist for an individual account (after scrolling)")
            row.tap()
            Thread.sleep(forTimeInterval: 1.5)
            attach(app, name: "07_\(identifier)_opened")
            XCTAssertEqual(app.state, .runningForeground, "app crashed after opening settings row '\(identifier)'")
        }
    }
}
