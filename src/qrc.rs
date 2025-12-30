qrc!(qml_resources,
    "/" {
        "qml/Main.qml",
        "qml/MediaPickerPage.qml",
        "qml/PostDetailPage.qml",
        "qml/PostPage.qml",
        "qml/QuotePost.qml",
        "qml/SearchPage.qml",
        "qml/SettingsPage.qml",
        "qml/SignInPage.qml",
        "qml/TimelinePage.qml",
        "qml/TimelinePost.qml",
        "qml/TimelinePostContent.qml",
        "qml/UserProfilePage.qml",
    },
);

pub fn load() {
    qml_resources();
}
