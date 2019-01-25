//
//  ChooseInputsViewController.swift
//  LearnLanguages
//
//  Created by Amir Khorsandi on 12/23/18.
//  Copyright © 2018 Amir Khorsandi. All rights reserved.
//
import AVFoundation
import AVKit
import SafariServices
import SwiftRichString

class ChooseInputsViewController: BaseViewController, NibBasedViewController, LLTextViewMenuDelegate, UIGestureRecognizerDelegate {
    
    
    // MARK: Properties
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @IBOutlet private weak var textView: LLTextView!
    @IBOutlet private weak var playerContainerView: UIView!
    @IBOutlet private weak var playPauseButton: UIButton!
    
    var player: AVPlayer!
    var playerController: LLPlayerViewController!
    var subtitles: Subtitles!
    
    private var currentPlaybackTime : Double {
        get {
            return CMTimeGetSeconds(player.currentTime())
        }
        set {
            let time = CMTimeMakeWithSeconds(newValue, preferredTimescale: Int32(NSEC_PER_SEC))
            player.seek(to: time)
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addPlayerAndPlay()
        addSubtitle()
        textView.isEditable = false
        textView.isSelectable = true
        textView.menuItemsDelegate = self
        addPlayerTimeListener()
        addPanGesture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        playerController?.view.frame = CGRect(x:0, y:0, width: playerContainerView.frame.width, height: playerContainerView.frame.height)
    }
    
    // MARK: - Event handlers
    
    @IBAction private func closeButtonTouched() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func playPauseButtonTouched() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else if player.timeControlStatus == .paused {
            player.play()
        }
    }
    
    @IBAction private func skipNextButtonTouched() {
        let seekDuration = 5.0
        guard let duration = player.currentItem?.duration else{
            return
        }
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = playerCurrentTime + seekDuration
        
        if newTime < (CMTimeGetSeconds(duration) - seekDuration) {
            
            let time2: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            player.seek(to: time2, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            
        }
    }
    
    @IBAction private func skipPrevButtonTouched() {
        let seekDuration = 5.0
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        var newTime = playerCurrentTime - seekDuration
        
        if newTime < 0 {
            newTime = 0
        }
        let time2: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
        player.seek(to: time2, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        

    }
    
    //MARK: - Private functions
    
    private func addPanGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGestue))
        textView.addGestureRecognizer(pan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        textView.addGestureRecognizer(tap)
    }
    
    @objc private func handleTap(_ gestureRecognizer : UIPanGestureRecognizer){
        textView.selectedTextRange = nil
    }
    
    @objc private func handlePanGestue(_ gestureRecognizer : UIPanGestureRecognizer){
        guard gestureRecognizer.view != nil else {return}
        let piece = gestureRecognizer.view!
        let location = gestureRecognizer.location(in: piece)
        if gestureRecognizer.state == .began {
            print("BEGIN: \(location.x), \(location.y)")
        }
        else if gestureRecognizer.state != .cancelled {
            print("MOVE: \(location.x), \(location.y)")
            
            let textStorage = NSTextStorage(attributedString: textView.attributedText)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)
            let bounds: CGRect = textView.bounds
            let textContainer = NSTextContainer(size: bounds.size)
            layoutManager.addTextContainer(textContainer)
            
            var characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            
            textView.becomeFirstResponder()
            textView.selectedRange = NSRange(location: characterIndex, length: 3)
            textView.select(self)
            
            print(characterIndex)
            
        }
        else if gestureRecognizer.state != .ended {
            
        }
        else {
            print("CANCELED: \(location.x), \(location.y)")
        }
    }
    
    private func addPlayerTimeListener(){
        
        player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.5, preferredTimescale: Int32(NSEC_PER_SEC)), queue: nil) { [weak self] (time:CMTime) in
            guard let strongSelf = self, let titles = strongSelf.subtitles.titles else {
                return
            }
            
            let currentValue = TimeInterval(time.value) / 1000000000
            if currentValue < 1 {
                return
            }
            let text = titles.first(where: { currentValue < $0.end! && currentValue > $0.start!})
            let style = Style {
                $0.font = SystemFonts.Helvetica.font(size: 18)
                $0.lineSpacing = 16
            }
            strongSelf.textView.attributedText = text?.texts?.joined(separator: "\n").set(style: style)
        }
    }
    
    private func addPlayerAndPlay(){
        let url: URL = Bundle.main.url(forResource: "Friends0301", withExtension: "mp4")!
        
        let avAsset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: avAsset)
        player = AVPlayer(playerItem: playerItem)
        playerController = LLPlayerViewController() 
        playerController?.player = player
        playerController?.view.frame = CGRect(x:0, y:0, width: 0, height: 0)
        
        guard let videoView = playerController?.view else { return }
        playerContainerView.insertSubview(videoView, at: 0)
        player?.play()
        
 
        player.addObserver(self, forKeyPath: "timeControlStatus", options: [], context: nil)
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus" {
            onPlayerStateChanged()
        }
    }
    
    @objc private func onPlayerStateChanged() {
        if player.timeControlStatus == .playing {
            playPauseButton.setImage(#imageLiteral(resourceName: "Pause"), for: .normal)
        } else {
            playPauseButton.setImage(#imageLiteral(resourceName: "Play"), for: .normal)
        }
    }
    
    private func addSubtitle(){
        
        let exampleSubtitlesUrl = Bundle.main.url(forResource: "Friends0301", withExtension: "srt")
        subtitles = Subtitles(fileUrl: exampleSubtitlesUrl!)
    }
    
    
    //MARK: - LLTextViewMenuDelegate
    
    func onTranslateMenuItemSelected(_ textView: UITextView, selectedText:String) {
        openWebView(url: "https://translate.google.com/#view=home&op=translate&sl=auto&tl=fa&text=" + urlEncode(selectedText) )
    }
    
    func onImageMenuItemSelected(_ textView: UITextView, selectedText:String) {
        openWebView(url: "https://www.google.com/search?tbm=isch&q=" + urlEncode(selectedText) )
    }
    
    func onGoogleMenuItemSelected(_ textView: UITextView, selectedText:String) {
        openWebView(url: "https://www.google.com/search?q=" + urlEncode(selectedText) )
    }
    
    private func urlEncode(_ originalString:String) -> String{
        return originalString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
    
    private func openWebView(url: String){
        
        let webView = SFSafariViewController(url: URL(string: url)!)
        present(webView, animated: true)
    }
    
}
