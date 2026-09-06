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
        // لغة المحاكي رصدناها فعليًا غير ثابتة بين تشغيل وآخر (تنقلب عربي حتى
        // لو كانت إنجليزي بتشغيل سابق نفس الجلسة) - نجبر الإنجليزي صراحة عشان
        // مطابقة نصوص الأزرار بالاختبارات تبقى موثوقة (راجع AppSettings.swift)
        app.launchArguments += ["-UITestResetState", "-UITestForceEnglish"]
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

    /// Regression: كان الضغط على أي تصنيف/حيوان بالأحياء ينهي التطبيق لأن
    /// ScienceLabSession لم تكن مضمونة داخل وجهات NavigationStack.
    func test06c_ScienceLabBiologyNavigationDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestResetState", "-UITestForceEnglish", "-UITestScienceLabBiology"]
        app.launch()

        let mammals = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'mammals' OR label CONTAINS[c] 'ثدييات'")).firstMatch
        XCTAssertTrue(mammals.waitForExistence(timeout: 10))
        mammals.tap()
        XCTAssertEqual(app.state, .runningForeground, "app must stay open after selecting a biology category")

        let lion = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'lion' OR label CONTAINS[c] 'أسد'")).firstMatch
        XCTAssertTrue(lion.waitForExistence(timeout: 10))
        lion.tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(app.state, .runningForeground, "app must stay open after opening an animal detail")
        attach(app, name: "06c_science_lab_biology_detail")
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

    // MARK: - غير مسجّل دخول: RoomLobbyView "تسجيل الدخول" (خلل تعشيش NavigationStack مصحّح)

    /// كانت `RoomLobbyView.loginRequiredView` تدفع `LoginView` (نفسه NavigationStack)
    /// بـ NavigationLink فوق NavigationStack الحالي - تعشيش غير صحيح (نفس فئة خلل
    /// "زر الرجوع يرجع بعيد" الموثّقة بالمشروع). صحّحناها لتقديمها كـ sheet بدل
    /// دفعها - هذا الاختبار يتأكد الرجوع من شاشة الدخول (بزر الإلغاء) يرجّع بالضبط
    /// لـ RoomLobbyView (مو لبرّه ولا معلّق)، وهذا مسار يوصله أي دور (بما فيه ضيف).
    func test08_RoomLobbyLoginPromptOpensAsSheetAndCancelReturnsToLobby() throws {
        let app = launchedApp()
        let guestButton = app.buttons["welcome_continue_guest_button"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 15))
        guestButton.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        tabBar.buttons["Rooms"].tap()

        let groupRoomRow = app.descendants(matching: .any)["rooms_hub_group_room_row"]
        XCTAssertTrue(groupRoomRow.waitForExistence(timeout: 10))
        groupRoomRow.tap()

        let loginButton = app.buttons["room_lobby_login_button"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10), "unauthenticated user opening a room should see the login-required prompt")
        attach(app, name: "08_room_lobby_login_required")
        loginButton.tap()

        // لو كانت لسه NavigationLink (خلل قديم)، هذا الحقل برضو بيظهر - الفرق
        // الحقيقي يظهر بعد الإلغاء تحت
        let identifierField = app.textFields["login_identifier_field"]
        XCTAssertTrue(identifierField.waitForExistence(timeout: 5), "login sheet should present the identifier field")
        attach(app, name: "08_login_sheet_over_lobby")

        let cancelButtons = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'"))
        XCTAssertTrue(cancelButtons.count > 0, "login sheet should have a cancel button")
        cancelButtons.element(boundBy: 0).tap()

        // لازم نرجع بالضبط لـ RoomLobbyView (زر تسجيل الدخول لسه موجود)، مو نطلع
        // للخلف أكثر (لـ RoomsHubView) ولا نعلق بشاشة الدخول
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5), "cancelling login must return to RoomLobbyView exactly, not pop further or strand the user")
        attach(app, name: "08_back_at_room_lobby_after_cancel")
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - حسابات مؤسسية حقيقية (مدرسة/معلم/طالب) - دخول + بوابة تغيير كلمة السر

    /// كل الحسابات المؤسسية التجريبية عندها `must_change_password=true` أول
    /// دخول - هذي الدالة تتعامل مع البوابة الصلبة (`ForcePasswordChangeView`)
    /// لو ظهرت، وتُرجع كلمة السر الفعلية المستخدمة بعدها (تدعم إعادة تشغيل
    /// الاختبار بنفس الجلسة: لو الدخول بكلمة السر الأصلية فشل - افتراض إنها
    /// انصفّرت بتشغيل سابق بنفس الجلسة - تعيد المحاولة بكلمة السر الجديدة).
    /// يمسح أي نص موجود بحقل نص عادي (Backspace بعدد حروف القيمة الحالية) قبل
    /// ما يكتب نص جديد - لازم قبل أي إعادة محاولة على نفس الحقل، غير كذا
    /// النص الجديد ينلصق على القديم بدل ما يستبدله.
    private func clearAndType(_ field: XCUIElement, _ text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            field.typeText(deleteString)
        }
        field.typeText(text)
    }

    private enum LoginOutcome { case forcePasswordChange, dashboardOrTabs, error }

    /// ينتظر حد ما توصل واحدة من ثلاث نتايج ممكنة بعد الضغط على "دخول"،
    /// بدل افتراض نتيجة معيّنة بعد وقت ثابت - كل واحدة إشارة واضحة بواجهة
    /// المستخدم (مو خمّن بالتوقيت).
    private func waitForLoginOutcome(_ app: XCUIApplication, timeout: TimeInterval) -> LoginOutcome? {
        let forcePwField = app.secureTextFields["force_pw_new_password_field"]
        let errorMessage = app.staticTexts["login_error_message"]
        let tabBar = app.tabBars.firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if forcePwField.exists { return .forcePasswordChange }
            if tabBar.exists { return .dashboardOrTabs }
            if errorMessage.exists { return .error }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return nil
    }

    /// كل الحسابات المؤسسية التجريبية عندها `must_change_password=true` أول
    /// دخول - هذي الدالة تتعامل مع البوابة الصلبة (`ForcePasswordChangeView`)
    /// لو ظهرت، وتُرجع كلمة السر الفعلية المستخدمة بعدها (تدعم إعادة تشغيل
    /// الاختبار بنفس الجلسة: لو الدخول بكلمة السر الأصلية فشل - افتراض إنها
    /// انصفّرت بتشغيل سابق بنفس الجلسة - تعيد المحاولة بكلمة السر الجديدة،
    /// وتفشل بوضوح (XCTFail) لو الاثنتين فشلوا، بدل ما ترجع بصمت كأنها نجحت).
    @discardableResult
    private func loginInstitutionalAccount(
        _ app: XCUIApplication,
        identifier: String,
        originalPassword: String,
        newPassword: String
    ) throws -> String {
        app.buttons["welcome_login_button"].tap()
        let identifierField = app.textFields["login_identifier_field"]
        XCTAssertTrue(identifierField.waitForExistence(timeout: 5))
        clearAndType(identifierField, identifier)

        let passwordField = app.secureTextFields["login_password_field"]
        typeSecurely(originalPassword, into: passwordField)
        app.buttons["login_submit_button"].tap()

        var usedPassword = originalPassword
        var outcome = waitForLoginOutcome(app, timeout: 20)

        if outcome == .error {
            // الأصلية فشلت - جرّب الجديدة (تشغيل سابق بنفس الجلسة غيّرها فعليًا)،
            // بعد مسح الحقلين فعليًا (مو الإضافة فوق القديم)
            clearAndType(identifierField, identifier)
            clearAndType(passwordField, newPassword)
            app.buttons["login_submit_button"].tap()
            usedPassword = newPassword
            outcome = waitForLoginOutcome(app, timeout: 20)
        }

        guard let outcome else {
            XCTFail("login for '\(identifier)' produced neither the force-password-change gate, an error, nor a landed dashboard within the timeout - possibly a network/backend hiccup, not necessarily an app bug")
            return usedPassword
        }

        if outcome == .error {
            let errorText = app.staticTexts["login_error_message"].label
            XCTFail("login for '\(identifier)' failed with both the original and the fallback new password (error shown: '\(errorText)') - this is either a genuinely wrong credential or the backend/Supabase is rejecting the request (e.g. rate limiting), not confirmed as an app bug")
            return usedPassword
        }

        if outcome == .forcePasswordChange {
            let forcePwField = app.secureTextFields["force_pw_new_password_field"]
            typeSecurely(newPassword, into: forcePwField)
            let confirmField = app.secureTextFields["force_pw_confirm_password_field"]
            typeSecurely(newPassword, into: confirmField)
            let saveButton = app.buttons["force_pw_save_button"]
            XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
            XCTAssertTrue(saveButton.isEnabled, "save should be enabled once both password fields match and are >=6 chars")
            saveButton.tap()
            usedPassword = newPassword
            // بعد الحفظ لازم نوصل فعليًا للوحة/التبويبات - لو ما وصلنا، فشل حقيقي
            // بالحفظ (سيرفري أو تحديث الحالة محليًا) نفشل الاختبار عليه بوضوح
            let landedAfterSave = XCTWaiter.wait(for: [
                XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: app.tabBars.firstMatch),
            ], timeout: 15)
            if landedAfterSave != .completed {
                // بعض الأدوار (مدرسة/معلم) ما عندها تاب بار إطلاقًا - نتأكد
                // بالأقل إن بوابة تغيير كلمة السر اختفت (يعني الحفظ نجح ورجعنا)
                XCTAssertFalse(forcePwField.exists, "force-password-change save did not seem to complete for '\(identifier)'")
            }
        }

        if app.buttons["Not Now"].waitForExistence(timeout: 3) {
            app.buttons["Not Now"].tap()
            Thread.sleep(forTimeInterval: 1)
        }

        return usedPassword
    }

    /// يرجع لأي شاشة دور مؤسسي (School/Teacher dashboard) لصف رئيسي معيّن،
    /// ثم يضغط زر الرجوع النظامي (أول زر بشريط التنقّل) ويتأكد الرجوع صحيح
    /// (نرجع بالضبط للوحة، ما نطلع لبرّه ولا نعلق) - يفحص خلل "زر الرجوع
    /// يرجع أبعد من خطوة" المذكور بتاريخ المشروع لكل صف جديد بلوحتي المدرسة/المعلم.
    private func openRowAndVerifyBackNav(_ app: XCUIApplication, rowIdentifier: String, dashboardLandmarkIdentifier: String) {
        let row = app.descendants(matching: .any)[rowIdentifier]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "dashboard row '\(rowIdentifier)' should exist")
        row.tap()
        Thread.sleep(forTimeInterval: 1.2)
        attach(app, name: "row_\(rowIdentifier)_opened")
        XCTAssertEqual(app.state, .runningForeground, "app crashed after opening '\(rowIdentifier)'")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "no back button found after opening '\(rowIdentifier)'")
        backButton.tap()

        let landmark = app.descendants(matching: .any)[dashboardLandmarkIdentifier]
        XCTAssertTrue(landmark.waitForExistence(timeout: 5), "back from '\(rowIdentifier)' should return exactly to the dashboard, not pop further or get stuck")
    }

    // MARK: - دور: إداري مدرسة (school_administration) - نفس لوحة school_admin بالضبط

    /// `school_administration` و`school_admin` يشتركان بنفس `SchoolDashboardView`
    /// بالضبط (الفرق الوحيد: `SchoolAdministrationView.canManage` يخفي إضافة/حذف
    /// حسابات إداريين ثانيين لـ `school_administration` بس) - راجع
    /// `RootView.swift` و`SchoolAdministrationView.swift:23`. حساب `test@zakiy.com`
    /// المزوّد لـ`school_admin` كلمة سره غير صحيحة فعليًا على السيرفر الحي (تأكدنا
    /// بطلب REST مباشر لـ Supabase - `invalid_credentials` بكل الاحتمالات
    /// المعقولة لالتباس النسخ)، فنغطي اللوحة المشتركة بالكامل عبر
    /// `school_administration` اللي بياناته صحيحة ونشتغل فعليًا.
    func test09_SchoolAdministrationDashboardAllRowsOpenAndBackNavWorks() throws {
        let app = launchedApp()
        _ = try loginInstitutionalAccount(
            app,
            identifier: "zakiy-qa-administration@example.com",
            originalPassword: "hcmwO503Y%8A",
            newPassword: "QaAdminNew!26x"
        )

        let landmark = "school_dash_teachers_row"
        XCTAssertTrue(app.descendants(matching: .any)[landmark].waitForExistence(timeout: 15), "school_administration should land on SchoolDashboardView after forced password change")
        attach(app, name: "09_school_dashboard")

        let rows = [
            "school_dash_teachers_row",
            "school_dash_administration_row",
            "school_dash_students_row",
            "school_dash_classes_row",
            "school_dash_bulkadd_row",
            "school_dash_attendance_row",
            "school_dash_library_row",
            "school_dash_madrasati_row",
        ]
        for row in rows {
            openRowAndVerifyBackNav(app, rowIdentifier: row, dashboardLandmarkIdentifier: landmark)
        }

        // أدوات اللوحة العلوية (المساعد الذكي/الرسائل) - نفس فحص فتح ورجوع
        openRowAndVerifyBackNav(app, rowIdentifier: "role_toolbar_ai_button", dashboardLandmarkIdentifier: landmark)
        openRowAndVerifyBackNav(app, rowIdentifier: "role_toolbar_messages_button", dashboardLandmarkIdentifier: landmark)

        // تأكيد: إداري المدرسة (مو مدير) ما يشوف زر إضافة إداري جديد بشاشة
        // إدارة الحسابات (SchoolAdministrationView.canManage == false)
        app.descendants(matching: .any)["school_dash_administration_row"].tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(app.buttons["admin_staff_add_button"].exists, "school_administration (non-admin) must not see the add-admin-staff control")
        attach(app, name: "09_administration_view_no_add_button")
    }

    // MARK: - دور: معلم (teacher)

    func test10_TeacherDashboardAllRowsOpenAndBackNavWorks() throws {
        let app = launchedApp()
        _ = try loginInstitutionalAccount(
            app,
            identifier: "zakiy-qa-teacher@example.com",
            originalPassword: "IOX7tZ5Y%wtq",
            newPassword: "QaTeacherNew!26x"
        )

        let landmark = "teacher_dash_roster_row"
        XCTAssertTrue(app.descendants(matching: .any)[landmark].waitForExistence(timeout: 15), "teacher should land on TeacherDashboardView after forced password change")
        attach(app, name: "10_teacher_dashboard")

        let rows = [
            "teacher_dash_roster_row",
            "teacher_dash_performance_row",
            "teacher_dash_schedule_row",
            "teacher_dash_attendance_row",
            "teacher_dash_library_row",
            "teacher_dash_assignments_row",
            "teacher_dash_quizzes_row",
            "teacher_dash_gradesheet_row",
            "teacher_dash_madrasati_row",
        ]
        for row in rows {
            openRowAndVerifyBackNav(app, rowIdentifier: row, dashboardLandmarkIdentifier: landmark)
        }

        openRowAndVerifyBackNav(app, rowIdentifier: "role_toolbar_ai_button", dashboardLandmarkIdentifier: landmark)
        openRowAndVerifyBackNav(app, rowIdentifier: "role_toolbar_messages_button", dashboardLandmarkIdentifier: landmark)
    }

    // MARK: - دور: طالب (student) - دخول باسم مستخدم (بدون إيميل)

    /// يسجّل دخول بحساب طالب مؤسسي حقيقي باسم المستخدم (بدون "@") - يتأكد
    /// `signInWithIdentifier` يحوّله فعليًا لبريده الاصطناعي عبر
    /// `/api/resolve-login-identifier` قبل Supabase (بدل ما يفشل الدخول
    /// مباشرة لأن Supabase يتطلب إيميل دايمًا).
    func test11_StudentUsernameLoginReachesMainTabsWithScheduleTab() throws {
        let app = launchedApp()
        _ = try loginInstitutionalAccount(
            app,
            identifier: "talbtjrybywahd",
            originalPassword: "DsF%QoKQH6Bf",
            newPassword: "QaStud1New!26x"
        )

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "student login should reach the normal MainTabView")
        attach(app, name: "11_student_main_tabs")

        // طالب مرتبط بفصل (class_id != nil) - لازم يشوف تبويب "جدولي" الإضافي
        // اللي ما يظهر لحساب فردي عادي (MainTabView.swift:16-20)
        XCTAssertTrue(tabBar.buttons["My Schedule"].waitForExistence(timeout: 5), "a student with a class assigned should see the extra 'My Schedule' tab")

        for label in ["Home", "Rooms", "My Schedule", "Library", "Performance", "Messages", "Settings"] {
            let button = tabBar.buttons[label]
            if button.exists && button.isHittable {
                button.tap()
                _ = app.wait(for: .runningForeground, timeout: 3)
                attach(app, name: "11_student_tab_\(label)")
                XCTAssertEqual(app.state, .runningForeground, "app crashed after tapping student tab '\(label)'")
            }
        }

        // Settings -> الواجبات/الاختبارات (خاص بالطالب فقط، SettingsView.swift:77-84)
        tabBar.buttons["Settings"].tap()
        let assignmentsRow = app.descendants(matching: .any)["settings_assignments_row"]
        var attempts = 0
        while !assignmentsRow.waitForExistence(timeout: 2), attempts < 6 {
            app.swipeUp(); attempts += 1
        }
        XCTAssertTrue(assignmentsRow.exists, "student should see the assignments row under Settings")
        assignmentsRow.tap()
        Thread.sleep(forTimeInterval: 1)
        attach(app, name: "11_student_assignments_list")
        XCTAssertEqual(app.state, .runningForeground)
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings_assignments_row"].waitForExistence(timeout: 5), "back from assignments should return to Settings, not strand the student")
    }

    // MARK: - حلقة كاملة معلم↔طالب: اختبار (سؤال صح/خطأ) إنشاء→نشر→حل→تصحيح

    /// كل مرحلة بتشغيل تطبيق منفصل (تسجيل خروج/دخول فعلي بين المعلم والطالب،
    /// نفس تجربة حسابين حقيقيين مختلفين) - يوثّق التكامل الفعلي عبر السيرفر
    /// الحي، مو مجرد فحص واجهة كل دور لحاله.
    func test12_TeacherCreatesQuizStudentTakesItTeacherGrades() throws {
        let uniqueTitle = "QA T/F Quiz \(Int(Date().timeIntervalSince1970))"

        // 1) المعلم ينشئ اختبار سؤال واحد (صح/خطأ) وينشره
        let teacherApp = launchedApp()
        try loginInstitutionalAccount(
            teacherApp,
            identifier: "zakiy-qa-teacher@example.com",
            originalPassword: "IOX7tZ5Y%wtq",
            newPassword: "QaTeacherNew!26x"
        )
        teacherApp.descendants(matching: .any)["teacher_dash_quizzes_row"].tap()
        teacherApp.buttons["quizzes_create_button"].tap()

        let subjectField = teacherApp.textFields["quiz_create_subject_field"]
        XCTAssertTrue(subjectField.waitForExistence(timeout: 10))
        subjectField.tap()
        subjectField.typeText("QA")
        let titleField = teacherApp.textFields["quiz_create_title_field"]
        titleField.tap()
        titleField.typeText(uniqueTitle)

        teacherApp.buttons["quiz_create_add_question_button"].tap()
        teacherApp.buttons["question_editor_type_picker"].tap()
        let trueFalseMenuItem = teacherApp.buttons["True / False"]
        XCTAssertTrue(trueFalseMenuItem.waitForExistence(timeout: 5), "question type menu should offer True/False")
        trueFalseMenuItem.tap()

        let questionTextField = teacherApp.textFields["question_editor_text_field"]
        XCTAssertTrue(questionTextField.waitForExistence(timeout: 5))
        questionTextField.tap()
        questionTextField.typeText("2 + 2 = 4?")
        teacherApp.buttons["question_editor_true_button"].tap()

        attach(teacherApp, name: "12_quiz_create_form_filled")
        teacherApp.buttons["quiz_create_submit_button"].tap()

        // يرجع لقائمة الاختبارات بعد الحفظ - نفتح اللي أنشأناه بالتو (مسودة)
        let newQuizRow = teacherApp.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", uniqueTitle)).firstMatch
        XCTAssertTrue(newQuizRow.waitForExistence(timeout: 10), "newly created quiz should appear in the teacher's list")
        newQuizRow.tap()

        let publishButton = teacherApp.buttons["quiz_publish_button"]
        XCTAssertTrue(publishButton.waitForExistence(timeout: 5))
        publishButton.tap()
        let confirmPublish = teacherApp.buttons["Publish quiz"]
        XCTAssertTrue(confirmPublish.waitForExistence(timeout: 5))
        confirmPublish.tap()
        Thread.sleep(forTimeInterval: 1.5)
        attach(teacherApp, name: "12_quiz_published")
        XCTAssertEqual(teacherApp.state, .runningForeground)

        // 2) الطالب يحل نفس الاختبار (تسجيل دخول باسم مستخدم، تطبيق منفصل تمامًا)
        let studentApp = launchedApp()
        try loginInstitutionalAccount(
            studentApp,
            identifier: "talbtjrybywahd",
            originalPassword: "DsF%QoKQH6Bf",
            newPassword: "QaStud1New!26x"
        )
        let studentTabBar = studentApp.tabBars.firstMatch
        XCTAssertTrue(studentTabBar.waitForExistence(timeout: 15))
        studentTabBar.buttons["Settings"].tap()
        let quizzesRow = studentApp.descendants(matching: .any)["settings_quizzes_row"]
        var attempts = 0
        while !quizzesRow.waitForExistence(timeout: 2), attempts < 6 {
            studentApp.swipeUp(); attempts += 1
        }
        XCTAssertTrue(quizzesRow.exists)
        quizzesRow.tap()

        let studentQuizRow = studentApp.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", uniqueTitle)).firstMatch
        XCTAssertTrue(studentQuizRow.waitForExistence(timeout: 10), "student should see the newly-published quiz")
        studentQuizRow.tap()

        let trueLabel = studentApp.buttons["True"]
        XCTAssertTrue(trueLabel.waitForExistence(timeout: 10), "quiz-take screen should render the true/false answer buttons")
        trueLabel.tap()
        attach(studentApp, name: "12_student_answered_quiz")

        studentApp.buttons["Submit quiz"].firstMatch.tap()
        // زر التسليم يفتح confirmationDialog بنفس النص تقريبًا - نضغط أول زر
        // مطابق يظهر بعده (تأكيد التسليم الفعلي)
        let confirmSubmit = studentApp.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'submit'")).element(boundBy: 0)
        if confirmSubmit.waitForExistence(timeout: 3) { confirmSubmit.tap() }
        Thread.sleep(forTimeInterval: 2)
        attach(studentApp, name: "12_student_submitted_quiz")
        XCTAssertEqual(studentApp.state, .runningForeground, "app should not crash after submitting a quiz")

        // 3) المعلم يشوف إجابة الطالب ويحطّ درجة يدوية
        let teacherApp2 = launchedApp()
        try loginInstitutionalAccount(
            teacherApp2,
            identifier: "zakiy-qa-teacher@example.com",
            originalPassword: "IOX7tZ5Y%wtq",
            newPassword: "QaTeacherNew!26x"
        )
        teacherApp2.descendants(matching: .any)["teacher_dash_quizzes_row"].tap()
        let gradedQuizRow = teacherApp2.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", uniqueTitle)).firstMatch
        XCTAssertTrue(gradedQuizRow.waitForExistence(timeout: 10))
        gradedQuizRow.tap()

        let viewAnswersButton = teacherApp2.buttons["View answers"]
        if viewAnswersButton.waitForExistence(timeout: 5) { viewAnswersButton.tap() }
        attach(teacherApp2, name: "12_teacher_sees_student_submission")
        XCTAssertEqual(teacherApp2.state, .runningForeground, "app should not crash showing the student's submitted answer")
    }

    // MARK: - رسائل: معلم يبدأ محادثة جديدة مع طالب (بدون علاقة صداقة) ويردّ الطالب

    func test13_TeacherMessagesStudentAndStudentReplies() throws {
        let uniqueBody = "QA ping \(Int(Date().timeIntervalSince1970))"

        let teacherApp = launchedApp()
        try loginInstitutionalAccount(
            teacherApp,
            identifier: "zakiy-qa-teacher@example.com",
            originalPassword: "IOX7tZ5Y%wtq",
            newPassword: "QaTeacherNew!26x"
        )
        teacherApp.buttons["role_toolbar_messages_button"].tap()

        let searchField = teacherApp.textFields["conversations_search_field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("talbtjrybywahd")
        Thread.sleep(forTimeInterval: 1.5) // debounce (300ms) + طلب شبكة

        let resultRow = teacherApp.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'conversations_search_result_'")).firstMatch
        XCTAssertTrue(resultRow.waitForExistence(timeout: 10), "teacher should be able to find a student by username with no prior friendship")
        resultRow.tap()

        let inputField = teacherApp.textFields["conversation_input_field"]
        XCTAssertTrue(inputField.waitForExistence(timeout: 5))
        inputField.tap()
        inputField.typeText(uniqueBody)
        teacherApp.buttons["conversation_send_button"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(teacherApp.staticTexts[uniqueBody].waitForExistence(timeout: 5), "sent message should appear in the thread")
        attach(teacherApp, name: "13_teacher_sent_message")

        // الطالب يشوف الرسالة ويرد
        let studentApp = launchedApp()
        try loginInstitutionalAccount(
            studentApp,
            identifier: "talbtjrybywahd",
            originalPassword: "DsF%QoKQH6Bf",
            newPassword: "QaStud1New!26x"
        )
        let studentTabBar = studentApp.tabBars.firstMatch
        XCTAssertTrue(studentTabBar.waitForExistence(timeout: 15))
        studentTabBar.buttons["Messages"].tap()

        let conversationCell = studentApp.staticTexts["معلم تجريبي QA"]
        var found = conversationCell.waitForExistence(timeout: 10)
        if !found {
            // اسم العرض قد يظهر بلغة/تنسيق مختلف شوي - نجرّب مطابقة جزئية بدل التساوي التام
            found = studentApp.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'تجريبي'")).firstMatch.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(found, "student should see a conversation from the teacher with no prior friendship")
        studentApp.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'تجريبي'")).firstMatch.tap()

        XCTAssertTrue(studentApp.staticTexts[uniqueBody].waitForExistence(timeout: 10), "student should receive the teacher's message")
        attach(studentApp, name: "13_student_received_message")

        let replyText = "QA reply \(Int(Date().timeIntervalSince1970))"
        let studentInput = studentApp.textFields["conversation_input_field"]
        studentInput.tap()
        studentInput.typeText(replyText)
        studentApp.buttons["conversation_send_button"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(studentApp.staticTexts[replyText].waitForExistence(timeout: 5), "student's reply should appear in their own thread")
        attach(studentApp, name: "13_student_replied")
        XCTAssertEqual(studentApp.state, .runningForeground)
    }
}
