import UIKit

class StreamViewController: GAITrackedViewController, ZLSwipeableViewDataSource, ZLSwipeableViewDelegate {
    @IBOutlet weak var swipeableView: ZLSwipeableView!
    @IBOutlet weak var revealButtonItem: UIBarButtonItem!
    
    var deck = Deck(deckSourceMode: DeckSourceMode.NewGifs)
    var swipeStart: CGPoint!
    var totalFavedForSession: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.screenName = "Stream"
      
        let titleImage = UIImage(named: "fun-logo.png")
        let titleImageView = UIImageView(frame: CGRectMake(0, 0, 30, 30))
        titleImageView.contentMode = .ScaleAspectFit
        titleImageView.image = titleImage
        self.navigationItem.titleView = titleImageView

        let rvc = self.revealViewController()
        revealButtonItem.target = rvc
        revealButtonItem.action = "revealToggle:"
        
        let tap = rvc.tapGestureRecognizer();
        navigationController!.navigationBar.addGestureRecognizer(rvc.panGestureRecognizer())

        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        swipeableView.dataSource = self
        swipeableView.delegate = self
        swipeableView.backgroundColor = UIColor.clearColor()

        Flurry.logAllPageViewsForTarget(self.navigationController)
    
        fetchCardsAndUpdateView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        swipeableView.setNeedsLayout()
        swipeableView.layoutIfNeeded()
    }
    
//    @IBAction func switchToFavesButtonWasPressed(sender: AnyObject) {
//        deck.deckSourceMode = DeckSourceMode.Faves
//        deck.reset()
//        fetchCardsAndUpdateView()
//    }

    @IBAction func faveButtonWasPressed(sender: AnyObject) {
        swipeableView.swipeTopViewToRight()
        if let view = swipeableView.topSwipeableView() as? GifCollectionViewCell {
            view.shouldPlay = true
        }
    }
    
    @IBAction func passButtonWasPressed(sender: AnyObject) {
        swipeableView.swipeTopViewToLeft()
        if let view = swipeableView.topSwipeableView() as? GifCollectionViewCell {
            view.shouldPlay = true
        }
    }
    @IBAction func flagButtonWasPressed(sender: AnyObject) {
        var alert = UIAlertController(title: "Flag image", message: "Are you sure you want to flag this image as offensive?", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        alert.addAction(UIAlertAction(title: "Flag", style: UIAlertActionStyle.Default, handler: flagHandler))
        
        self.presentViewController(alert, animated: true, completion: nil)
        
    }
    func flagHandler(alert: UIAlertAction!) {
        swipeableView.swipeTopViewToDown()
        if let view = swipeableView.topSwipeableView() as? GifCollectionViewCell {
            
            println("\(view.imageId) flagged")
            Flurry.logEvent("flagged", withParameters: ["gif":view.imageId!])
            
            let event = GAIDictionaryBuilder.createEventWithCategory("gif", action: "flagged", label:"Gif Flagged", value:nil).build() as NSDictionary
            GAI.sharedInstance().defaultTracker.send(event as [NSObject: AnyObject])
            FunSession.sharedSession.imageFlaggedAsInappropriate(view.imageId!)
            view.shouldPlay = true
        }
    }

    @IBAction func shareButtonWasPressed(sender: AnyObject) {
        if let view = swipeableView.topSwipeableView() as? GifCollectionViewCell {
            let card = deck.cardForId(view.imageId! as String)!
            Flurry.logEvent("share", withParameters: ["gif":view.imageId!])
            let avc = UIActivityViewController(activityItems: [card.caption!, card.shareUrl()], applicationActivities: nil)
            navigationController?.presentViewController(avc, animated: true, completion: nil)
        }
    }

    
    func fetchCardsAndUpdateView() {
        weak var mySwipeableView : ZLSwipeableView?  = self.swipeableView
        deck.fetch() {
            dispatch_async(dispatch_get_main_queue()) {
                if let myConcreteSwipeableView = mySwipeableView {
                    myConcreteSwipeableView.discardAllSwipeableViews()
                    myConcreteSwipeableView.loadNextSwipeableViewsIfNeeded()
                }
            }
        }
    }
    
    // ZLSwipeableViewDelegate
    func swipeableView(swipeableView: ZLSwipeableView!, didStartSwipingView view: UIView!, atLocation location: CGPoint) {
        swipeStart = location
        println("swipe start")
    }
    
    func swipeableView(swipeableView: ZLSwipeableView!, didEndSwipingView view: UIView!, atLocation location: CGPoint) {
        swipeStart = nil

        let gifView = view as! GifCollectionViewCell
        gifView.passLabel.alpha = 0.0
        gifView.faveLabel.alpha = 0.0
    }
    
    func swipeableView(swipeableView: ZLSwipeableView!, didSwipeView view: UIView!, inDirection direction: ZLSwipeableViewDirection) {
        //Flurry.logEvent("swipe", withParameters: ["direction" : direction])
        let gifView = view as! GifCollectionViewCell
        switch(direction) {
        case .Left:
            println("\(gifView.imageId) passed")
            Flurry.logEvent("swipe", withParameters: ["direction" : "left"])
            let event = GAIDictionaryBuilder.createEventWithCategory("gif", action: "passed", label:"Gif Passed", value:nil).build() as NSDictionary
            GAI.sharedInstance().defaultTracker.send(event as [NSObject: AnyObject])
            FunSession.sharedSession.imagePassed(gifView.imageId!)
        case .Right:
            println("\(gifView.imageId) faved")
            Flurry.logEvent("swipe", withParameters: ["direction" : "right"])
            let event = GAIDictionaryBuilder.createEventWithCategory("gif", action: "faved", label:"Gif Faved", value:nil).build() as NSDictionary
            GAI.sharedInstance().defaultTracker.send(event as [NSObject: AnyObject])
            totalFavedForSession += 1
            // already faved 10 items: show them 'oops' payment page
//            if totalFavedForSession >= 10 {
//                self.performSegueWithIdentifier("oops", sender: self)
//            }
            FunSession.sharedSession.imageFaved(gifView.imageId!)
        default:
            println("Ignore swipe")
        }
    }
    
    func swipeableView(swipeableView: ZLSwipeableView!, swipingView view: UIView!, atLocation location: CGPoint, translation: CGPoint) {
        let minimalDrag = CGFloat(10.0)
        let maximumDrag = CGFloat(40.0)
        let gifView = view as! GifCollectionViewCell
        if let concreteSwipeStart = swipeStart {
            let swipeDiff = location.x - concreteSwipeStart.x
            let absSwipeDiff = abs(swipeDiff)

            var alphaValue = CGFloat(0.0)
            if (absSwipeDiff > maximumDrag) {
                alphaValue = 1.0
            } else if (absSwipeDiff > minimalDrag) {
                alphaValue = (absSwipeDiff - minimalDrag) / (maximumDrag - minimalDrag)
            }

            if swipeDiff > 0 {
                gifView.faveLabel.alpha = alphaValue
                gifView.passLabel.alpha = 0.0
            } else if swipeDiff < 0 {
                gifView.faveLabel.alpha = 0.0
                gifView.passLabel.alpha = alphaValue
            } else {
                gifView.faveLabel.alpha = 0.0
                gifView.passLabel.alpha = 0.0
            }
        }
    }
    
    // ZLSwipeableViewDataSource
    func nextViewForSwipeableView(swipeableView: ZLSwipeableView!) -> UIView! {
        
        if let view = swipeableView.topSwipeableView() as? GifCollectionViewCell {
            view.shouldPlay = true
        }

        if let card = self.deck.nextCard() {
            var view = GifCollectionViewCell(frame:swipeableView.bounds)
            view.gifUrl = card.gifvUrl!
            dispatch_async(dispatch_get_main_queue()) { [weak view]() -> Void in
                if let strongView = view {
                    strongView.addAnimatedImage()
                }
            }
            
            view.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth
        
            view.imageId = card.id!
            view.caption.text = card.caption!

            view.layer.backgroundColor = UIColor.whiteColor().CGColor
            view.layer.cornerRadius = 10.0
            view.layer.shadowColor = UIColor.blackColor().CGColor
            view.layer.shadowOpacity = 0.33
            view.layer.shadowOffset = CGSizeMake(0, 1.5)
            view.layer.shadowRadius = 4.0
            
            return view
        }

        return nil
    }
}

