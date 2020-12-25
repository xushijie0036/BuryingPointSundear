import Foundation
import CoreLocation
import UIKit

enum BuryingPointgestureEnum :Int {
    case LeftSlide//左滑
    case RightSlide//右滑
    case UpSlip//上滑
    case DownwardSlide//下滑
    case LeftAndRightSlide//左右滑动
    case UpAndDownwardSlide//上下滑动
    case slide//滑动
    case narrow//缩小
    case enlarge//放大
    case zoom//缩放
    case tapAction//点击
}

enum BuryingPointEventAction :Int {
    case TYPE_PAGE_URL = 1//操作是指向正在跟踪的网站上的页面的URL
    case TYPE_OUTLINK//操作是正在跟踪的网站上链接的URL。一位访客点击了一下。
    case TYPE_DOWNLOAD//操作是从正在跟踪的网站下载的文件的URL。
    case TYPE_PAGE_TITLE//操作是正在跟踪的网站上某个页面的页面标题。
    case TYPE_ECOMMERCE_ITEM_SKU//操作是网站上销售的电子商务项目的SKU。
    case TYPE_ECOMMERCE_ITEM_NAME//操作是网站上销售的电子商务项目的名称。
    case TYPE_ECOMMERCE_ITEM_CATEGORY//操作是网站上使用的电子商务项目类别的名称。
    case TYPE_SITE_SEARCH//操作类型是站点搜索操作。
    case TYPE_EVENT_CATEGORY//操作是事件类别（请参阅跟踪事件用户指南）
    case TYPE_EVENT_ACTION//操作是事件类别
    case TYPE_EVENT_NAME//操作是事件名称
    case TYPE_CONTENT_NAME//操作是内容名称（请参阅内容跟踪用户指南和开发人员指南）
    case TYPE_CONTENT_PIECE//操作是内容块
    case TYPE_CONTENT_TARGET//操作是内容目标
    case TYPE_CONTENT_INTERACTION//操作是内容交互
    
}



/// The BuryingPoint Tracker is a Swift framework to send analytics to the BuryingPoint server.  BuryingPoint Tracker是一个快速框架，用于将分析发送到BuryingPoint服务器。
///
/// ## Basic Usage  基本用法
/// * Use the track methods to track your views, events and more.  使用跟踪方法跟踪您的视图，事件等。
final public class BuryingPointSundear: NSObject,CLLocationManagerDelegate {
    
    
    static public let sharedInstance: BuryingPointSundear = {
        let queue = UserDefaultsQueue(UserDefaults.standard, autoSave: true)
        let dispatcher = URLSessionDispatcher(baseURL: URL(string: "http://statistics-ccg.sundear.com.cn/api/statistics")!)
        let buryingPoint = BuryingPointSundear(siteId: "23", queue: queue, dispatcher: dispatcher)
        buryingPoint.logger = DefaultLogger(minLevel: .verbose)
        buryingPoint.migrateFromFourPointFourSharedInstance()
        return buryingPoint
    }()
    
    private func migrateFromFourPointFourSharedInstance() {
        guard !UserDefaults.standard.bool(forKey: "migratedFromFourPointFourSharedInstance") else { return }
        copyFromOldSharedInstance()
        UserDefaults.standard.set(true, forKey: "migratedFromFourPointFourSharedInstance")
    }

    
    /// Defines if the user opted out of tracking. When set to true, every event  定义用户是否选择退出跟踪。设置为true时，每个事件
    /// will be discarded immediately. This property is persisted between app launches.  将立即丢弃。此属性在应用程序启动之间持续存在。
    @objc public var isOptedOut: Bool {
        get {
            return buryingPointUserDefaults.optOut
        }
        set {
            buryingPointUserDefaults.optOut = newValue
        }
    }
    
    /// Will be used to associate all future events with a given userID. This property   将用于将所有未来事件与给定的用户名相关联。这个属性
    /// is persisted between app launches.    在应用程序发布之间持续存在。
    @objc public var userId: String? {
        get {
            return buryingPointUserDefaults.visitorUserId
        }
        set {
            buryingPointUserDefaults.visitorUserId = newValue
            visitor = Visitor.current(in: buryingPointUserDefaults)
        }
    }
    
    @available(*, deprecated, message: "use userId instead")
    @objc public var visitorId: String? {
        get {
            return userId
        }
        set {
            userId = newValue
        }
    }
    
    
    
    /// Will be used to associate all future events with a given visitorId / cid. This property  将用于将所有未来事件与给定的访问/cid相关联。这个属性
    /// is persisted between app launches. 在应用程序发布之间持续存在
    /// The `forcedVisitorId` can only be a 16 character long hexadecimal string. Setting an invalid  `forcedVisitorId''只能是16个字符长的十六位小数字符串。设置无效
    /// string will have no effect.  字符串将无效。
    @objc public var forcedVisitorId: String? {
        get {
            return buryingPointUserDefaults.forcedVisitorId
        }
        set {
            logger.debug("Setting the forcedVisitorId to \(forcedVisitorId ?? "nil")")
            if let newValue = newValue {
                let isValidString = UInt64(newValue, radix: 16) != nil && newValue.count == 16
                if isValidString {
                    buryingPointUserDefaults.forcedVisitorId = newValue
                } else {
                    logger.error("forcedVisitorId is invalid. It must be a 16 character long hex string.")
                    logger.error("forcedVisitorId is still \(forcedVisitorId ?? "nil")")
                }
            } else {
                buryingPointUserDefaults.forcedVisitorId = nil
            }
            visitor = Visitor.current(in: buryingPointUserDefaults)
        }
    }
    
    internal var buryingPointUserDefaults: BuryingPointUserDefaults
    private let dispatcher: Dispatcher
    private var queue: Queue
    internal let siteId: String
    
     //操作分类
    var idactionCategory : String?
    
    //操作值
    var idactionAction : String?
    

    internal var dimensions: [CustomDimension] = []
    
    internal var customVariables: [CustomVariable] = []
    
    /// This logger is used to perform logging of all sorts of BuryingPoint related information.该记录器用于执行各种埋藏点相关信息的记录。
    /// Per default it is a `DefaultLogger` with a `minLevel` of `LogLevel.warning`. You can   按照默认值，它是一个“默认记录器”，其“minLevel”为`LogLevel.warning`. 你可以
    /// set your own Logger with a custom `minLevel` or a complete custom logging mechanism.  使用自定义的“minLevel”或完整的自定义日志记录机制设置自己的记录器
    @objc public var logger: Logger = DefaultLogger(minLevel: .warning)
    
    /// The `contentBase` is used to build the url of an Event, if the Event hasn't got a url set.如果事件没有url集，“contentBase”用于构建事件的url。
    /// This autogenerated url will then have the format <contentBase>/<actions>.然后，此自动生成的url将具有格式<contentBase>/<actions>。
    /// Per default the `contentBase` is http://<Application Bundle Name>. 默认情况下，“contentBase”是http://<Application Bundle Name>。
    /// Set the `contentBase` to nil, if you don't want to auto generate a url.  /如果您不想自动生成url，请将“contentBase”设置为零。
    @objc public var contentBase: URL?
    
    internal static var _sharedInstance: BuryingPointSundear?
    
    /// Create and Configure a new Tracker  创建和配置新的跟踪器
    ///
    /// - Parameters:
    ///   - siteId: The unique site id generated by the server when a new site was created.  创建新站点时由服务器生成的唯一站点id。
    ///   - queue: The queue to use to store all analytics until it is dispatched to the server.  用于存储所有分析的队列，直到将其发送到服务器为止。
    ///   - dispatcher: The dispatcher to use to transmit all analytics to the server. 用于将所有分析传输到服务器的调度程序。
    required public init(siteId: String, queue: Queue, dispatcher: Dispatcher) {
        self.siteId = siteId
        self.queue = queue
        self.dispatcher = dispatcher
        self.contentBase = URL(string: "http://\(Application.makeCurrentApplication().bundleIdentifier ?? "unknown")")
        self.buryingPointUserDefaults = BuryingPointUserDefaults(suiteName: "\(siteId)\(dispatcher.baseURL.absoluteString)")
        self.visitor = Visitor.current(in: buryingPointUserDefaults)
        self.session = Session.current(in: buryingPointUserDefaults)
        super.init()
        startNewSession()
        startDispatchTimer()
    }
    
    /// Create and Configure a new Tracker  创建和配置新的跟踪器
    ///
    /// A volatile memory queue will be used to store the analytics data. All not transmitted data will be lost when the application gets terminated.易失记忆队列将用于存储分析数据。当应用程序终止时，所有未传输的数据都将丢失。
    /// The URLSessionDispatcher will be used to transmit the data to the server.URLSessionDispatcher将用于将数据传输到服务器。
    ///
    /// - Parameters:
    ///   - siteId: The unique site id generated by the server when a new site was created.创建新站点时由服务器生成的唯一站点id。
    ///   - baseURL: The url of the BuryingPoint server. This url has to end in `sundear.php` or `buryingPoint.php`. BuryingPoint服务器的url。此url必须以`sundear.php`或者`buryingPoint.php`.
    ///   - userAgent: An optional parameter for custom user agent.自定义用户代理的可选参数。
    @objc convenience public init(siteId: String, baseURL: URL, userAgent: String? = nil) {
        let validSuffix = baseURL.absoluteString.hasSuffix("sundear.php") ||
            baseURL.absoluteString.hasSuffix("buryingPoint.php")
        assert(validSuffix, "The baseURL is expected to end in sundear.php or buryingPoint.php")
        
        let queue = MemoryQueue()
        let dispatcher = URLSessionDispatcher(baseURL: baseURL, userAgent: userAgent)
        self.init(siteId: siteId, queue: queue, dispatcher: dispatcher)
    }
    
    // MARK  设置触发条数，默认 100 条
    @objc public var flushBulkSize = 100;
    
    internal func queue(event: Event) {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.queue(event: event)
            }
            return
        }
        guard !isOptedOut else { return }
        logger.verbose("Queued event: \(event)")
        queue.enqueue(event: event)
        nextEventStartsANewSession = false
        
        print(self.queue.eventCount)
        if self.queue.eventCount >= flushBulkSize {
            self.dispatch()
        }
    }
    

    /**
    初始化系统的一些方法
     */
    @objc public func deviceAndApplication(){
        let application = Application.makeCurrentApplication()
        let device = Device.makeCurrentDevice()
        setCustomVariable(withIndex: 2, name: "config_device_brand", value: device.platform);
        setCustomVariable(withIndex: 3, name: "config_os", value: device.operatingSystem)
        setCustomVariable(withIndex: 4, name: "config_os_version", value: device.osVersion);
        setCustomVariable(withIndex: 5,  name: "bundleShortVersion", value:application.bundleShortVersion ?? "unknown")
    }

    ///输入用户的手机号
    @objc public func BuryingPointPhoneNumber(phoneNumber: String){
        setCustomVariable(withIndex: 6, name: "phoneNumber", value: phoneNumber)
    }
    
    
    /**
     进入界面
     */
    @objc public func BuryingPoinStartVisitIdaction(){
        

        UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "visitCurrentName")
        UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "visitCurrentUrl")
        
        let visitEntryIdactionTitle = UserDefaults.standard.object(forKey: "visitEntryIdactionName") as? String ?? ""
        let visitEntryIdactionUrl = UserDefaults.standard.object(forKey: "visitEntryIdactionUrl")  as? String ?? ""
        
        let visitExitIdactionTitle = UserDefaults.standard.object(forKey: "visitExitIdactionName") as? String ?? ""
        let visitExitIdactionUrl = UserDefaults.standard.object(forKey: "visitExitIdactionUrl")  as? String ?? ""
        let visitCurrentTitle = UserDefaults.standard.object(forKey: "visitCurrentName") as? String ?? ""
        let visitCurrentUrl = UserDefaults.standard.object(forKey: "visitCurrentUrl")  as? String ?? ""
        
        track(view: ["visit_entry_idaction_name",String(visitEntryIdactionTitle),"visit_entry_idaction_url",String(visitEntryIdactionUrl),"visit_exit_idaction_name",String(visitExitIdactionTitle),"visit_exit_idaction_url",String(visitExitIdactionUrl),"visit_current_name",String(visitCurrentTitle) ,"visit_current_url",String(visitCurrentUrl),"startView","start"])
        
        if (visitEntryIdactionUrl == "") {
            UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "visitEntryIdactionName")
            UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "visitEntryIdactionUrl")
        }
        UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "visitExitIdactionName")
        UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "visitExitIdactionUrl")
       
    }
    
    /**
     退出界面
     */
    @objc public func BuryingPoinEndVisitIdaction(){
        UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "visitCurrentName")
        UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "visitCurrentUrl")
        
        let visitEntryIdactionTitle = UserDefaults.standard.object(forKey: "visitEntryIdactionName") as? String ?? ""
        let visitEntryIdactionUrl = UserDefaults.standard.object(forKey: "visitEntryIdactionUrl")  as? String ?? ""
        
        let visitExitIdactionTitle = UserDefaults.standard.object(forKey: "visitExitIdactionName") as? String ?? ""
        let visitExitIdactionUrl = UserDefaults.standard.object(forKey: "visitExitIdactionUrl")  as? String ?? ""
        let visitCurrentTitle = UserDefaults.standard.object(forKey: "visitCurrentName") as? String ?? ""
        let visitCurrentUrl = UserDefaults.standard.object(forKey: "visitCurrentUrl")  as? String ?? ""
        
        track(view: ["visit_entry_idaction_name",String(visitEntryIdactionTitle),"visit_entry_idaction_url",String(visitEntryIdactionUrl),"visit_exit_idaction_name",String(visitExitIdactionTitle),"visit_exit_idaction_url",String(visitExitIdactionUrl),"visit_current_name",String(visitCurrentTitle) ,"visit_current_url",String(visitCurrentUrl),"endView","end"])
        
        if (visitEntryIdactionUrl == "") {
            UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "visitEntryIdactionName")
            UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "visitEntryIdactionUrl")
        }
        UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "visitExitIdactionName")
        UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "visitExitIdactionUrl")
    }
    
    /**
     跳转界面所使用的关键词与名称
     refererKeyword :跳转过来的后进来所使用的关键字
     refererName:跳转过来的名称
     */
    
    @objc public func BuryingPoinRefererKeywordAndName(refererKeyword: String,refererName: String){
        UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "visitCurrentName")
        UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "visitCurrentUrl")
        let visitCurrentTitle = UserDefaults.standard.object(forKey: "visitCurrentName") as? String ?? ""
        let visitCurrentUrl = UserDefaults.standard.object(forKey: "visitCurrentUrl")  as? String ?? ""
        track(view: ["referer_keyword",refererKeyword,"referer_name",refererName,"visit_current_name",String(visitCurrentTitle) ,"visit_current_url",String(visitCurrentUrl)])
    }
    
  
    // MARK: dispatching  标记：调度
    
    private let numberOfEventsDispatchedAtOnce = 20
    private(set) var isDispatching = false
    
    var locationManager : CLLocationManager = CLLocationManager()
    
    @objc public func obtainLocation(){
        let authorizationStatus: CLAuthorizationStatus = CLLocationManager.authorizationStatus()

           if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
           }
           self.locationManager.delegate = self
           self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
           self.locationManager.distanceFilter = 50
           self.locationManager.startUpdatingLocation()
    }
    
    
    @objc public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            
        let currLocation:CLLocation = locations.last!
        let longitude = "\(currLocation.coordinate.longitude)"
            //获取纬度
        let latitude = "\(currLocation.coordinate.latitude)"
        setCustomVariable(withIndex: 0, name: "location_longitude", value: longitude)
        setCustomVariable(withIndex: 1, name: "location_latitude", value: latitude)
        
    }
    

    
    /// Manually start the dispatching process. You might want to call this method in AppDelegates `applicationDidEnterBackground` to transmit all data 手动启动调度过程。您可能想在appdelicates`applicationdifferbackground'中调用此方法来传输所有数据
    /// whenever the user leaves the application.每当用户离开应用程序时。
    @objc public func dispatch() {
        guard !isDispatching else {
            logger.verbose("BuryingPointSundear is already dispatching.")
            return
        }
        guard queue.eventCount > 0 else {
            logger.info("No need to dispatch. Dispatch queue is empty.")
            startDispatchTimer()
            return
        }
        logger.info("Start dispatching events")
        isDispatching = true
        dispatchBatch()
    }
    
    private func dispatchBatch() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.dispatchBatch()
            }
            return
        }
        queue.first(limit: numberOfEventsDispatchedAtOnce) { [weak self] events in
            guard let self = self else { return }
            guard events.count > 0 else {
                // there are no more events queued, finish dispatching
                self.isDispatching = false
                self.startDispatchTimer()
                self.logger.info("Finished dispatching events")
                return
            }
            self.dispatcher.send(events: events, success: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.queue.remove(events: events, completion: {
                        self.logger.info("Dispatched batch of \(events.count) events.")
                        DispatchQueue.main.async {
                            self.dispatchBatch()
                        }
                    })
                }
            }, failure: { [weak self] error in
                guard let self = self else { return }
                self.isDispatching = false
                self.startDispatchTimer()
                self.logger.warning("Failed dispatching events with error \(error)")
            })
        }
    }
    
    
    // MARK: dispatch timer 调度计时器
    
    @objc public var dispatchInterval: TimeInterval = 30.0 {
        didSet {
            startDispatchTimer()
        }
    }
    private var dispatchTimer: Timer?
    
    private func startDispatchTimer() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.startDispatchTimer()
            }
            return
        }
        guard dispatchInterval > 0  else { return } // Discussion: Do we want the possibility to dispatch synchronous? That than would be dispatchInterval = 0 我们是否希望同步调度的可能性？那将是dispatchInterval 0
        if let dispatchTimer = dispatchTimer {
            dispatchTimer.invalidate()
            self.dispatchTimer = nil
        }
        // Dispatchin asynchronous here to break the retain cycle   Dispatchin异步这里打破保留周期
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dispatchTimer = Timer.scheduledTimer(timeInterval: self.dispatchInterval, target: self, selector: #selector(self.dispatch), userInfo: nil, repeats: false)
        }
    }
    
    internal var visitor: Visitor
    internal var session: Session
    internal var nextEventStartsANewSession = true

    internal var campaignName: String? = nil
    internal var campaignKeyword: String? = nil
    
    /// Adds the name and keyword for the current campaign. 为当前活动添加名称和关键字。
    /// This is usually very helpfull if you use deeplinks into your app.  如果您在应用程序中使用deeplinks，这通常非常有用。
    ///
    /// More information on campaigns: [https://buryingPoint.org/docs/tracking-campaigns/](https://buryingPoint.org/docs/tracking-campaigns/)
    ///
    /// - Parameters:
    ///   - name: The name of the campaign. 活动名称。
    ///   - keyword: The keyword of the campaign.  活动的关键字。
    @objc public func trackCampaign(name: String?, keyword: String?) {
        campaignName = name
        campaignKeyword = keyword
    }
    
    /// There are several ways to track content impressions and interactions manually, semi-automatically and automatically. Please be aware that content impressions will be tracked using bulk tracking which will always send a POST request, even if  GET is configured which is the default. For more details have a look at the in-depth guide to Content Tracking. 有几种方法可以手动，半自动和自动跟踪内容印象和交互。请注意，内容印象将使用批量跟踪进行跟踪，即使GET配置为默认值，它也会始终发送帖子请求。有关更多详细信息，请参阅内容跟踪的深入指南。
    /// More information on content: [https://buryingPoint.org/docs/content-tracking/](https://buryingPoint.org/docs/content-tracking/)
    ///
    /// - Parameters:
    ///   - name: The name of the content. For instance 'Ad Foo Bar'  内容的名称。例如'Ad Foo Bar'
    ///   - piece: The actual content piece. For instance the path to an image, video, audio, any text   实际内容片段。例如，图像，视频，音频，任何文本的路径
    ///   - target: The target of the content. For instance the URL of a landing page  内容的目标。例如着陆页的URL
    ///   - interaction: The name of the interaction with the content. For instance a 'click'  与内容交互的名称。例如，“点击”
    @objc public func trackContentImpression(name: String, piece: String?, target: String?) {
        track(Event(tracker: self, action: [], contentName: name, contentPiece: piece, contentTarget: target, idactionCategory:nil, idactionAction: nil))
    }
    @objc public func trackContentInteraction(name: String, interaction: String, piece: String?, target: String?) {
        track(Event(tracker: self, action: [], contentName: name, contentInteraction: interaction, contentPiece: piece, contentTarget: target, idactionCategory:nil, idactionAction: nil))
    }
    
    /**
     action 的值为以下含义
     1:操作是指向正在跟踪的网站上的页面的URL。
     2:操作是正在跟踪的网站上链接的URL。一位访客点击了一下。
     3:操作是从正在跟踪的网站下载的文件的URL。
     4:操作是正在跟踪的网站上某个页面的页面标题。
     5:操作是网站上销售的电子商务项目的SKU。
     6:操作是网站上销售的电子商务项目的名称。
     7:操作是网站上使用的电子商务项目类别的名称。
     8:操作类型是站点搜索操作。
     9:操作是事件类别（请参阅跟踪事件用户指南）
     10:操作是事件类别
     11:操作是事件名称
     12:操作是内容名称
     13:操作是内容块
     14:操作是内容目标
     15:操作是内容交互
     
     如果action为9的时候 gesture需要填写以下的值 否则gesture 可以随意输入100
     gesture  手势：滑动和缩小或者放大
     左滑 0   右滑 1   上滑 2    下滑 3    左右滑4   上下滑 5  滑动 6    缩小 7    放大 8     缩放 9   点击10
     
     
     contantName  点击按钮的名称，或者搜索事件的关键词，可以填空
     */
    
    public func BuryingPointTrackContentInteraction(action: Int, gesture: Int, contantName: String) {
       
            let ges = BuryingPointEventAction.init(rawValue: action)
        var actionString :String?
        var gestureString :String?
            switch ges {
            case .some(.TYPE_PAGE_URL):
                actionString = "TYPE_PAGE_URL";
            case .some(.TYPE_OUTLINK):
                actionString = "TYPE_OUTLINK";
            case .some(.TYPE_DOWNLOAD):
                actionString = "TYPE_DOWNLOAD";
            case .some(.TYPE_PAGE_TITLE):
                actionString = "TYPE_PAGE_TITLE";
            case .some(.TYPE_ECOMMERCE_ITEM_SKU):
                actionString = "TYPE_ECOMMERCE_ITEM_SKU";
            case .some(.TYPE_ECOMMERCE_ITEM_NAME):
                actionString = "TYPE_ECOMMERCE_ITEM_NAME";
            case .some(.TYPE_ECOMMERCE_ITEM_CATEGORY):
                actionString = "TYPE_ECOMMERCE_ITEM_CATEGORY";
            case .some(.TYPE_SITE_SEARCH):
                actionString = "TYPE_SITE_SEARCH";
            case .some(.TYPE_EVENT_CATEGORY):
                let gesture = BuryingPointgestureEnum.init(rawValue: gesture)
                switch gesture {
                case .some(.LeftSlide):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "LeftSlide"
                case .some(.RightSlide):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "RightSlide"
                case .some(.UpSlip):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "UpSlip"
                case .some(.DownwardSlide):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "DownwardSlide"
                case .some(.LeftAndRightSlide):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "LeftAndRightSlide"
                case .some(.UpAndDownwardSlide):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "UpAndDownwardSlide"
                case .some(.slide):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "slide"
                case .some(.narrow):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "narrow"
                case .some(.enlarge):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "enlarge"
                case .some(.zoom):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "zoom"
                case .some(.tapAction):
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "tapAction"
                case .none:
                    actionString = "TYPE_EVENT_CATEGORY"
                    gestureString = "non-existent"
                }
            case .some(.TYPE_EVENT_ACTION):
                actionString = "TYPE_EVENT_ACTION"
            case .some(.TYPE_EVENT_NAME):
                actionString = "TYPE_EVENT_NAME"
            case .some(.TYPE_CONTENT_NAME):
                actionString = "TYPE_CONTENT_NAME"
            case .some(.TYPE_CONTENT_PIECE):
                actionString = "TYPE_CONTENT_PIECE"
            case .some(.TYPE_CONTENT_TARGET):
                actionString = "TYPE_CONTENT_TARGET"
            case .some(.TYPE_CONTENT_INTERACTION):
                actionString = "TYPE_CONTENT_INTERACTION"
            case .none:
                actionString = "non-existent"
            }
        
        let navigation_title = UserDefaults.standard.object(forKey: "BuryingPoint_navigation_title")
        let navigation_name = UserDefaults.standard.object(forKey: "BuryingPoint_navigation_name")
        track(Event(tracker: self, action: [contantName], contentName: self.currentViewController()?.navigationItem.title, contentInteraction: navigation_title as? String, contentPiece: navigation_name as? String, contentTarget: "\(String(describing: self.currentViewController().self))", idactionCategory:gestureString, idactionAction: actionString))
        UserDefaults.standard.set(self.currentViewController()?.navigationItem.title, forKey: "BuryingPoint_navigation_title")
        UserDefaults.standard.set("\(String(describing: self.currentViewController().self))", forKey: "BuryingPoint_navigation_name")
    }

    
    
    
    func currentViewController() -> (UIViewController?) {
        var window = UIApplication.shared.keyWindow
        if window?.windowLevel != UIWindow.Level.normal{
            let windows = UIApplication.shared.windows
            for  windowTemp in windows{
                if windowTemp.windowLevel == UIWindow.Level.normal{
                    window = windowTemp
                    break
                }
            }
        }
        let vc = window?.rootViewController
        return currentViewController(vc)
    }
    
    
    func currentViewController(_ vc :UIViewController?) -> UIViewController? {
        if vc == nil {
            return nil
        }
        if let presentVC = vc?.presentedViewController {
            return currentViewController(presentVC)
        }
        else if let tabVC = vc as? UITabBarController {
            if let selectVC = tabVC.selectedViewController {
                return currentViewController(selectVC)
            }
            return nil
        }
        else if let naiVC = vc as? UINavigationController {
            return currentViewController(naiVC.visibleViewController)
        }
        else {
            return vc
        }
    }
}

extension BuryingPointSundear {
    /// Starts a new Session  开始一个新的会话
    ///
    /// Use this function to manually start a new Session. A new Session will be automatically created only on app start. 使用此功能手动启动新会话。新会话将仅在app start上自动创建。
    /// You can use the AppDelegates `applicationWillEnterForeground` to start a new visit whenever the app enters foreground.  每当应用程序进入前景时，您可以使用appdelicates`applicationwillenterforgound`开始新的访问。
    public func startNewSession() {
        UserDefaults.standard.removeObject(forKey: "BuryingPoint_navigation_title")
        UserDefaults.standard.removeObject(forKey: "BuryingPoint_navigation_name")
        UserDefaults.standard.removeObject(forKey: "visitEntryIdactionName")
        UserDefaults.standard.removeObject(forKey: "visitEntryIdactionUrl")
        UserDefaults.standard.removeObject(forKey: "visitExitIdactionName")
        UserDefaults.standard.removeObject(forKey: "visitExitIdactionUrl")
        buryingPointUserDefaults.previousVisit = buryingPointUserDefaults.currentVisit
        buryingPointUserDefaults.currentVisit = Date()
        buryingPointUserDefaults.totalNumberOfVisits += 1
        nextEventStartsANewSession = true
        
        self.session = Session.current(in: buryingPointUserDefaults)
    }
}

extension BuryingPointSundear {
    
    /// Tracks a custom Event   跟踪自定义事件
    ///
    /// - Parameter event: The event that should be tracked.   参数事件：应跟踪的事件。
    public func track(_ event: Event) {
        queue(event: event)
        
        if (event.campaignName == campaignName && event.campaignKeyword == campaignKeyword) {
            campaignName = nil
            campaignKeyword = nil
        }
    }
    
    /// Tracks a screenview.  跟踪屏幕视图
    ///
    /// This method can be used to track hierarchical screen names, e.g. screen/settings/register. Use this to create a hierarchical and logical grouping of screen views in the BuryingPoint web interface.   该方法可用于跟踪分层屏幕名称，例如屏幕/设置/寄存器。使用它可以在BuryingPoint web界面中创建屏幕视图的分层和逻辑分组。
    ///
    /// - Parameter view: An array of hierarchical screen names.  分层屏幕名称的数组。
    /// - Parameter url: The optional url of the page that was viewed.   已查看页面的可选url。
    /// - Parameter dimensions: An optional array of dimensions, that will be set only in the scope of this view.   一个可选的维度数组，仅在此视图的范围内设置。
    public func track(view: [String], url: URL? = nil, dimensions: [CustomDimension] = []) {
        let event = Event(tracker: self, action: view, url: url, dimensions: dimensions, isCustomAction: false, idactionCategory:nil, idactionAction: nil)
        queue(event: event)
    }
    
    /// Tracks an event as described here:跟踪此处描述的事件 https://buryingPoint.org/docs/event-tracking/
    ///
    /// - Parameters:
    ///   - category: The Category of the Event  事件的类别
    ///   - action: The Action of the Event  事件的行动
    ///   - name: The optional name of the Event   事件的可选名称
    ///   - value: The optional value of the Event   事件的可选值
    ///   - dimensions: An optional array of dimensions, that will be set only in the scope of this event.  一个可选的维度数组，仅在此事件的范围内设置。
    ///   - url: The optional url of the page that was viewed.  已查看页面的可选url。
    public func track(eventWithCategory category: String, action: String, name: String? = nil, value: Float? = nil, dimensions: [CustomDimension] = [], url: URL? = nil) {
        let event = Event(tracker: self, action: [], url: url, eventCategory: category, eventAction: action, eventName: name, eventValue: value, dimensions: dimensions, idactionCategory:nil, idactionAction: nil)
        queue(event: event)
    }
    
    /// Tracks a goal as described here:跟踪目标，如下所述 https://buryingPoint.org/docs/tracking-goals-web-analytics/
    ///
    /// - Parameters:
    ///   - goalId: The defined ID of the Goal   目标的定义ID
    ///   - revenue: The monetary value that was generated by the Goal  目标产生的货币价值
    public func trackGoal(id goalId: Int?, revenue: Float?) {
        let event = Event(tracker: self, action: [], goalId: goalId, revenue: revenue, idactionCategory:nil, idactionAction: nil)
        queue(event: event)
    }

    /// Tracks an order as described here: 跟踪此处描述的顺序 https://buryingPoint.org/docs/ecommerce-analytics/#tracking-ecommerce-orders-items-purchased-required
    ///
    /// - Parameters:
    ///   - id: The unique ID of the order  订单的唯一id
    ///   - items: The array of items to be ordered   要订购的项目数组
    ///   - revenue: The grand total for the order (includes tax, shipping and subtracted discount)  订单的总额（包括税收，运输和扣除折扣）
    ///   - subTotal: The sub total of the order (excludes shipping) 订单的小计（不包括运输）
    ///   - tax: The tax amount of the order   订单的税项
    ///   - shippingCost: The shipping cost of the order   订单的运输成本
    ///   - discount: The discount offered  提供的折扣
    public func trackOrder(id: String, items: [OrderItem], revenue: Float, subTotal: Float? = nil, tax: Float? = nil, shippingCost: Float? = nil, discount: Float? = nil) {
        let lastOrderDate = buryingPointUserDefaults.lastOrder

        let event = Event(tracker: self, action: [], orderId: id, orderItems: items, orderRevenue: revenue, orderSubTotal: subTotal, orderTax: tax, orderShippingCost: shippingCost, orderDiscount: discount, orderLastDate: lastOrderDate, idactionCategory:nil, idactionAction: nil)
        queue(event: event)
        
        buryingPointUserDefaults.lastOrder = Date()
    }
}

extension BuryingPointSundear {
    
    /// Tracks a search result page as described here/跟踪搜索结果页面，如下所述: https://buryingPoint.org/docs/site-search/
    ///
    /// - Parameters:
    ///   - query: The string the user was searching for  用户搜索的字符串
    ///   - category: An optional category which the user was searching in   用户正在搜索的可选类别
    ///   - resultCount: The number of results that were displayed for that search   为该搜索显示的结果数量
    ///   - dimensions: An optional array of dimensions, that will be set only in the scope of this event.  一个可选的维度数组，仅在此事件的范围内设置。
    ///   - url: The optional url of the page that was viewed.   已查看页面的可选url。
    public func trackSearch(query: String, category: String?, resultCount: Int?, dimensions: [CustomDimension] = [], url: URL? = nil) {
        let event = Event(tracker: self, action: [], url: url, searchQuery: query, searchCategory: category, searchResultsCount: resultCount, dimensions: dimensions, idactionCategory:nil, idactionAction: nil)
        queue(event: event)
    }
}

extension BuryingPointSundear {
    /// Set a permanent custom dimension.  设置一个永久的自定义维度。
    ///
    /// Use this method to set a dimension that will be send with every event. This is best for Custom Dimensions in scope "Visit". A typical example could be any device information or the version of the app the visitor is using.  使用此方法设置将随每个事件发送的维度。这对于“访问”范围内的自定义维度最佳。一个典型的例子可能是访问者使用的任何设备信息或应用程序的版本。
    ///
    /// For more information on custom dimensions visit https://buryingPoint.org/docs/custom-dimensions/
    ///
    /// - Parameter value: The value you want to set for this dimension.  要为此维度设置的值
    /// - Parameter index: The index of the dimension. A dimension with this index must be setup in the BuryingPoint backend.  维度的索引。必须在BuryingPoint后端设置具有此索引的维度。
    @available(*, deprecated, message: "use setDimension: instead")
    public func set(value: String, forIndex index: Int) {
        let dimension = CustomDimension(index: index, value: value)
        remove(dimensionAtIndex: dimension.index)
        dimensions.append(dimension)
    }
    
    /// Set a permanent custom dimension.设置一个永久的自定义维度
    ///
    /// Use this method to set a dimension that will be send with every event. This is best for Custom Dimensions in scope "Visit". A typical example could be any device information or the version of the app the visitor is using. 使用此方法设置将随每个事件发送的维度。这对于“访问”范围内的自定义维度最佳。一个典型的例子可能是访问者使用的任何设备信息或应用程序的版本。
    ///
    /// For more information on custom dimensions visit 有关自定义维度的更多信息 https://buryingPoint.org/docs/custom-dimensions/
    ///
    /// - Parameter dimension: The Dimension to set 要设置的维度
    public func set(dimension: CustomDimension) {
        remove(dimensionAtIndex: dimension.index)
        dimensions.append(dimension)
    }
    
    /// Set a permanent custom dimension by value and index.  按值和索引设置永久自定义维度。
    ///
    /// This is a convenience alternative to set(dimension:) and calls the exact same functionality. Also, it is accessible from Objective-C.
    ///这是设置（维度：）的便利替代方案，并调用完全相同的功能。此外，它可以从客观C获得。
    /// - Parameter value: The value for the new Custom Dimension  新自定义维度的值
    /// - Parameter forIndex: The index of the new Custom Dimension  新自定义维度的索引
    @objc public func setDimension(_ value: String, forIndex index: Int) {
        set(dimension: CustomDimension( index: index, value: value ));
    }
    
    /// Removes a previously set custom dimension.   删除先前设置的自定义维度。
    ///
    /// Use this method to remove a dimension that was set using the `set(value: String, forDimension index: Int)` method.
    ///使用此方法删除使用“set（value:String，forDimension index:Int）”方法设置的维度。
    /// - Parameter index: The index of the dimension.   维度的索引。
    @objc public func remove(dimensionAtIndex index: Int) {
        dimensions = dimensions.filter({ dimension in
            dimension.index != index
        })
    }
}


extension BuryingPointSundear {

    /// Set a permanent new Custom Variable.   设置一个永久的新自定义变量。
    ///
    /// - Parameter dimension: The Custom Variable to set   自定义变量设置
    public func set(customVariable: CustomVariable) {
        removeCustomVariable(withIndex: customVariable.index)
        customVariables.append(customVariable)
    }
    
    /// Set a permanent new Custom Variable.  /设置一个永久的新自定义变量。
    /// 使用此方法时需要注意，下标0-6是获取系统方法，禁止使用，否则引起方法覆盖
    /// - Parameter name: The index of the new Custom Variable  新自定义变量的索引
    /// - Parameter name: The name of the new Custom Variable   新自定义变量的名称
    /// - Parameter value: The value of the new Custom Variable   新自定义变量的值
    @objc public func setCustomVariable(withIndex index: UInt, name: String, value: String) {
        set(customVariable: CustomVariable(index: index, name: name, value: value))
    }
    
    /// Remove a previously set Custom Variable. 删除先前设置的自定义变量。
    ///
    /// - Parameter index: The index of the Custom Variable 自定义变量的索引
    @objc public func removeCustomVariable(withIndex index: UInt) {
        customVariables = customVariables.filter { $0.index != index }
    }
}

// Objective-c compatibility extension  兼容性扩展
extension BuryingPointSundear {
    @objc public func track(view: [String], url: URL? = nil) {
        track(view: view, url: url, dimensions: [])
    }
    
    @objc public func track(eventWithCategory category: String, action: String, name: String? = nil, number: NSNumber? = nil, url: URL? = nil) {
        let value = number == nil ? nil : number!.floatValue
        track(eventWithCategory: category, action: action, name: name, value: value, url: url)
    }
    
    @available(*, deprecated, message: "use trackEventWithCategory:action:name:number:url instead")
    @objc public func track(eventWithCategory category: String, action: String, name: String? = nil, number: NSNumber? = nil) {
        track(eventWithCategory: category, action: action, name: name, number: number, url: nil)
    }
    
    @objc public func trackSearch(query: String, category: String?, resultCount: Int, url: URL? = nil) {
        trackSearch(query: query, category: category, resultCount: resultCount, dimensions: [], url: url)
    }
}

extension BuryingPointSundear {
    @objc public func copyFromOldSharedInstance() {
        buryingPointUserDefaults.copy(from: UserDefaults.standard)
    }
}

extension BuryingPointSundear {
    /// The version of the BuryingPoint SDKs  BuryingPoint SDKs的版本
    @objc public static let sdkVersion = "0.0.4"
}
