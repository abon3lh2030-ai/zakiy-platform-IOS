import Foundation

// ============================================================================
// مستكشف الأحياء - بيانات ثابتة منقولة حرفيًا من SL_BIO_CATEGORIES/SL_ANIMALS/
// SL_BODY_IMAGES/SL_ANIMAL_BODY_KEY/SL_PARTS_INFO بموقع الويب (30-science-lab.js)
// - نفس الترتيب، نفس القيم بالضبط. ما تُترجم ولا تُعدَّل بدون الرجوع للمصدر.
// ============================================================================

/// تصنيف أحياء (ثدييات/زواحف/برمائيات/طيور/أسماك/جسم الإنسان)
struct BioCategory: Identifiable, Hashable {
    let id: String
    let nameKey: String
    let icon: String
    let animalIds: [String]
}

/// حيوان مفرد - اسم + حقيقة سريعة (تظهر بالبطاقة) + ٣ حقائق مفصّلة (تظهر بشاشة التفاصيل)
struct BioAnimal: Identifiable, Hashable {
    let id: String
    let nameKey: String
    let icon: String
    let quickFactKey: String
    let factKeys: [String]
}

/// نقطة ضغط فوق صورة تشريح - x/y نسبة مئوية من عرض/ارتفاع الصورة (مأخوذة
/// كما هي من SL_BODY_IMAGES بدون أي إعادة حساب - مضبوطة يدويًا على الصورة الحقيقية)
struct BodyHotspot: Identifiable, Hashable {
    let part: String
    let x: Double
    let y: Double
    var id: String { "\(part)-\(x)-\(y)" }
}

/// مصدر صورة الجسم. كل صور الموقع مرفقة الآن داخل التطبيق حتى تظهر فورًا
/// وبشكل ثابت، مع إبقاء دعم الرابط الخارجي لأي صورة مستقبلية.
enum BodyImageSource: Hashable {
    case asset(String)
    case remote(URL)
}

struct BodyImageData: Identifiable, Hashable {
    let id: String
    let source: BodyImageSource
    /// مفتاح ترجمة نص الإسناد (الرخصة/المصدر) - nil يعني ما فيه إسناد مطلوب
    /// (صورة الإنسان CC0، ورسمتا الفيل/التمساح للمستخدم نفسه)
    let creditKey: String?
    let hotspots: [BodyHotspot]
}

struct BodyPartInfo {
    let nameKey: String
    let descKey: String
}

enum ScienceLabBioData {
    // ---------- SL_BIO_CATEGORIES ----------
    static let categories: [BioCategory] = [
        BioCategory(id: "mammals", nameKey: "sl_cat_mammals", icon: "🦁", animalIds: ["lion", "elephant", "cat", "dog", "whale"]),
        BioCategory(id: "reptiles", nameKey: "sl_cat_reptiles", icon: "🐊", animalIds: ["crocodile", "turtle", "snake"]),
        BioCategory(id: "amphibians", nameKey: "sl_cat_amphibians", icon: "🐸", animalIds: ["frog", "salamander"]),
        BioCategory(id: "birds", nameKey: "sl_cat_birds", icon: "🦅", animalIds: ["eagle", "penguin", "parrot"]),
        BioCategory(id: "fish", nameKey: "sl_cat_fish", icon: "🦈", animalIds: ["shark", "goldfish"]),
        BioCategory(id: "human", nameKey: "sl_cat_human", icon: "🧍", animalIds: []),
    ]

    // ---------- SL_ANIMALS ----------
    static let animals: [String: BioAnimal] = [
        "lion": BioAnimal(id: "lion", nameKey: "sl_animal_lion_name", icon: "🦁", quickFactKey: "sl_animal_lion_quick", factKeys: ["sl_animal_lion_fact1", "sl_animal_lion_fact2", "sl_animal_lion_fact3"]),
        "elephant": BioAnimal(id: "elephant", nameKey: "sl_animal_elephant_name", icon: "🐘", quickFactKey: "sl_animal_elephant_quick", factKeys: ["sl_animal_elephant_fact1", "sl_animal_elephant_fact2", "sl_animal_elephant_fact3"]),
        "cat": BioAnimal(id: "cat", nameKey: "sl_animal_cat_name", icon: "🐱", quickFactKey: "sl_animal_cat_quick", factKeys: ["sl_animal_cat_fact1", "sl_animal_cat_fact2", "sl_animal_cat_fact3"]),
        "dog": BioAnimal(id: "dog", nameKey: "sl_animal_dog_name", icon: "🐶", quickFactKey: "sl_animal_dog_quick", factKeys: ["sl_animal_dog_fact1", "sl_animal_dog_fact2", "sl_animal_dog_fact3"]),
        "whale": BioAnimal(id: "whale", nameKey: "sl_animal_whale_name", icon: "🐋", quickFactKey: "sl_animal_whale_quick", factKeys: ["sl_animal_whale_fact1", "sl_animal_whale_fact2", "sl_animal_whale_fact3"]),
        "crocodile": BioAnimal(id: "crocodile", nameKey: "sl_animal_crocodile_name", icon: "🐊", quickFactKey: "sl_animal_crocodile_quick", factKeys: ["sl_animal_crocodile_fact1", "sl_animal_crocodile_fact2", "sl_animal_crocodile_fact3"]),
        "turtle": BioAnimal(id: "turtle", nameKey: "sl_animal_turtle_name", icon: "🐢", quickFactKey: "sl_animal_turtle_quick", factKeys: ["sl_animal_turtle_fact1", "sl_animal_turtle_fact2", "sl_animal_turtle_fact3"]),
        "snake": BioAnimal(id: "snake", nameKey: "sl_animal_snake_name", icon: "🐍", quickFactKey: "sl_animal_snake_quick", factKeys: ["sl_animal_snake_fact1", "sl_animal_snake_fact2", "sl_animal_snake_fact3"]),
        "frog": BioAnimal(id: "frog", nameKey: "sl_animal_frog_name", icon: "🐸", quickFactKey: "sl_animal_frog_quick", factKeys: ["sl_animal_frog_fact1", "sl_animal_frog_fact2", "sl_animal_frog_fact3"]),
        "salamander": BioAnimal(id: "salamander", nameKey: "sl_animal_salamander_name", icon: "🦎", quickFactKey: "sl_animal_salamander_quick", factKeys: ["sl_animal_salamander_fact1", "sl_animal_salamander_fact2", "sl_animal_salamander_fact3"]),
        "eagle": BioAnimal(id: "eagle", nameKey: "sl_animal_eagle_name", icon: "🦅", quickFactKey: "sl_animal_eagle_quick", factKeys: ["sl_animal_eagle_fact1", "sl_animal_eagle_fact2", "sl_animal_eagle_fact3"]),
        "penguin": BioAnimal(id: "penguin", nameKey: "sl_animal_penguin_name", icon: "🐧", quickFactKey: "sl_animal_penguin_quick", factKeys: ["sl_animal_penguin_fact1", "sl_animal_penguin_fact2", "sl_animal_penguin_fact3"]),
        "parrot": BioAnimal(id: "parrot", nameKey: "sl_animal_parrot_name", icon: "🦜", quickFactKey: "sl_animal_parrot_quick", factKeys: ["sl_animal_parrot_fact1", "sl_animal_parrot_fact2", "sl_animal_parrot_fact3"]),
        "shark": BioAnimal(id: "shark", nameKey: "sl_animal_shark_name", icon: "🦈", quickFactKey: "sl_animal_shark_quick", factKeys: ["sl_animal_shark_fact1", "sl_animal_shark_fact2", "sl_animal_shark_fact3"]),
        "goldfish": BioAnimal(id: "goldfish", nameKey: "sl_animal_goldfish_name", icon: "🐠", quickFactKey: "sl_animal_goldfish_quick", factKeys: ["sl_animal_goldfish_fact1", "sl_animal_goldfish_fact2", "sl_animal_goldfish_fact3"]),
    ]

    // ---------- SL_BODY_PARTS (نفس القائمة للحيوانات وللإنسان) ----------
    static let genericBodyParts = ["heart", "lungs", "brain", "stomach", "liver", "intestines", "kidneys", "skin"]

    // ---------- SL_PARTS_INFO ----------
    static let partsInfo: [String: BodyPartInfo] = [
        "heart": BodyPartInfo(nameKey: "sl_part_heart_name", descKey: "sl_part_heart_desc"),
        "lungs": BodyPartInfo(nameKey: "sl_part_lungs_name", descKey: "sl_part_lungs_desc"),
        "brain": BodyPartInfo(nameKey: "sl_part_brain_name", descKey: "sl_part_brain_desc"),
        "stomach": BodyPartInfo(nameKey: "sl_part_stomach_name", descKey: "sl_part_stomach_desc"),
        "kidneys": BodyPartInfo(nameKey: "sl_part_kidneys_name", descKey: "sl_part_kidneys_desc"),
        "skin": BodyPartInfo(nameKey: "sl_part_skin_name", descKey: "sl_part_skin_desc"),
        "liver": BodyPartInfo(nameKey: "sl_part_liver_name", descKey: "sl_part_liver_desc"),
        "intestines": BodyPartInfo(nameKey: "sl_part_intestines_name", descKey: "sl_part_intestines_desc"),
    ]

    // ---------- SL_BODY_IMAGES ----------
    // الصور نفسها المستخدمة في موقع الويب، محفوظة محليًا بكتالوج الأصول حتى
    // لا يعتمد المختبر على الشبكة أو دعم SVG الأصلي في iOS.
    static let bodyImages: [String: BodyImageData] = [
        "human": BodyImageData(
            id: "human",
            source: .asset("BiologyHuman"),
            creditKey: nil,
            hotspots: [
                BodyHotspot(part: "brain", x: 48.6, y: 16.4),
                BodyHotspot(part: "heart", x: 44.3, y: 52.4),
                BodyHotspot(part: "lungs", x: 35.7, y: 44),
                BodyHotspot(part: "lungs", x: 50, y: 44),
                BodyHotspot(part: "liver", x: 42.1, y: 63.2),
                BodyHotspot(part: "stomach", x: 52.5, y: 68.4),
                BodyHotspot(part: "kidneys", x: 38.9, y: 72),
                BodyHotspot(part: "kidneys", x: 52.1, y: 70.4),
                BodyHotspot(part: "intestines", x: 40, y: 82.8),
                BodyHotspot(part: "skin", x: 29.3, y: 48),
            ]
        ),
        "dog": BodyImageData(
            id: "dog",
            source: .asset("BiologyDog"),
            creditKey: "sl_body_credit_dog",
            hotspots: [
                BodyHotspot(part: "brain", x: 16.7, y: 9.2),
                BodyHotspot(part: "lungs", x: 17.8, y: 26.7),
                BodyHotspot(part: "heart", x: 20.6, y: 35),
                BodyHotspot(part: "liver", x: 29.4, y: 28.3),
                BodyHotspot(part: "stomach", x: 31.1, y: 34.2),
                BodyHotspot(part: "kidneys", x: 36.1, y: 25),
                BodyHotspot(part: "intestines", x: 39.4, y: 31.7),
                BodyHotspot(part: "skin", x: 33.3, y: 46.7),
            ]
        ),
        "elephant": BodyImageData(
            id: "elephant",
            source: .asset("AnimalElephantBody"),
            creditKey: nil,
            hotspots: [
                BodyHotspot(part: "brain", x: 22.5, y: 30.2),
                BodyHotspot(part: "heart", x: 40.7, y: 40.9),
                BodyHotspot(part: "liver", x: 48.7, y: 42.7),
                BodyHotspot(part: "stomach", x: 52.2, y: 47.4),
                BodyHotspot(part: "intestines", x: 62.5, y: 48.6),
                BodyHotspot(part: "kidneys", x: 72, y: 26.7),
                BodyHotspot(part: "kidneys", x: 75.2, y: 34.4),
            ]
        ),
        "crocodile": BodyImageData(
            id: "crocodile",
            source: .asset("AnimalCrocodileBody"),
            creditKey: nil,
            hotspots: [
                BodyHotspot(part: "brain", x: 23, y: 19.4),
                BodyHotspot(part: "heart", x: 42.8, y: 47.5),
                BodyHotspot(part: "liver", x: 44.9, y: 41),
                BodyHotspot(part: "lungs", x: 52.2, y: 36.7),
                BodyHotspot(part: "stomach", x: 52.8, y: 48.6),
                BodyHotspot(part: "intestines", x: 64.8, y: 41),
                BodyHotspot(part: "kidneys", x: 72.6, y: 37.8),
                BodyHotspot(part: "skin", x: 86.7, y: 64.8),
            ]
        ),
        "cat": BodyImageData(
            id: "cat",
            source: .asset("BiologyCat"),
            creditKey: "sl_body_credit_cat",
            hotspots: [
                BodyHotspot(part: "brain", x: 27.9, y: 25.5),
                BodyHotspot(part: "lungs", x: 43.3, y: 40.5),
                BodyHotspot(part: "heart", x: 53.9, y: 45.1),
                BodyHotspot(part: "liver", x: 59.1, y: 42.8),
                BodyHotspot(part: "stomach", x: 63.3, y: 40.5),
                BodyHotspot(part: "kidneys", x: 65.1, y: 34.7),
                BodyHotspot(part: "intestines", x: 67.3, y: 44),
                BodyHotspot(part: "skin", x: 45.2, y: 76.4),
            ]
        ),
        "reptile": BodyImageData(
            id: "reptile",
            source: .asset("BiologyReptile"),
            creditKey: "sl_body_credit_reptile",
            hotspots: [
                BodyHotspot(part: "heart", x: 50, y: 15),
                BodyHotspot(part: "lungs", x: 41.7, y: 15),
                BodyHotspot(part: "liver", x: 25, y: 50),
                BodyHotspot(part: "stomach", x: 50, y: 35.8),
                BodyHotspot(part: "intestines", x: 82.8, y: 33.7),
                BodyHotspot(part: "kidneys", x: 75, y: 81.7),
                BodyHotspot(part: "skin", x: 10, y: 78.3),
            ]
        ),
        "fish": BodyImageData(
            id: "fish",
            source: .asset("BiologyFish"),
            creditKey: "sl_body_credit_fish",
            hotspots: [
                BodyHotspot(part: "heart", x: 28.9, y: 58.8),
                BodyHotspot(part: "liver", x: 40, y: 55.5),
                BodyHotspot(part: "stomach", x: 44.3, y: 59.1),
                BodyHotspot(part: "intestines", x: 38.5, y: 68.4),
                BodyHotspot(part: "kidneys", x: 47.2, y: 48.1),
                BodyHotspot(part: "skin", x: 67.4, y: 27.7),
            ]
        ),
        "whale": BodyImageData(
            id: "whale",
            source: .asset("BiologyWhale"),
            creditKey: "sl_body_credit_whale",
            hotspots: [
                BodyHotspot(part: "brain", x: 14, y: 51.7),
                BodyHotspot(part: "heart", x: 29.6, y: 68.1),
                BodyHotspot(part: "lungs", x: 28.6, y: 46.6),
                BodyHotspot(part: "liver", x: 40.1, y: 64.7),
                BodyHotspot(part: "stomach", x: 41.3, y: 54.8),
                BodyHotspot(part: "kidneys", x: 50.7, y: 56),
                BodyHotspot(part: "intestines", x: 47.5, y: 65.5),
                BodyHotspot(part: "skin", x: 67.9, y: 30.2),
            ]
        ),
        "turtle": BodyImageData(
            id: "turtle",
            source: .asset("BiologyTurtle"),
            creditKey: "sl_body_credit_turtle",
            hotspots: [
                BodyHotspot(part: "lungs", x: 74, y: 37.9),
                BodyHotspot(part: "heart", x: 74.8, y: 40.4),
                BodyHotspot(part: "stomach", x: 71.8, y: 46.5),
                BodyHotspot(part: "liver", x: 78.5, y: 45.6),
                BodyHotspot(part: "intestines", x: 74, y: 55.1),
                BodyHotspot(part: "skin", x: 65.1, y: 37.9),
            ]
        ),
        "frog": BodyImageData(
            id: "frog",
            source: .asset("BiologyFrog"),
            creditKey: "sl_body_credit_frog",
            hotspots: [
                BodyHotspot(part: "heart", x: 44.9, y: 6.7),
                BodyHotspot(part: "lungs", x: 30.7, y: 8.5),
                BodyHotspot(part: "lungs", x: 63.8, y: 10.7),
                BodyHotspot(part: "liver", x: 54.4, y: 8.2),
                BodyHotspot(part: "kidneys", x: 28.4, y: 18.3),
            ]
        ),
        "bird": BodyImageData(
            id: "bird",
            source: .asset("BiologyBird"),
            creditKey: "sl_body_credit_bird",
            hotspots: [
                BodyHotspot(part: "stomach", x: 48.5, y: 75),
                BodyHotspot(part: "intestines", x: 37.5, y: 65.4),
            ]
        ),
    ]

    // ---------- SL_ANIMAL_BODY_KEY: أي حيوان يستخدم أي صورة (أقرب تصنيف حقيقي متوفر له) ----------
    static let animalBodyKey: [String: String] = [
        "lion": "cat", "cat": "cat", "dog": "dog",
        "elephant": "elephant", "whale": "whale",
        "crocodile": "crocodile", "turtle": "turtle", "snake": "reptile",
        "frog": "frog", "salamander": "frog",
        "eagle": "bird", "penguin": "bird", "parrot": "bird",
        "shark": "fish", "goldfish": "fish",
    ]

    static func bodyImage(forAnimal animalId: String) -> BodyImageData {
        let key = animalBodyKey[animalId] ?? "dog"
        return bodyImages[key] ?? bodyImages["dog"]!
    }
}
