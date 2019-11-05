//
//  PlayDemoVideo.swift
//  TridentCockpit
//
//  Created by Dmitriy Borovikov on 05.11.2019.
//  Copyright © 2019 Dmitriy Borovikov. All rights reserved.
//

import Cocoa
import AVKit

#if DEBUG
extension VideoViewController {
    private func createPlayerView() -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView, positioned: .above, relativeTo: videoView)
        NSLayoutConstraint.activate([
            playerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            playerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerView.widthAnchor.constraint(equalTo: playerView.heightAnchor, multiplier: 16/9)
        ])
        playerView.controlsStyle = .none
        return playerView
    }

    func playDemoVideo() {
        guard let fileName = ProcessInfo.processInfo.environment["demoVideo"] else { return }
        
        FastRTPS.removeReader(topic: .rovDepth)
        FastRTPS.removeReader(topic: .rovTempWater)
        FastRTPS.removeReader(topic: .rovCamFwdH2640Video)
        self.depth = 12.3
        self.temperature = 28.4
        
        let moviesFolder = FileManager.default.urls(for: .moviesDirectory, in: .allDomainsMask).first!
        let videoURL = moviesFolder.appendingPathComponent(fileName)
        let playerView = createPlayerView()
        let player = AVPlayer(url: videoURL)
        guard let videoTime = player.currentItem?.asset.duration else { return }
        playerView.player = player
        avPlayerView = playerView
        timeObserverToken = player.addBoundaryTimeObserver(forTimes: [NSValue(time: videoTime)], queue: nil) { [weak self] in
            self?.removeDemoVideo()
            
        }
        player.play()
    }
    
    private func removeDemoVideo() {
        guard let playerView = avPlayerView as? AVPlayerView else { return }
        if let player = playerView.player, let timeObserver = timeObserverToken {
            player.removeTimeObserver(timeObserver)
            timeObserverToken = nil
        }
        playerView.removeFromSuperview()
        avPlayerView = nil
    }
    
}
#endif
