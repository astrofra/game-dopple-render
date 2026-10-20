const GAME_LENGTH = 10;
const TURBO_DURATION_MS = 5000;
const USED_PAIRS_STORAGE_KEY = "doppleRenderUsedPairs";

let current = 0;
let score = 0;
let order = [];
let seen = new Set();
let rounds = [];
let imagesLoaded = 0;
let imagesToLoad = 0;
let canClick = false;
let selectedMode = "soft";
let roundsTotal = GAME_LENGTH;
let timerId = null;
let timerDeadline = 0;

function startGame() {
  clearTurboTimer();
  current = 0;
  score = 0;
  order = [];
  rounds = [];
  seen = loadSeenPairs();
  selectedMode = document.querySelector('input[name="mode"]:checked').value;
  roundsTotal = Math.min(GAME_LENGTH, Object.keys(imageMapping).length);

  document.getElementById("intro").classList.add("hidden");
  document.getElementById("result").classList.add("hidden");
  document.getElementById("game").classList.remove("hidden");
  document.getElementById("modeTitle").textContent = getModeLabel();
  document.getElementById("roundsTotal").textContent = roundsTotal;
  document.getElementById("resultMode").textContent = getModeLabel();
  document.getElementById("resultTotal").textContent = roundsTotal;
  updateModeControls();
  loadNext();
}

function loadSeenPairs() {
  const storedPairs = sessionStorage.getItem(USED_PAIRS_STORAGE_KEY);
  return storedPairs ? new Set(JSON.parse(storedPairs)) : new Set();
}

function saveSeenPairs() {
  sessionStorage.setItem(USED_PAIRS_STORAGE_KEY, JSON.stringify([...seen]));
}

function getRandomPair() {
  const pairIds = Object.keys(imageMapping);
  let availablePairIds = pairIds.filter((id) => !seen.has(id));

  if (availablePairIds.length === 0) {
    seen.clear();
    saveSeenPairs();
    availablePairIds = pairIds;
  }

  const pairId = availablePairIds[Math.floor(Math.random() * availablePairIds.length)];
  seen.add(pairId);
  saveSeenPairs();
  return pairId;
}

function loadNext() {
  if (current >= roundsTotal) {
    showResult();
    return;
  }

  clearTurboTimer();
  canClick = false;
  imagesLoaded = 0;
  document.getElementById("timer").classList.add("hidden");
  document.getElementById("timeRemaining").textContent = (TURBO_DURATION_MS / 1000).toFixed(1);
  showLoadingMessage();

  const pairId = getRandomPair();
  const pair = {
    id: pairId,
    mode: selectedMode
  };

  if (selectedMode === "soft") {
    pair.iaFirst = Math.random() < 0.5;
    pair.correct = pair.iaFirst ? 1 : 0;
    imagesToLoad = 2;
  } else {
    pair.displayedType = Math.random() < 0.5 ? "ai" : "real";
    pair.correct = pair.displayedType;
    imagesToLoad = 1;
  }

  order[current] = pair;
  document.getElementById("pairIndex").textContent = current + 1;

  const mappingEntry = imageMapping[pairId];
  if (!mappingEntry) {
    console.error(`No mapping found for pair ${pairId}`);
    return;
  }

  if (selectedMode === "soft") {
    loadSoftPair(mappingEntry, pair.iaFirst);
    return;
  }

  loadAdvancedImage(mappingEntry, pair.displayedType);
}

function loadSoftPair(mappingEntry, iaFirst) {
  const softPair = document.getElementById("softPair");
  const advancedPair = document.getElementById("advancedPair");
  softPair.classList.remove("hidden");
  advancedPair.classList.add("hidden");

  const img1 = document.getElementById("img1");
  const img2 = document.getElementById("img2");
  prepareImageForLoading(img1);
  prepareImageForLoading(img2);
  img1.onload = imageLoaded;
  img2.onload = imageLoaded;
  img1.src = `assets/${iaFirst ? mappingEntry.b : mappingEntry.a}`;
  img2.src = `assets/${iaFirst ? mappingEntry.a : mappingEntry.b}`;
}

function loadAdvancedImage(mappingEntry, displayedType) {
  const softPair = document.getElementById("softPair");
  const advancedPair = document.getElementById("advancedPair");
  softPair.classList.add("hidden");
  advancedPair.classList.remove("hidden");

  const singleImg = document.getElementById("singleImg");
  prepareImageForLoading(singleImg);
  singleImg.onload = imageLoaded;
  singleImg.src = `assets/${displayedType === "ai" ? mappingEntry.b : mappingEntry.a}`;
}

function prepareImageForLoading(image) {
  image.classList.add("is-loading");
  image.style.cursor = "not-allowed";
}

function makeChoice(choice) {
  if (!canClick || selectedMode !== "soft") return;
  finishRound(choice);
}

function makeAdvancedChoice(choice) {
  if (!canClick || selectedMode === "soft") return;
  finishRound(choice);
}

function finishRound(choice) {
  const pair = order[current];
  canClick = false;
  clearTurboTimer();

  const success = choice === pair.correct;
  if (success) score++;
  rounds.push({
    id: pair.id,
    mode: pair.mode,
    user: choice,
    correct: pair.correct,
    iaFirst: pair.iaFirst,
    displayedType: pair.displayedType,
    timedOut: choice === null
  });
  current++;
  loadNext();
}

function imageLoaded() {
  imagesLoaded++;
  if (imagesLoaded !== imagesToLoad) return;

  hideLoadingMessage();
  document.querySelectorAll("#softPair img, #advancedPair img").forEach((image) => {
    image.classList.remove("is-loading");
    image.style.cursor = "pointer";
  });
  canClick = true;

  if (selectedMode === "turbo") {
    document.getElementById("timer").classList.remove("hidden");
    startTurboTimer();
  }
}

function startTurboTimer() {
  timerDeadline = Date.now() + TURBO_DURATION_MS;
  updateTurboTimer();
  timerId = setInterval(updateTurboTimer, 100);
}

function updateTurboTimer() {
  const remaining = Math.max(0, timerDeadline - Date.now());
  const timer = document.getElementById("timer");
  document.getElementById("timeRemaining").textContent = (remaining / 1000).toFixed(1);
  timer.style.setProperty("--timer-progress", `${remaining / TURBO_DURATION_MS * 100}%`);

  if (remaining === 0) {
    finishRound(null);
  }
}

function clearTurboTimer() {
  if (timerId !== null) {
    clearInterval(timerId);
    timerId = null;
  }
}

function updateModeControls() {
  const isSoft = selectedMode === "soft";
  const isTurbo = selectedMode === "turbo";
  document.getElementById("question").textContent = isSoft
    ? "Click on the real photo."
    : "Is this image REAL or AI-generated?";
  document.getElementById("answerActions").classList.toggle("hidden", isSoft);
  document.getElementById("timer").classList.toggle("hidden", !isTurbo);
}

function getModeLabel() {
  return selectedMode.charAt(0).toUpperCase() + selectedMode.slice(1);
}

function showLoadingMessage() {
  document.getElementById("loadingMessage").style.display = "block";
}

function hideLoadingMessage() {
  document.getElementById("loadingMessage").style.display = "none";
}

function showResult() {
  clearTurboTimer();
  document.getElementById("game").classList.add("hidden");
  document.getElementById("result").classList.remove("hidden");
  document.getElementById("score").textContent = score;

  const recap = document.getElementById("recap");
  recap.innerHTML = "";
  rounds.forEach((round, index) => {
    if (round.mode === "soft") {
      appendSoftRecap(recap, round, index);
    } else {
      appendAdvancedRecap(recap, round, index);
    }
  });
}

function appendSoftRecap(recap, round, index) {
  const pairDiv = document.createElement("div");
  pairDiv.className = `recap-pair ${round.user === round.correct ? "correct" : "wrong"}`;

  const mappingEntry = imageMapping[round.id];
  const img1 = createRecapImage(
    `assets/${round.iaFirst ? mappingEntry.b : mappingEntry.a}`,
    `Round ${index + 1}, first image`
  );
  const img2 = createRecapImage(
    `assets/${round.iaFirst ? mappingEntry.a : mappingEntry.b}`,
    `Round ${index + 1}, second image`
  );

  markUserChoice(img1, round.user === 0, round.user === round.correct);
  markUserChoice(img2, round.user === 1, round.user === round.correct);
  pairDiv.appendChild(img1);
  pairDiv.appendChild(img2);
  recap.appendChild(pairDiv);
}

function appendAdvancedRecap(recap, round, index) {
  const roundDiv = document.createElement("div");
  roundDiv.className = `recap-advanced ${round.user === round.correct ? "correct" : "wrong"}`;

  const mappingEntry = imageMapping[round.id];
  const imageType = round.displayedType === "ai" ? mappingEntry.b : mappingEntry.a;
  const image = createRecapImage(`assets/${imageType}`, `Round ${index + 1}`);
  const answer = document.createElement("p");
  const expectedLabel = round.correct === "ai" ? "AI" : "REAL";
  const userLabel = round.timedOut ? "No answer" : round.user === "ai" ? "AI" : "REAL";
  answer.textContent = `${userLabel} · Correct answer: ${expectedLabel}`;

  roundDiv.appendChild(image);
  roundDiv.appendChild(answer);
  recap.appendChild(roundDiv);
}

function createRecapImage(source, alt) {
  const image = document.createElement("img");
  image.src = source;
  image.alt = alt;
  return image;
}

function markUserChoice(image, isSelected, wasCorrect) {
  if (!isSelected) return;
  image.classList.add(wasCorrect ? "user-correct" : "user-wrong");
}
