//
//  NowPlayingCentral.swift
//  MinimalMIDIPlayer
//
//  Created by Peter Wunder on 07.09.18.
//  Copyright © 2018 Peter Wunder. All rights reserved.
//

import Cocoa
import MediaPlayer

@available(OSX 10.12.2, *)
class NowPlayingCentral: NSObject {
	
	static let shared = NowPlayingCentral()
	
	var playbackState: MPNowPlayingPlaybackState {
		get {
			return MPNowPlayingInfoCenter.default().playbackState
		}
		set {
			if !Settings.shared.cacophonyMode {
				MPNowPlayingInfoCenter.default().playbackState = newValue
			}
		}
	}
	
	private var players: [PWMIDIPlayer] = []
	
	override init() {
		super.init()
		
		Swift.print("Next stop: Now Playing Central")
		
		MPRemoteCommandCenter.shared().playCommand.addTarget(self, action: #selector(playCommand(event:)))
		MPRemoteCommandCenter.shared().pauseCommand.addTarget(self, action: #selector(pauseCommand(event:)))
		MPRemoteCommandCenter.shared().stopCommand.addTarget(self, action: #selector(stopCommand(event:)))
		MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget(self, action: #selector(togglePlayPauseCommand(event:)))
		MPRemoteCommandCenter.shared().changePlaybackPositionCommand.addTarget(self, action: #selector(changePlaybackPositionCommand(event:)))
		MPRemoteCommandCenter.shared().previousTrackCommand.addTarget(self, action: #selector(previousTrackCommand(event:)))
		MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = false
	}
	
	// MARK: - View Controller Management
	
	func makeActive(player: PWMIDIPlayer) {
		if let playerIdx = self.players.firstIndex(of: player) {
			self.players.remove(at: playerIdx)
		}
		
		self.players.insert(player, at: 0)
	}
	
	func addToPlayers(player: PWMIDIPlayer) {
		if self.players.contains(player) {
			self.players.append(player)
		}
	}
	
	func removeFromPlayers(player: PWMIDIPlayer?) {
		if let player = player, let playerIdx = self.players.firstIndex(of: player) {
			self.players.remove(at: playerIdx)
			
			if self.players.isEmpty {
				self.resetNowPlayingInfo()
			}
		}
	}
	
	var activePlayer: PWMIDIPlayer? {
		return self.players.first
	}
	
	// MARK: - Now Playing Control
	
	func resetNowPlayingInfo() {
		MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
		self.playbackState = .stopped
	}
	
	func initNowPlayingInfo(for midiPlayer: PWMIDIPlayer) {
		guard midiPlayer == self.activePlayer else {
			return
		}
		
		MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
		
		let midiTitle = midiPlayer.currentMIDI!.deletingPathExtension().lastPathComponent
		let midiAlbumTitle = midiPlayer.currentSoundfont?.deletingPathExtension().lastPathComponent ?? midiPlayer.currentMIDI!.deletingLastPathComponent().lastPathComponent
		let midiArtist = "MinimalMIDIPlayer" // heh
		
		var nowPlayingInfo: [String : Any] = [
			MPNowPlayingInfoPropertyMediaType: NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue),
			MPNowPlayingInfoPropertyIsLiveStream: NSNumber(booleanLiteral: false),

			MPNowPlayingInfoPropertyDefaultPlaybackRate: NSNumber(floatLiteral: Double(midiPlayer.rate)),
			MPNowPlayingInfoPropertyPlaybackProgress: NSNumber(floatLiteral: midiPlayer.currentPosition),

			MPMediaItemPropertyTitle: midiTitle,
			MPMediaItemPropertyAlbumTitle: midiAlbumTitle,
			MPMediaItemPropertyArtist: midiArtist,

			MPMediaItemPropertyPlaybackDuration: NSNumber(value: midiPlayer.duration)
		]

		if #available(OSX 10.13.2, *) {
			nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: CGSize(width: 800, height: 800), requestHandler: {
				(size: CGSize) -> NSImage in

				return NSImage(named: "AlbumArt")!
			})
		}
		
//		Swift.print(nowPlayingInfo)

		MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
	}
	
	func updateNowPlayingInfo(for midiPlayer: PWMIDIPlayer, with updatedDict: [String : Any]) {
		guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil, !Settings.shared.cacophonyMode else {
			return
		}
		
		for key in updatedDict.keys {
			MPNowPlayingInfoCenter.default().nowPlayingInfo![key] = updatedDict[key]
		}
	}
	
	// MARK: - MPRemoteCommandEvent Handlers
	
	@objc func playCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
		Swift.print("Play command")
		if let activePlayer = self.activePlayer, !Settings.shared.cacophonyMode {
			activePlayer.play()
			return .success
		}
		
		return .noActionableNowPlayingItem
	}
	
	@objc func pauseCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
		Swift.print("Pause command")
		if let activePlayer = self.activePlayer, !Settings.shared.cacophonyMode {
			activePlayer.pause()
			return .success
		}
		return .noActionableNowPlayingItem
	}
	
	@objc func stopCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
		Swift.print("Stop command")
		if let activePlayer = self.activePlayer, !Settings.shared.cacophonyMode {
			activePlayer.stop()
			return .success
		}
		return .noActionableNowPlayingItem
	}
	
	@objc func togglePlayPauseCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
		Swift.print("Play/ Pause command")
		if let activePlayer = self.activePlayer, !Settings.shared.cacophonyMode {
			activePlayer.togglePlayPause()
			return .success
		}
		return .noActionableNowPlayingItem
	}
	
	@objc func changePlaybackPositionCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
		if let changePositionEvent = event as? MPChangePlaybackPositionCommandEvent,
		   let activePlayer = self.activePlayer,
		   !Settings.shared.cacophonyMode {
			activePlayer.currentPosition = changePositionEvent.positionTime
			return .success
		}
		
		return .noActionableNowPlayingItem
	}
	
	@objc func previousTrackCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
		Swift.print("Previous track command")
		// Rewind: stop, set currentPosition to 0, play
		if let activePlayer = self.activePlayer, !Settings.shared.cacophonyMode {
			activePlayer.stop()
			activePlayer.currentPosition = 0
			activePlayer.play()
			return .success
		}
		return .noActionableNowPlayingItem
	}
	
//	class func 

}