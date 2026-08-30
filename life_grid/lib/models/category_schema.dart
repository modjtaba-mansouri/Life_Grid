/// One trackable item within a category (or the category's own single
/// rating, if it's a "solo" category with no items).
class ItemDef {
  final String id;
  final String label;
  final bool defaultOn;
  /// True = this item is a running count (e.g. "how many times today"),
  /// entered with a number stepper instead of a 1-5 rating. Counter
  /// items are never included in averages/statistics — they're a
  /// separate tally, not a mood-style rating.
  final bool isCounter;
  const ItemDef(this.id, this.label, {this.defaultOn = false, this.isCounter = false});
}

/// A category. If [items] is empty, this is a "solo" category — rated
/// directly with one number, same in Simple and Precise mode (Today,
/// Mood, GamePlay, etc.). Otherwise, Simple mode shows one combined
/// rating for the whole category, and Precise mode shows each enabled
/// item separately.
class CategoryDef {
  final String id;
  final String label;
  final List<ItemDef> items;
  final bool asksEnvironmentType; // Education: School / College / University
  final bool isCustom;
  /// True = this is always a single flat rating, in both Simple and
  /// Precise mode, and can never have sub-items (Today, Mood, GamePlay,
  /// and any user-added "standalone item"). False = a category that has
  /// (or can have) sub-items — Simple mode still shows it as one combined
  /// rating, but Precise mode expands it, even if it currently has zero
  /// enabled items (e.g. a freshly-created empty custom category).
  final bool isStandalone;
  const CategoryDef(
    this.id,
    this.label, {
    this.items = const [],
    this.asksEnvironmentType = false,
    this.isCustom = false,
    this.isStandalone = false,
  });
}

/// The master list, in display order. This order is used for both Simple
/// and Precise modes.
const List<CategoryDef> kBuiltInCategories = [
  CategoryDef('today', 'Today', isStandalone: true),
  CategoryDef('mood', 'Mood', isStandalone: true),
  CategoryDef('health', 'Health', items: [
    ItemDef('chronic_condition', 'Chronic Condition', defaultOn: true),
    ItemDef('period', 'Period'),
    ItemDef('pms', 'PMS'),
  ]),
  CategoryDef('mental', 'Mental', isStandalone: true),
  CategoryDef('weather', 'Weather', isStandalone: true),
  CategoryDef('memory', 'Memory', isStandalone: true),
  CategoryDef('luck', 'Luck', isStandalone: true),
  CategoryDef('flow_current', 'Flow and Current', isStandalone: true),
  CategoryDef('kindness', 'Kindness', items: [
    ItemDef('people_you_know', 'People You Know', defaultOn: true),
    ItemDef('strangers', 'Strangers', defaultOn: true),
    ItemDef('family', 'Family'),
    ItemDef('friends', 'Friends'),
    ItemDef('familiar_faces', 'Familiar Faces'),
    ItemDef('nature', 'Nature'),
    ItemDef('animals', 'Animals'),
  ]),
  CategoryDef('economic', 'Economic', items: [
    ItemDef('flow', 'Flow', defaultOn: true),
    ItemDef('expenses', 'Expenses', defaultOn: true),
    ItemDef('earning', 'Earning'),
    ItemDef('saving', 'Saving'),
    ItemDef('wasting', 'Wasting'),
  ]),
  CategoryDef('family', 'Family', items: [
    ItemDef('you_towards_them', 'You Towards Them', defaultOn: true),
    ItemDef('they_towards_you', 'They Towards You', defaultOn: true),
    ItemDef('relatives', 'Relatives'),
  ]),
  CategoryDef('friends', 'Friends', items: [
    ItemDef('you_towards_friends', 'You Towards Your Friends', defaultOn: true),
    ItemDef('friends_towards_you', 'Your Friends Towards You', defaultOn: true),
    ItemDef('new_people', 'New People / Acquaintances'),
  ]),
  CategoryDef('romance', 'Romance', items: [
    ItemDef('your_mood_relationship', 'Your Mood in the Relationship', defaultOn: true),
    ItemDef('partner_towards_you', 'Your Partner Towards You', defaultOn: true),
  ]),
  CategoryDef('intimacy', 'Intimacy', items: [
    ItemDef('sex', 'Sex', defaultOn: true),
    ItemDef('urges', 'Urges', defaultOn: true),
    ItemDef('sexual_feelings', 'Sexual Feelings', defaultOn: true),
    ItemDef('masturbation', 'Masturbation', defaultOn: true),
    ItemDef('urge_count', 'Number of Urges', defaultOn: true, isCounter: true),
    ItemDef('masturbation_count', 'Number of Masturbations', defaultOn: true, isCounter: true),
  ]),
  CategoryDef('workplace', 'Workplace', items: [
    ItemDef('towards_coworkers', 'Towards Coworkers (How You Treated Them)', defaultOn: true),
    ItemDef('from_coworkers', 'From Coworkers (How They Treated You)', defaultOn: true),
    ItemDef('work_itself', 'The Work Itself (Hard/Easy, Smooth/Rough Today)', defaultOn: true),
    ItemDef('boss_hr', 'Boss / Management / HR'),
  ]),
  CategoryDef('gameplay', 'GamePlay', isStandalone: true),
  CategoryDef('education', 'Education', asksEnvironmentType: true, items: [
    ItemDef('towards_classmates', 'Towards Classmates (How You Treated Them)', defaultOn: true),
    ItemDef('from_classmates', 'From Classmates (How They Treated You)', defaultOn: true),
    ItemDef('coursework', 'Coursework (Performance/Difficulty Today)', defaultOn: true),
    ItemDef('engagement', "Your Engagement in Today's Sessions", defaultOn: true),
    ItemDef('teachers', 'Teachers/Masters'),
  ]),
  CategoryDef('courses', 'Courses', items: [
    ItemDef('classmates_course', 'Classmates in the Course', defaultOn: true),
    ItemDef('engagement_session', 'Your Engagement that Session', defaultOn: true),
    ItemDef('instructor', 'Instructor'),
    ItemDef('course_itself', 'The Course Itself (Hard/Easy Today)'),
  ]),
  CategoryDef('practice', 'Practice', items: [
    ItemDef('sports', 'Sports', defaultOn: true),
    ItemDef('playing_music', 'Playing Music', defaultOn: true),
    ItemDef('painting', 'Painting', defaultOn: true),
    ItemDef('calligraphy', 'Calligraphy', defaultOn: true),
    ItemDef('yoga', 'Yoga', defaultOn: true),
  ]),
  CategoryDef('society', 'Society', items: [
    ItemDef('interactions_strangers', 'Interactions with Strangers/Public', defaultOn: true),
    ItemDef('community_involvement', 'Community Involvement'),
    ItemDef('news_impact', 'News/Current Events Impact'),
  ]),
];
