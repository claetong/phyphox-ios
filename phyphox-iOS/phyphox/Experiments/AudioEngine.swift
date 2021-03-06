//
//  AudioEngine.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 30.04.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation

private let audioInputQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.audioInput", attributes: [])
private let audioOutputQueue = DispatchQueue(label: "de.rwth-aachen.phyphox.audioOutput", qos: .userInteractive, attributes: [])

final class AudioEngine {
    let bufferFrameCount: AVAudioFrameCount = 2048
    
    private var engine: AVAudioEngine? = nil
    private var playbackPlayer: AVAudioPlayerNode? = nil
    private var frameIndex: Int = 0
    private var endIndex: Int = 0
    private var recordInput: AVAudioInputNode? = nil
    
    private var playing = false
    
    private var playbackOut: ExperimentAudioOutput? = nil
    private var playbackStateToken = UUID()
    private var recordIn: ExperimentAudioInput? = nil
    
    private var format: AVAudioFormat? = nil
    
    private var sineLookup: [Float]?
    let sineLookupSize = 4096
    private var phases: [Double] = []
    
    enum AudioEngineError: Error {
        case RateMissmatch
    }
    
    init(audioOutput: ExperimentAudioOutput?, audioInput: ExperimentAudioInput?) {
        self.playbackOut = audioOutput
        self.recordIn = audioInput
    }
    
    @objc func audioEngineConfigurationChange(_ notification: Notification) -> Void {
        let wasPlaying = playing
        
        stop()
        
        if (wasPlaying) {
            play()
        }
    }
    
    func startEngine() throws {
        if playbackOut == nil && recordIn == nil {
            return
        }
        
        if let playbackOut = playbackOut, playbackOut.tones.count > 0 {
            if sineLookup == nil {
                sineLookup = (0..<sineLookupSize).map{sin(2*Float.pi*Float($0)/Float(sineLookupSize))}
            }
        }
        
        let avSession = AVAudioSession.sharedInstance()
        if playbackOut != nil && recordIn != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
        } else if playbackOut != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayback)
        } else if recordIn != nil {
            try avSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker) //Just setting AVAudioSessionCategoryRecord interferes with VoiceOver as it silences every other audio output (as documented)
        }
        try avSession.setMode(AVAudioSessionModeMeasurement)
        if (avSession.isInputGainSettable) {
            try avSession.setInputGain(1.0)
        }
        
        let sampleRate = recordIn?.sampleRate ?? playbackOut?.sampleRate ?? 0
        try avSession.setPreferredSampleRate(Double(sampleRate))
        
        try avSession.setActive(true)
        
        var audioDescription = monoFloatFormatWithSampleRate(avSession.sampleRate)
        format = AVAudioFormat(streamDescription: &audioDescription)
        
        self.engine = AVAudioEngine()
        
        NotificationCenter.default.addObserver(self, selector: #selector(audioEngineConfigurationChange), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: self.engine)
        
        if (playbackOut != nil) {
            self.playbackPlayer = AVAudioPlayerNode()
            self.engine!.attach(self.playbackPlayer!)
            self.engine!.connect(self.playbackPlayer!, to: self.engine!.mainMixerNode, format: self.format)
        }
        
        if (recordIn != nil) {
            self.recordInput = engine!.inputNode
            
            self.recordInput!.installTap(onBus: 0, bufferSize: UInt32(avSession.sampleRate/10), format: format!, block: {(buffer, time) in
                audioInputQueue.async {
                    autoreleasepool {
                        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                        let data = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                        
                        self.recordIn?.sampleRateInfoBuffer?.append(AVAudioSession.sharedInstance().sampleRate)
                        self.recordIn?.outBuffer.appendFromArray(data.map { Double($0) })
                    }
                }
            })
            
        }
        
        try self.engine!.start()
    }
    
    func play() {
        guard let playbackOut = playbackOut else {
            return
        }
        
        if !playing {
            playing = true
            
            frameIndex = 0
            endIndex = 0
            phases = [Double](repeating: 0.0, count: playbackOut.tones.count)
            
            if let inBuffer = playbackOut.directSource {
                endIndex = max(endIndex, inBuffer.count);
            }
            for tone in playbackOut.tones {
                endIndex = max(endIndex, Int(tone.duration.getValue() ?? 0.0 * AVAudioSession.sharedInstance().sampleRate))
            }
            if let noise = playbackOut.noise {
                endIndex = max(endIndex, Int(noise.duration.getValue() ?? 0.0 * AVAudioSession.sharedInstance().sampleRate))
            }
            
            appendBufferToPlayback()
            appendBufferToPlayback()
            appendBufferToPlayback()
            appendBufferToPlayback()
            
            self.playbackPlayer!.play()
        }
    }
    
    func appendBufferToPlayback() {

        guard let playbackOut = playbackOut else {
            return
        }
        
        var data = [Float](repeating: 0, count: Int(bufferFrameCount))
        
        var totalAmplitude: Float = 0.0

        addDirectBuffer: if let inBuffer = playbackOut.directSource {
            let inArray = inBuffer.toArray()
            let sampleCount = inArray.count
            guard sampleCount > 0 else {
                break addDirectBuffer
            }
            let start = playbackOut.loop ? frameIndex % sampleCount : frameIndex
            let end = min(inArray.count, start+Int(bufferFrameCount))
            if end > start {
                data.replaceSubrange(0..<end-start, with: inArray[start..<end].map { Float($0) })
            }
            if playbackOut.loop {
                var offset = end-start
                while offset < Int(bufferFrameCount) {
                    let subEnd = min(inArray.count, Int(bufferFrameCount)-offset)
                    data.replaceSubrange(offset..<offset+subEnd, with: inArray[0..<subEnd].map { Float($0) })
                    offset += subEnd
                }
            }
            totalAmplitude += 1.0
        }

        for (i, tone) in playbackOut.tones.enumerated() {
            guard let f = tone.frequency.getValue(), f > 0 else {
                continue
            }
            guard let a = tone.amplitude.getValue(), a > 0 else {
                continue
            }
            totalAmplitude += Float(a)
            guard let d = tone.duration.getValue(), d > 0 else {
                continue
            }
            guard let sineLookup = sineLookup else {
                continue
            }
            let end: Int
            if playbackOut.loop {
                end = Int(bufferFrameCount)
            } else {
                end = min(Int(bufferFrameCount), Int(d * AVAudioSession.sharedInstance().sampleRate)-frameIndex)
            }
            if end < 1 {
                continue
            }
            //Phase is not tracked at a periodicity of 0..2pi but 0..1 as it is converted to the range of the lookuptable anyways
            let phaseStep = f / (Double)(AVAudioSession.sharedInstance().sampleRate)
            var phase = phases[i]
            for i in 0..<end {
                let lookupIndex = Int(phase*Double(sineLookupSize)) % sineLookupSize
                data[i] += Float(a)*sineLookup[lookupIndex]
                phase += phaseStep
            }
            phases[i] = phase
        }

        addNoise: if let noise = playbackOut.noise {
            guard let a = noise.amplitude.getValue(), a > 0 else {
                break addNoise
            }
            totalAmplitude += Float(a)
            guard let d = noise.duration.getValue(), d > 0 else {
                break addNoise
            }
            let end: Int
            if playbackOut.loop {
                end = Int(bufferFrameCount)
            } else {
                end = min(Int(bufferFrameCount), Int(d * AVAudioSession.sharedInstance().sampleRate)-frameIndex)
            }
            if end < 1 {
                break addNoise
            }
            for i in 0..<end {
                data[i] += Float.random(in: -Float(a)...Float(a))
            }
        }

        guard totalAmplitude > 0 else {
            stop()
            return
        }
        
        if playbackOut.normalize {
            for i in 0..<Int(bufferFrameCount) {
                data[i] = data[i] / totalAmplitude
            }
        }
        
        frameIndex += Int(bufferFrameCount)
            
        guard let buffer = AVAudioPCMBuffer(pcmFormat: self.format!, frameCapacity: bufferFrameCount) else {
            stop()
            return
        }
        buffer.floatChannelData?[0].assign(from: &data, count: Int(bufferFrameCount))
        buffer.frameLength = UInt32(bufferFrameCount)
        
        if !playing {
            return
        }
        self.playbackPlayer!.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [unowned self] in
            if self.playing && (self.playbackOut?.loop ?? false || self.frameIndex < self.endIndex) {
                audioOutputQueue.async {
                    self.appendBufferToPlayback()
                }
            } else {
                self.playing = false
            }
        })
    }
    
    func stop() {
        if playing {
            playing = false
            self.playbackPlayer!.stop()
        }
    }
    
    func stopEngine() {
        stop()
        
        engine?.stop()
        engine = nil
        
        playbackPlayer = nil
        
        playbackOut = nil
        recordIn = nil
        
        let avSession = AVAudioSession.sharedInstance()
        do {
            try avSession.setActive(false)
        } catch {
            
        }
    }
    
}
