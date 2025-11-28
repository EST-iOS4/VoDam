//
//  RecordingFeatureTests.swift
//  VodamTests
//
//  Created by 이건준 on 11/27/25.
//

import Testing
import ComposableArchitecture
@testable import VoDam

@MainActor
@Suite
struct RecordingFeatureTests {

    // MARK: - 1. startTapped: ready → recording, 타이머 시작

    @Test
    func startTapped시_ready에서_recording으로_변경되고_타이머가_동작한다() async {
        let clock = TestClock()
        var didStartRecording = false

        let store = TestStore(
            initialState: RecordingFeature.State(
                status: .ready,
                elapsedSeconds: 5,
                fileURL: nil,
                lastRecordedLength: 0
            ),
            reducer: { RecordingFeature() }
        )

        store.dependencies.continuousClock = clock
        store.dependencies.audioRecorder = AudioRecorderService(
            startRecording: {
                didStartRecording = true
                return URL(string: "file:///tmp/mock.m4a")!
            },
            pauseRecording: { },
            resumeRecording: { },
            stopRecording: { nil }
        )

        await store.send(.startTapped) {
            $0.status = .recording
            $0.elapsedSeconds = 0
        }

        #expect(didStartRecording == true)

        await clock.advance(by: .seconds(1))
        await store.receive(.tick) {
            $0.elapsedSeconds = 1
        }

        await clock.advance(by: .seconds(2))
        await store.receive(.tick) {
            $0.elapsedSeconds = 2
        }
        await store.receive(.tick) {
            $0.elapsedSeconds = 3
        }
    }

    // MARK: - 2. tick: recording일 때만 elapsedSeconds 증가

    @Test
    func tick은_recording일때만_elapsedSeconds를_증가시킨다() async {
        do {
            let store = TestStore(
                initialState: RecordingFeature.State(
                    status: .recording,
                    elapsedSeconds: 10,
                    fileURL: nil,
                    lastRecordedLength: 0
                ),
                reducer: { RecordingFeature() }
            )

            await store.send(.tick) {
                $0.elapsedSeconds = 11
            }
        }

        do {
            let store = TestStore(
                initialState: RecordingFeature.State(
                    status: .paused,
                    elapsedSeconds: 10,
                    fileURL: nil,
                    lastRecordedLength: 0
                ),
                reducer: { RecordingFeature() }
            )

            await store.send(.tick)
            #expect(store.state.elapsedSeconds == 10)
        }

        do {
            let store = TestStore(
                initialState: RecordingFeature.State(
                    status: .ready,
                    elapsedSeconds: 5,
                    fileURL: nil,
                    lastRecordedLength: 0
                ),
                reducer: { RecordingFeature() }
            )

            await store.send(.tick)
            #expect(store.state.elapsedSeconds == 5)
        }
    }

    // MARK: - 3. pauseTapped: recording일 때만 paused로 변경 + 녹음 일시정지 호출

    @Test
    func pauseTapped시_recording상태에서만_paused로_변경되고_recorder_pause가_호출된다() async {
        var didPauseRecording = false

        let store = TestStore(
            initialState: RecordingFeature.State(
                status: .recording,
                elapsedSeconds: 3,
                fileURL: nil,
                lastRecordedLength: 0
            ),
            reducer: { RecordingFeature() }
        )

        store.dependencies.audioRecorder = AudioRecorderService(
            startRecording: { URL(string: "file:///tmp/mock.m4a")! },
            pauseRecording: { didPauseRecording = true },
            resumeRecording: { },
            stopRecording: { nil }
        )

        await store.send(.pauseTapped) {
            $0.status = .paused
        }

        #expect(didPauseRecording == true)
    }

    // MARK: - 4. stopTapped: fileURL/lastRecordedLength 설정 + 상태 리셋

    @Test
    func stopTapped시_fileURL과_lastRecordedLength가_설정되고_상태가_ready로_리셋된다() async {
        let mockURL = URL(string: "file:///tmp/recording.m4a")!
        var didStopRecording = false

        let store = TestStore(
            initialState: RecordingFeature.State(
                status: .recording,
                elapsedSeconds: 10,
                fileURL: nil,
                lastRecordedLength: 0
            ),
            reducer: { RecordingFeature() }
        )

        store.dependencies.audioRecorder = AudioRecorderService(
            startRecording: { mockURL },
            pauseRecording: { },
            resumeRecording: { },
            stopRecording: {
                didStopRecording = true
                return mockURL
            }
        )

        await store.send(.stopTapped) {
            $0.fileURL = mockURL
            $0.lastRecordedLength = 10
            $0.status = .ready
            $0.elapsedSeconds = 0
        }

        #expect(didStopRecording == true)
    }

    // MARK: - 5. pauseTapped는 recording이 아닐 때는 아무 일도 하지 않는다

    @Test
    func pauseTapped는_recording이_아닐때_아무_동작도_하지_않는다() async {
        var didPauseRecording = false

        let store = TestStore(
            initialState: RecordingFeature.State(
                status: .ready,
                elapsedSeconds: 0,
                fileURL: nil,
                lastRecordedLength: 0
            ),
            reducer: { RecordingFeature() }
        )

        store.dependencies.audioRecorder = AudioRecorderService(
            startRecording: { URL(string: "file:///tmp/mock.m4a")! },
            pauseRecording: { didPauseRecording = true },
            resumeRecording: { },
            stopRecording: { nil }
        )

        await store.send(.pauseTapped)
        #expect(store.state.status == .ready)
        #expect(didPauseRecording == false)
    }
}
