// MediaPipe Hands (tasks-vision) → window.lisaHand for the Dart side.
// lisaHand.lm: Float32Array(42) of normalised x,y landmark pairs, or null.
// lisaHand.age(): ms since a hand was last seen (Infinity if never).
// lisaHand.status: human readable state for the preview card.
import {
  FilesetResolver,
  HandLandmarker,
} from "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/vision_bundle.mjs";

const hand = { lm: null, seen: -Infinity, status: "loading model…" };
hand.age = () => performance.now() - hand.seen;

let video, landmarker, lastTime = -1;

hand.start = async () => {
  try {
    const base = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21";
    const vision = await FilesetResolver.forVisionTasks(base + "/wasm");
    landmarker = await HandLandmarker.createFromOptions(vision, {
      baseOptions: {
        modelAssetPath:
          "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task",
        delegate: "GPU",
      },
      runningMode: "VIDEO",
      numHands: 1,
    });
    hand.status = "waiting for camera permission…";
    video = document.createElement("video"); // never attached to the page
    video.autoplay = video.muted = video.playsInline = true;
    video.srcObject = await navigator.mediaDevices.getUserMedia({
      video: { width: 640, height: 480 },
    });
    await video.play();
    hand.status = "no hand";
    requestAnimationFrame(loop);
  } catch (e) {
    hand.status = "camera unavailable: " + (e.name || e);
    throw e;
  }
};

function loop() {
  if (video.currentTime !== lastTime) {
    lastTime = video.currentTime;
    const lm = landmarker.detectForVideo(video, performance.now()).landmarks[0];
    if (lm) {
      const out = new Float32Array(42);
      for (let i = 0; i < 21; i++) {
        out[i * 2] = lm[i].x;
        out[i * 2 + 1] = lm[i].y;
      }
      hand.lm = out;
      hand.seen = performance.now();
      hand.status = "tracking";
    } else {
      hand.lm = null;
      hand.status = "no hand";
    }
  }
  requestAnimationFrame(loop);
}

window.lisaHand = hand;
