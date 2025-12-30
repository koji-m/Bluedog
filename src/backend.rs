/*
 * Copyright (C) 2025  Koji Matsumoto
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * bluedog is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
use std::fmt;
use std::fs;
use std::error;
use std::path::Path;
use std::collections::{
    HashMap,
    HashSet,
};
use std::str::FromStr;
use futures::future::join_all;
use qmetaobject::*;
use atrium_api::app::bsky::actor::get_profile;
use atrium_api::app::bsky::feed::defs::{
    PostView,
    PostViewEmbedRefs,
    FeedViewPostReasonRefs,
    ThreadViewPostRepliesItem,
};
use atrium_api::app::bsky::embed::images;
use atrium_api::app::bsky::embed::record::{
    ViewRecordRefs,
    ViewRecordEmbedsItem,
};
use atrium_api::app::bsky::feed::{
    get_author_feed,
    get_post_thread,
    get_posts,
    get_timeline,
    like,
    post,
    search_posts,
};
use atrium_api::app::bsky::graph::follow;
use atrium_api::com::atproto::repo::{
    create_record,
    delete_record,
    strong_ref,
};
use atrium_api::types::string::{
    AtIdentifier,
    Cid,
    Datetime,
    Did,
};
use atrium_api::types::{
    Object,
    LimitedNonZeroU8,
    TryFromUnknown,
    Union,
};
use bsky_sdk::BskyAgent;
use bsky_sdk::agent::config::{
    Config,
    FileStore,
};
use serde;
use url::Url;

#[derive(Debug, Clone)]
pub struct BackendError;

impl fmt::Display for BackendError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "backend error")
    }
}

impl error::Error for BackendError {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        None
    }
}

#[derive(Debug, serde::Deserialize)]
struct Record {
    text: String,
}

async fn get_profile(agent: &BskyAgent, did: String) -> Result<HashMap<String, QString>, BackendError> {
    match agent.api.app.bsky.actor.get_profile(
        get_profile::ParametersData {
            actor: AtIdentifier::Did(
                Did::new(did).unwrap()),
        }.into()
    ).await {
        Ok(view) => {
            let mut prof = HashMap::<String, QString>::new();
            prof.insert("did".to_string(), QString::from(view.did.as_str()));
            prof.insert("handle".to_string(), QString::from(view.handle.as_str()));
            prof.insert("displayName".to_string(), QString::from(view.display_name.clone().unwrap_or("".to_string())));
            prof.insert("avatar".to_string(), QString::from(view.avatar.clone().unwrap_or("".to_string())));
            prof.insert("banner".to_string(), QString::from(view.banner.clone().unwrap_or("".to_string())));
            prof.insert("followersCount".to_string(), QString::from(view.followers_count.map_or("".to_string(), |v| v.to_string())));
            prof.insert("followsCount".to_string(), QString::from(view.follows_count.map_or("".to_string(), |v| v.to_string())));
            prof.insert("postsCount".to_string(), QString::from(view.posts_count.map_or("".to_string(), |v| v.to_string())));
            prof.insert("description".to_string(), QString::from(view.description.clone().unwrap_or("".to_string())));
            prof.insert("followingUri".to_string(), QString::from(view.viewer.clone().map_or(
                "".to_string(),
                |vs| vs.following.clone().map_or(
                    "".to_string(),
                    |flw| flw.clone()))));
            Ok(prof)
        }
        Err(_) => Err(BackendError)
    }
}

fn parse_feed_view_post(post: &PostView, reposted_by: &str) -> QVariantMap {
    let mut res = QVariantMap::default();
    let author = &post.author.data;

    let avatar: QString = author.avatar.as_ref().unwrap().as_str().into();
    let handle: QString = author.handle.as_ref().into();
    let display_name: QString = author.display_name.as_ref().unwrap().as_str().into();
    let did: QString = author.did.as_ref().into();
    res.insert("avatar".into(), avatar.into());
    res.insert("authorHandle".into(), handle.into());
    res.insert("authorDisplayName".into(), display_name.into());
    res.insert("authorDid".into(), did.into());

    let repost_count = post.repost_count.unwrap_or(0);
    let quote_count = post.quote_count.unwrap_or(0);
    let quote_and_repost_count: QVariant = (repost_count + quote_count).into();
    res.insert("quoteAndRepostCount".into(), quote_and_repost_count);

    let record = Record::try_from_unknown(post.record.clone()).unwrap_or(Record { text: "".to_string() });
    let text: QString = record.text.as_str().into();
    res.insert("text".into(), text.into());

    let posted_at: QString = post.indexed_at.as_str().into();
    res.insert("postedAt".into(), posted_at.into());

    let reply_count: QVariant = post.reply_count.unwrap_or(0).into();
    res.insert("replyCount".into(), reply_count);

    let like_count: QVariant = post.like_count.unwrap_or(0).into();
    res.insert("likeCount".into(), like_count);

    res.insert("uri".into(), QString::from(post.uri.clone()).into());

    let cid = post.cid.as_ref().to_string();
    res.insert("cid".into(), QString::from(cid).into());

    res.insert("quotePost".into(), QVariant::default());
    res.insert("embed".into(), QVariant::default());
    if let Some(ref embed_ref) = post.embed {
        if let Union::Refs(r) = embed_ref {
            match r {
                PostViewEmbedRefs::AppBskyEmbedRecordView(v) => {
                    let mut quote_post = QVariantMap::default();
                    if let Union::Refs(vr_ref) = &v.record {
                        if let ViewRecordRefs::ViewRecord(vr) = vr_ref {
                            let rec_value = Record::try_from_unknown(vr.value.clone()).unwrap_or(Record { text: "".to_string() });
                            let quote_author = &vr.author.data;
                            let mut quote_embeds = QVariantList::default();
                            if let Some(embeds_item) = vr.embeds.as_ref() {
                                for embed in embeds_item {
                                    let mut quote_embed = QVariantMap::default();
                                    if let Union::Refs(embed_ref) =embed {
                                        if let ViewRecordEmbedsItem::AppBskyEmbedImagesView(images_view) = embed_ref {
                                            let mut image_thumbs = QVariantList::default();
                                            for image in &images_view.images {
                                                image_thumbs.push(QString::from(image.thumb.as_str()).into());
                                            }
                                            quote_embed.insert("type".into(), QString::from("images").into());
                                            quote_embed.insert("thumbs".into(), image_thumbs.into());
                                        }
                                    }
                                    quote_embeds.push(quote_embed.into());
                                }
                            }
                            quote_post.insert("text".into(), QString::from(rec_value.text).into());
                            quote_post.insert("postedAt".into(), QString::from(vr.indexed_at.as_str()).into());
                            quote_post.insert("avatar".into(), QString::from(quote_author.avatar.as_ref().unwrap_or(&"".to_string()).as_str()).into());
                            quote_post.insert("authorHandle".into(), QString::from(quote_author.handle.as_str()).into());
                            quote_post.insert("authorDisplayName".into(), QString::from(quote_author.display_name.as_ref().unwrap_or(&"".to_string()).as_str()).into());
                            quote_post.insert("authorDid".into(), QString::from(quote_author.did.as_str()).into());
                            quote_post.insert("embeds".into(), quote_embeds.into());
                            quote_post.insert("uri".into(), QString::from(vr.uri.clone()).into());

                            res.insert("quotePost".into(), quote_post.into());
                        }
                    }
                },
                PostViewEmbedRefs::AppBskyEmbedImagesView(images_view) => {
                    let mut embed = QVariantMap::default();
                    let mut image_thumbs = QVariantList::default();
                    for image in &images_view.images {
                        image_thumbs.push(QString::from(image.thumb.as_str()).into());
                    }
                    embed.insert("type".into(), QString::from("images").into());
                    embed.insert("thumbs".into(), image_thumbs.into());

                    res.insert("embed".into(), embed.into());
                },
                PostViewEmbedRefs::AppBskyEmbedExternalView(external_view) => {
                    let mut embed = QVariantMap::default();
                    embed.insert("type".into(), QString::from("external").into());
                    embed.insert("uri".into(), QString::from(external_view.external.uri.clone()).into());
                    embed.insert("title".into(), QString::from(external_view.external.title.clone()).into());
                    embed.insert("description".into(), QString::from(external_view.external.description.clone()).into());
                    embed.insert("thumb".into(), QString::from(external_view.external.thumb.clone().unwrap_or("".to_string())).into());

                    res.insert("embed".into(), embed.into());
                },
                PostViewEmbedRefs::AppBskyEmbedVideoView(video_view) => {
                    let mut embed = QVariantMap::default();
                    embed.insert("type".into(), QString::from("video").into());
                    embed.insert("uri".into(), QString::from(video_view.playlist.clone()).into());
                    embed.insert("thumb".into(), QString::from(video_view.thumbnail.clone().unwrap_or("".to_string())).into());

                    res.insert("embed".into(), embed.into());
                },
                _ => {},
            }
        }
    }

    let viewer_like_uri = if let Some(viewer) = &post.viewer {
        if let Some(like) = &viewer.like {
            like.as_str().to_string()
        } else {
            "".to_string()
        }
    } else {
        "".to_string()
    };
    res.insert("viewer_like_uri".into(), QString::from(viewer_like_uri).into());

    res.insert("repostedBy".into(), QString::from(reposted_by).into());

    res
}

#[derive(Default)]
struct State {
    seen_uris: HashSet<String>,
}

#[allow(non_snake_case)]
#[derive(QObject, Default)]
pub struct Backend {
    base: qt_base_class!(trait QObject),
    dataDir: qt_property!(QString; NOTIFY dataDirChanged),
    dataDirChanged: qt_signal!(),
    signInSuccess: qt_signal!(),
    agentInitialized: qt_signal!(did: QString),
    agentInitializationFailed: qt_signal!(),
    timelineFetched: qt_signal!(feeds: QVariantMap),
    timelineFetchFailed: qt_signal!(),
    searchResultFetched: qt_signal!(feeds: QVariantMap),
    searchFailed: qt_signal!(),
    likeSucceeded: qt_signal!(uri: QString, postUri: QString),
    likeFailed: qt_signal!(),
    unlikeSucceeded: qt_signal!(postUri: QString),
    unlikeFailed: qt_signal!(),
    getPostSucceeded: qt_signal!(post: QVariantMap),
    getPostFailed: qt_signal!(),
    getRepliesSucceeded: qt_signal!(replies: QVariantMap),
    getRepliesFailed: qt_signal!(),
    signedIn: qt_signal!(prof: QVariantMap),
    signInFailed: qt_signal!(msg: QString),
    signedOut: qt_signal!(),
    myProfileFetched: qt_signal!(data: QVariantMap),
    userProfileFetched: qt_signal!(data: QVariantMap),
    userProfileFetchFailed: qt_signal!(),
    userPostsFetched: qt_signal!(feeds: QVariantMap, init: bool),
    userPostsFetchFailed: qt_signal!(),
    followSucceeded: qt_signal!(uri: QString),
    followFailed: qt_signal!(),
    unfollowSucceeded: qt_signal!(),
    unfollowFailed: qt_signal!(),
    postSucceeded: qt_signal!(),
    postFailed: qt_signal!(),
    agent: Option<BskyAgent>,
    timeline_state: State,
    search_state: State,
    author_feed_state: State,
    init: qt_method!(fn init(&mut self) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res: (Result<BskyAgent, BackendError>, String)| {
            let (agent, did) = res;
            if let Some(obj) = this.as_pinned() {
                match agent {
                    Ok(agent) => {
                        obj.borrow_mut().agent = Some(agent);
                        obj.borrow().agentInitialized(did.into());
                    }
                    Err(_) => {
                        obj.borrow().agentInitializationFailed();
                    }
                }
            }
        });

        let data_dir = self.dataDir.to_string();
        if self.agent.is_none() {
            std::thread::spawn(move || {
                let (agent, did) = match tokio::runtime::Runtime::new() {
                    Ok(runtime) => runtime.block_on(async {
                        let data_dir_path = data_dir.strip_prefix("file://").unwrap();
                        let path = Path::new(&data_dir_path);
                        match Config::load(&FileStore::new(path.join(Self::CONFIG_FILE_NAME))).await {
                            Ok(conf) => {
                                if let Ok(agent) = BskyAgent::builder()
                                    .config(conf)
                                    .build()
                                    .await {
                                        let did = agent.did().await.unwrap().as_str().to_string();
                                        (Ok(agent), did)
                                } else {
                                    (Err(BackendError), "".to_string())
                                }
                            },
                            Err(_) => {
                                (Err(BackendError), "".to_string())
                            }
                        }
                    }),
                    Err(_) => (Err(BackendError), "".to_string())
                };
                emit((agent, did));
            });
        }
    }),
    signIn: qt_method!(fn signIn(&mut self, username: String, password: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res: Result<(BskyAgent, HashMap<String, QString>), BackendError>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok((agent, prof)) => {
                        obj.borrow_mut().agent = Some(agent);
                        obj.borrow().signedIn(prof.into());
                    }
                    Err(_) => {
                        obj.borrow().signInFailed("".into());
                    }
                }
            }
        });

        let data_dir = self.dataDir.to_string();
        std::thread::spawn(move || {
            let res = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    if let Ok(agent) = BskyAgent::builder().build().await {
                        if let Ok(_) = agent.login(username, password).await {
                            let data_dir_path = data_dir.strip_prefix("file://").unwrap();
                            let path = Path::new(&data_dir_path);
                            let _ = fs::create_dir_all(path);
                            match agent
                                .to_config()
                                .await
                                .save(&FileStore::new(path.join(Self::CONFIG_FILE_NAME)))
                                .await {
                                    Ok(_) => {
                                        let did = agent.did().await.unwrap().as_str().to_string();
                                        match get_profile(&agent, did).await {
                                            Ok(prof) => Ok((agent, prof)),
                                            Err(err) => Err(err)
                                        }
                                    }
                                    Err(_) => {
                                        Err(BackendError)
                                    }
                                }
                        } else {
                            Err(BackendError)
                        }
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError)
            };
            emit(res);
        });
    }),
    signOut: qt_method!(fn signOut(&mut self) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |_| {
            if let Some(obj) = this.as_pinned() {
                obj.borrow_mut().agent = None;
                obj.borrow().signedOut();
            }
        });

        let data_dir = self.dataDir.to_string();
        std::thread::spawn(move || {
            let res = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    let data_dir_path = data_dir.strip_prefix("file://").unwrap();
                    let path = Path::new(&data_dir_path);
                    let _ = fs::remove_file(&path.join(Backend::CONFIG_FILE_NAME));
                    Ok(())
                }),
                Err(_) => Err(BackendError)
            };
            emit(res);
        });
    }),
    resetTimelineState: qt_method!(fn resetTimelineState(&mut self) {
        self.timeline_state = State::default();
    }),
    resetSearchState: qt_method!(fn resetSearchState(&mut self) {
        self.search_state = State::default();
    }),
    resetAuthorFeedState: qt_method!(fn resetAuthorFeedState(&mut self) {
        self.author_feed_state = State::default();
    }),
    getMyProfile: qt_method!(fn getMyProfile(&mut self, did: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res: Result<HashMap<String, QString>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok(prof) => {
                        obj.borrow().myProfileFetched(prof.into());
                    }
                    Err(_) => {
                        obj.borrow().agentInitializationFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let prof = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    get_profile(&agent, did).await
                }),
                Err(_) => Err(BackendError),
            };

            emit(prof);
        });
    }),
    getUserProfile: qt_method!(fn getUserProfile(&mut self, did: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res: Result<HashMap<String, QString>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok(prof) => {
                        obj.borrow().userProfileFetched(prof.into());
                    }
                    Err(_) => {
                        obj.borrow().userProfileFetchFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let prof = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    get_profile(&agent, did).await
                }),
                Err(_) => Err(BackendError),
            };

            emit(prof);
        });
    }),
    getTimeline: qt_method!(fn getTimeline(&mut self, limit: i32, cursor: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res_output_data: Result<get_timeline::OutputData, _>| {
            if let Some(obj) = this.as_pinned() {
                match res_output_data {
                    Ok(output_data) => {
                        let next_cursor = output_data.cursor.unwrap_or("".to_string());
                        let mut data = QVariantList::default();
                        for item in output_data.feed.iter() {
                            if obj.borrow().timeline_state.seen_uris.contains(&item.post.uri) {
                                continue;
                            }
                            obj.borrow_mut().timeline_state.seen_uris.insert(item.post.uri.clone());

                            let reposted_by = match &item.reason {
                                Some(reason) => match reason {
                                    Union::Refs(r) => match r {
                                        FeedViewPostReasonRefs::ReasonRepost(repost) => {
                                            if let Some(ref display_name) = repost.by.display_name {
                                                &display_name
                                            } else {
                                                repost.by.handle.as_str()
                                            }
                                        },
                                        _ => "",
                                    },
                                    _ => "",
                                },
                                None => "",
                            };
                            data.push(parse_feed_view_post(&item.post, reposted_by).into());
                        }
                        let mut res = QVariantMap::default();
                        res.insert("items".into(), data.into());
                        res.insert("nextCursor".into(), QString::from(next_cursor).into());
                        obj.borrow().timelineFetched(res.into());
                    },
                    Err(_) => {
                        obj.borrow().timelineFetchFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        let limit = match u8::try_from(limit) {
            Ok(v) => v,
            Err(_) => 0,
        };
        std::thread::spawn(move || {
            let feeds = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    let limit = LimitedNonZeroU8::try_from(limit).unwrap();
                    let cursor = if cursor.len() > 0 {
                        Some(cursor)
                    } else {
                        None
                    };
                    Ok(agent.api.app.bsky.feed.get_timeline(
                        get_timeline::ParametersData {
                            algorithm: None,
                            cursor: cursor,
                            limit: Some(limit),
                        }.into()
                    ).await.unwrap().data)
                }),
                Err(_) => Err(BackendError),
            };

            emit(feeds);
        });
    }),
    getPost: qt_method!(fn getPost(&mut self, uri: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res_data: Result<QVariantMap, _>| {
            if let Some(obj) = this.as_pinned() {
                match res_data {
                    Ok(post) => {
                        obj.borrow().getPostSucceeded(post);
                    },
                    Err(_) => {
                        obj.borrow().getPostFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let post = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    if let Ok(output_data) = &agent.api.app.bsky.feed.get_posts(
                        get_posts::ParametersData {
                            uris: vec![uri],
                        }.into()
                    ).await {
                        if output_data.posts.len() == 0 {
                            Err(BackendError)
                        } else {
                            let post = &output_data.posts[0];
                            Ok(parse_feed_view_post(post, ""))
                        }
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError),
            };

            emit(post);
        });
    }),
    getReplies: qt_method!(fn getReplies(&mut self, uri: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res_data: Result<Vec<Union<ThreadViewPostRepliesItem>>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res_data {
                    Ok(replies) => {
                        let mut data = QVariantList::default();
                        for item in replies.iter() {
                            if let Union::Refs(ThreadViewPostRepliesItem::ThreadViewPost(item)) = item {
                                data.push(parse_feed_view_post(&item.post, "").into());
                            }
                        }
                        let mut res = QVariantMap::default();
                        res.insert("items".into(), data.into());
                        obj.borrow().getRepliesSucceeded(res.into());
                    },
                    Err(_) => {
                        obj.borrow().getRepliesFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let replies = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    if let Union::Refs(get_post_thread::OutputThreadRefs::AppBskyFeedDefsThreadViewPost(thread_view)) = &agent.api.app.bsky.feed.get_post_thread(
                        get_post_thread::ParametersData {
                            depth: None,
                            parent_height: None,
                            uri: uri,
                        }.into()
                    ).await.unwrap().thread {
                        if let Some(rep) = &thread_view.replies {
                            Ok(rep.clone())
                        } else {
                            Err(BackendError)
                        }
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError),
            };

            emit(replies);
        });
    }),
    likePost: qt_method!(fn likePost(&mut self, uri: String, cid: String) {
        let this = QPointer::from(&*self);
        let post_uri = uri.clone();
        let emit = queued_callback(move |res: Result<Object<create_record::OutputData>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok(output_data) => {
                        obj.borrow().likeSucceeded(QString::from(output_data.uri.clone()), QString::from(post_uri.clone()));
                    }
                    Err(_) => {
                        obj.borrow().likeFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let res = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    let subject = Object::<strong_ref::MainData>::from(
                        strong_ref::MainData {
                            uri: uri.clone(),
                            cid: Cid::from_str(&cid).unwrap().clone(),
                        }
                    );
                    let record = like::RecordData {
                        subject,
                        created_at: Datetime::now(),
                        via: None,
                    };
                    if let Ok(output_data) = agent.create_record(record).await {
                        Ok(output_data)
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError),
            };

            emit(res);
        });
    }),
    unlikePost: qt_method!(fn unlikePost(&mut self, uri: String) {
        let this = QPointer::from(&*self);
        let post_uri = uri.clone();
        let emit = queued_callback(move |res: Result<Object<delete_record::OutputData>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok(_) => {
                        obj.borrow().unlikeSucceeded(QString::from(post_uri.clone()));
                    }
                    Err(_) => {
                        obj.borrow().unlikeFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let res = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    if let Ok(output_data) = agent.delete_record(&uri).await {
                        Ok(output_data)
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError),
            };

            emit(res);
        });
    }),
    searchPosts: qt_method!(fn searchPosts(&mut self, query: String, limit: i32, cursor: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res_output_data: Result<search_posts::OutputData, _>| {
            if let Some(obj) = this.as_pinned() {
                match res_output_data {
                    Ok(output_data) => {
                        let next_cursor = output_data.cursor.unwrap_or("".to_string());
                        let mut data = QVariantList::default();
                        for item in output_data.posts.iter() {
                            if obj.borrow().search_state.seen_uris.contains(&item.uri) {
                                continue;
                            }
                            obj.borrow_mut().search_state.seen_uris.insert(item.uri.clone());

                            data.push(parse_feed_view_post(&item, "").into());
                        }
                        let mut res = QVariantMap::default();
                        res.insert("items".into(), data.into());
                        res.insert("nextCursor".into(), QString::from(next_cursor).into());
                        obj.borrow().searchResultFetched(res.into());
                    },
                    Err(_) => {
                        obj.borrow().searchFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        let limit = match u8::try_from(limit) {
            Ok(v) => v,
            Err(_) => 0,
        };
        std::thread::spawn(move || {
            let feeds = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    let limit = LimitedNonZeroU8::try_from(limit).unwrap();
                    let cursor = if cursor.len() > 0 {
                        Some(cursor)
                    } else {
                        None
                    };
                    Ok(agent.api.app.bsky.feed.search_posts(
                        search_posts::ParametersData {
                            q: query,
                            cursor: cursor,
                            limit: Some(limit),
                            author: None,
                            domain: None,
                            lang: None,
                            mentions: None,
                            since: None,
                            until: None,
                            sort: None,
                            tag: None,
                            url: None,
                        }.into()
                    ).await.unwrap().data)
                }),
                Err(_) => Err(BackendError),
            };

            emit(feeds);
        });
    }),
    getUserPosts: qt_method!(fn getUserPosts(&mut self, did: String, limit: i32, cursor: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res_output_data: Result<(get_author_feed::OutputData, bool), _>| {
            if let Some(obj) = this.as_pinned() {
                match res_output_data {
                    Ok((output_data, init)) => {
                        let next_cursor = output_data.cursor.unwrap_or("".to_string());
                        let mut data = QVariantList::default();
                        for item in output_data.feed.iter() {
                            if obj.borrow().author_feed_state.seen_uris.contains(&item.post.uri) {
                                continue;
                            }
                            obj.borrow_mut().author_feed_state.seen_uris.insert(item.post.uri.clone());

                            let reposted_by = match &item.reason {
                                Some(reason) => match reason {
                                    Union::Refs(r) => match r {
                                        FeedViewPostReasonRefs::ReasonRepost(repost) => {
                                            if let Some(ref display_name) = repost.by.display_name {
                                                &display_name
                                            } else {
                                                repost.by.handle.as_str()
                                            }
                                        },
                                        _ => "",
                                    },
                                    _ => "",
                                },
                                None => "",
                            };
                            data.push(parse_feed_view_post(&item.post, reposted_by).into());
                        }
                        let mut res = QVariantMap::default();
                        res.insert("items".into(), data.into());
                        res.insert("nextCursor".into(), QString::from(next_cursor).into());
                        obj.borrow().userPostsFetched(res.into(), init);
                    },
                    Err(_) => {
                        obj.borrow().userPostsFetchFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        let limit = match u8::try_from(limit) {
            Ok(v) => v,
            Err(_) => 0,
        };
        std::thread::spawn(move || {
            let feeds = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    let limit = LimitedNonZeroU8::try_from(limit).unwrap();
                    let cursor = if cursor.len() > 0 {
                        Some(cursor)
                    } else {
                        None
                    };
                    let init = cursor.is_none();
                    Ok((agent.api.app.bsky.feed.get_author_feed(
                        get_author_feed::ParametersData {
                            actor: AtIdentifier::Did(Did::new(did).unwrap()),
                            cursor: cursor,
                            limit: Some(limit),
                            filter: None,
                            include_pins: None,
                        }.into()
                    ).await.unwrap().data, init))
                }),
                Err(_) => Err(BackendError),
            };

            emit(feeds);
        });
    }),
    followUser: qt_method!(fn followUser(&mut self, did: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res: Result<Object<create_record::OutputData>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok(output_data) => {
                        obj.borrow().followSucceeded(QString::from(output_data.uri.clone()));
                    }
                    Err(_) => {
                        obj.borrow().followFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let res = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    let record = follow::RecordData {
                        subject: Did::new(did).unwrap(),
                        created_at: Datetime::now(),
                    };
                    if let Ok(output_data) = agent.create_record(record).await {
                        Ok(output_data)
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError),
            };

            emit(res);
        });
    }),
    unfollowUser: qt_method!(fn unfollowUser(&mut self, uri: String) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res: Result<Object<delete_record::OutputData>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok(_) => {
                        obj.borrow().unfollowSucceeded();
                    }
                    Err(_) => {
                        obj.borrow().unfollowFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let res = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    if let Ok(output_data) = agent.delete_record(&uri).await {
                        Ok(output_data)
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError),
            };

            emit(res);
        });
    }),
    post: qt_method!(fn post(&mut self, text: String, image_urls: QVariantList) {
        let this = QPointer::from(&*self);
        let emit = queued_callback(move |res: Result<Object<create_record::OutputData>, _>| {
            if let Some(obj) = this.as_pinned() {
                match res {
                    Ok(_) => {
                        obj.borrow().postSucceeded();
                    }
                    Err(_) => {
                        obj.borrow().postFailed();
                    }
                }
            }
        });

        let agent = self.agent.as_ref().unwrap().clone();
        std::thread::spawn(move || {
            let res = match tokio::runtime::Runtime::new() {
                Ok(runtime) => runtime.block_on(async {
                    let futures = image_urls.into_iter().map(async |image_url| {
                        let image_url_str = image_url.to_qstring().to_string();
                        let url = Url::parse(&image_url_str).unwrap();
                        let path = url.path();
                        let image_bytes = fs::read(path).unwrap();
                        let blob_ref = agent.api.com.atproto.repo.upload_blob(image_bytes).await.unwrap().blob.clone();
                        Object::from(images::ImageData {
                            alt: "".to_string(),
                            aspect_ratio: None,
                            image: blob_ref,
                        })
                    });
                    let blob_refs = join_all(futures).await;
                    let embed = if blob_refs.len() > 0 {
                        Some(Union::Refs(
                            post::RecordEmbedRefs::AppBskyEmbedImagesMain(
                                Box::new(
                                    Object::from(
                                        images::MainData {
                                            images: blob_refs,
                                        }
                                    )
                                )
                            )
                        ))
                    } else {
                        None
                    };
                    let record = post::RecordData {
                        text: text,
                        embed: embed,
                        created_at: Datetime::now(),
                        entities: None,
                        facets: None,
                        labels: None,
                        langs: None,
                        reply: None,
                        tags: None,
                    };
                    if let Ok(output_data) = agent.create_record(record).await {
                        Ok(output_data)
                    } else {
                        Err(BackendError)
                    }
                }),
                Err(_) => Err(BackendError),
            };

            emit(res);
        });
    }),
}

impl Backend {
    const CONFIG_FILE_NAME: &str = "config.json";
}
