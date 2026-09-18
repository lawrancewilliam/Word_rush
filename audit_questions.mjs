// WORD RUSH - Question Audit Script
// Validates all 65 questions (3 games x 20 + 5 tiebreakers)
// MIGRATION 008: Game 3 replaced with Freshers-friendly word set.
// Every Game 3 word has >= 5 letters and is genuinely shuffled.
// MIGRATION 007: All 65 jumbles upgraded to strong shuffles.

const questions = [
  // GAME 1 (20 questions)
  { game: 1, order: 1, answer: 'CANTEEN', jumble: 'E N C A T N E', hint: 'A place where students buy food during breaks', difficulty: 'EASY', category: 'Food', tiebreaker: false },
  { game: 1, order: 2, answer: 'LIBRARY', jumble: 'Y B R I A L R', hint: 'A quiet place full of books', difficulty: 'EASY', category: 'College', tiebreaker: false },
  { game: 1, order: 3, answer: 'HOSTEL', jumble: 'L S T O E H', hint: 'Where students stay during college years', difficulty: 'EASY', category: 'College', tiebreaker: false },
  { game: 1, order: 4, answer: 'KEYBOARD', jumble: 'B R D K A Y O E', hint: 'You type on this device', difficulty: 'EASY', category: 'Technology', tiebreaker: false },
  { game: 1, order: 5, answer: 'BROWSER', jumble: 'O S W R B R E', hint: 'You use this to surf the internet', difficulty: 'EASY', category: 'Technology', tiebreaker: false },
  { game: 1, order: 6, answer: 'SANDWICH', jumble: 'W A N C S H D I', hint: 'Bread with filling, great for a quick snack', difficulty: 'EASY', category: 'Food', tiebreaker: false },
  { game: 1, order: 7, answer: 'NOODLES', jumble: 'L D S O N E O', hint: 'Long thin strands often served in soup', difficulty: 'EASY', category: 'Food', tiebreaker: false },
  { game: 1, order: 8, answer: 'CRICKET', jumble: 'K T C E I R C', hint: 'A bat and ball sport popular in India', difficulty: 'EASY', category: 'Sports', tiebreaker: false },
  { game: 1, order: 9, answer: 'CINEMA', jumble: 'A M I C E N', hint: 'Where you go to watch movies', difficulty: 'EASY', category: 'Entertainment', tiebreaker: false },
  { game: 1, order: 10, answer: 'CHAMPION', jumble: 'P M A H I C N O', hint: 'The one who wins the final prize', difficulty: 'MEDIUM', category: 'General', tiebreaker: false },
  { game: 1, order: 11, answer: 'ADVENTURE', jumble: 'T E U D E R V A N', hint: 'A thrilling journey into the unknown', difficulty: 'MEDIUM', category: 'General', tiebreaker: false },
  { game: 1, order: 12, answer: 'MYSTERY', jumble: 'T E Y R S Y M', hint: 'A story full of puzzles and secrets', difficulty: 'MEDIUM', category: 'Entertainment', tiebreaker: false },
  { game: 1, order: 13, answer: 'FOOTBALL', jumble: 'O L A F T L O B', hint: "The world's most popular sport with goals", difficulty: 'MEDIUM', category: 'Sports', tiebreaker: false },
  { game: 1, order: 14, answer: 'INTERNET', jumble: 'T N E R I T E N', hint: 'The global network connecting everyone', difficulty: 'MEDIUM', category: 'Technology', tiebreaker: false },
  { game: 1, order: 15, answer: 'PROGRAM', jumble: 'G O M R R A P', hint: 'A set of instructions for a computer', difficulty: 'MEDIUM', category: 'Technology', tiebreaker: false },
  { game: 1, order: 16, answer: 'MOUNTAIN', jumble: 'T N U M O A N I', hint: 'A very tall natural landform', difficulty: 'MEDIUM', category: 'General', tiebreaker: false },
  { game: 1, order: 17, answer: 'DOLPHIN', jumble: 'L D P I N H O', hint: 'An intelligent ocean creature', difficulty: 'MEDIUM', category: 'General', tiebreaker: false },
  { game: 1, order: 18, answer: 'ROBOTICS', jumble: 'O C S I B T R O', hint: 'The branch of technology dealing with robots', difficulty: 'HARD', category: 'Technology', tiebreaker: false },
  { game: 1, order: 19, answer: 'CHEMISTRY', jumble: 'Y M C H I T S R E', hint: 'The science of substances and reactions', difficulty: 'HARD', category: 'College', tiebreaker: false },
  { game: 1, order: 20, answer: 'ALGORITHM', jumble: 'R I G O T L A M H', hint: 'A step-by-step procedure for solving a problem', difficulty: 'HARD', category: 'Technology', tiebreaker: false },

  // GAME 2 (20 questions)
  { game: 2, order: 1, answer: 'CAFETERIA', jumble: 'F E I R C A T A E', hint: 'Another name for a dining hall', difficulty: 'EASY', category: 'College', tiebreaker: false },
  { game: 2, order: 2, answer: 'BICYCLE', jumble: 'C L Y I E B C', hint: 'A two-wheeled vehicle you pedal', difficulty: 'EASY', category: 'Sports', tiebreaker: false },
  { game: 2, order: 3, answer: 'PUZZLE', jumble: 'Z P L Z E U', hint: 'A game that tests your problem-solving', difficulty: 'EASY', category: 'Entertainment', tiebreaker: false },
  { game: 2, order: 4, answer: 'JUNGLE', jumble: 'N G E L U J', hint: 'A dense tropical forest', difficulty: 'EASY', category: 'General', tiebreaker: false },
  { game: 2, order: 5, answer: 'PENCIL', jumble: 'N E C P L I', hint: 'You write and draw with this', difficulty: 'EASY', category: 'College', tiebreaker: false },
  { game: 2, order: 6, answer: 'MIRROR', jumble: 'R R I O R M', hint: 'Shows your reflection', difficulty: 'EASY', category: 'General', tiebreaker: false },
  { game: 2, order: 7, answer: 'GUITAR', jumble: 'A U G R T I', hint: 'A stringed musical instrument', difficulty: 'EASY', category: 'Entertainment', tiebreaker: false },
  { game: 2, order: 8, answer: 'ISLAND', jumble: 'S D N I L A', hint: 'Land completely surrounded by water', difficulty: 'EASY', category: 'General', tiebreaker: false },
  { game: 2, order: 9, answer: 'VOLCANO', jumble: 'C L O N V O A', hint: 'A mountain that can erupt with lava', difficulty: 'EASY', category: 'General', tiebreaker: false },
  { game: 2, order: 10, answer: 'SYLLABUS', jumble: 'B L Y A S L S U', hint: 'Outline of topics covered in a course', difficulty: 'MEDIUM', category: 'College', tiebreaker: false },
  { game: 2, order: 11, answer: 'TROPHY', jumble: 'H Y T R O P', hint: 'An award given to winners', difficulty: 'MEDIUM', category: 'Sports', tiebreaker: false },
  { game: 2, order: 12, answer: 'BALLOON', jumble: 'A B L N L O O', hint: 'Inflatable object filled with air or gas', difficulty: 'MEDIUM', category: 'General', tiebreaker: false },
  { game: 2, order: 13, answer: 'KITCHEN', jumble: 'C H E K T N I', hint: 'Room where food is cooked', difficulty: 'MEDIUM', category: 'General', tiebreaker: false },
  { game: 2, order: 14, answer: 'PIRATE', jumble: 'A T I E R P', hint: 'A seafaring robber of the high seas', difficulty: 'MEDIUM', category: 'Entertainment', tiebreaker: false },
  { game: 2, order: 15, answer: 'SOLAR', jumble: 'R L O S A', hint: 'Related to the sun', difficulty: 'MEDIUM', category: 'Technology', tiebreaker: false },
  { game: 2, order: 16, answer: 'MARBLE', jumble: 'B A E L R M', hint: 'A smooth stone or glass ball for games', difficulty: 'MEDIUM', category: 'General', tiebreaker: false },
  { game: 2, order: 17, answer: 'OXYGEN', jumble: 'X E Y G N O', hint: 'The gas we breathe to survive', difficulty: 'HARD', category: 'College', tiebreaker: false },
  { game: 2, order: 18, answer: 'BACTERIA', jumble: 'R C A I A T B E', hint: 'Microscopic single-celled organisms', difficulty: 'HARD', category: 'College', tiebreaker: false },
  { game: 2, order: 19, answer: 'QUANTUM', jumble: 'N A U Q T M U', hint: 'The smallest discrete unit in physics', difficulty: 'HARD', category: 'Technology', tiebreaker: false },
  { game: 2, order: 20, answer: 'NEURON', jumble: 'R N E N U O', hint: 'A nerve cell that carries information', difficulty: 'HARD', category: 'College', tiebreaker: false },

  // GAME 3 (20 questions) - MIGRATION 008 word set
  { game: 3, order: 1, answer: 'MANGO', jumble: 'G M A O N', hint: 'A popular sweet fruit that is usually yellow when ripe', difficulty: 'EASY', category: 'General', tiebreaker: false },
  { game: 3, order: 2, answer: 'TIGER', jumble: 'G R I T E', hint: 'A wild animal known for its black stripes', difficulty: 'EASY', category: 'Animals', tiebreaker: false },
  { game: 3, order: 3, answer: 'TABLE', jumble: 'E B T A L', hint: 'You keep books and other items on this', difficulty: 'EASY', category: 'Daily Use', tiebreaker: false },
  { game: 3, order: 4, answer: 'HORSE', jumble: 'R E H O S', hint: 'An animal that people can ride', difficulty: 'EASY', category: 'Animals', tiebreaker: false },
  { game: 3, order: 5, answer: 'CLOCK', jumble: 'O C L K C', hint: 'It tells you the time', difficulty: 'EASY', category: 'Daily Use', tiebreaker: false },
  { game: 3, order: 6, answer: 'BOTTLE', jumble: 'L T B O E T', hint: 'Used to carry water or other drinks', difficulty: 'MEDIUM', category: 'Daily Use', tiebreaker: false },
  { game: 3, order: 7, answer: 'MONKEY', jumble: 'N E O Y K M', hint: 'An animal known for climbing trees', difficulty: 'MEDIUM', category: 'Animals', tiebreaker: false },
  { game: 3, order: 8, answer: 'PENCIL', jumble: 'N L E P C I', hint: 'Used for writing and can be erased', difficulty: 'MEDIUM', category: 'College', tiebreaker: false },
  { game: 3, order: 9, answer: 'RABBIT', jumble: 'B T A R B I', hint: 'A small animal with long ears', difficulty: 'MEDIUM', category: 'Animals', tiebreaker: false },
  { game: 3, order: 10, answer: 'POCKET', jumble: 'O T E C P K', hint: 'A small part of clothing used to carry things', difficulty: 'MEDIUM', category: 'Daily Use', tiebreaker: false },
  { game: 3, order: 11, answer: 'MARKER', jumble: 'E R K R A M', hint: 'Often used to write on a classroom whiteboard', difficulty: 'MEDIUM', category: 'College', tiebreaker: false },
  { game: 3, order: 12, answer: 'GIRAFFE', jumble: 'F R E F G A I', hint: 'The tallest living land animal', difficulty: 'MEDIUM', category: 'Animals', tiebreaker: false },
  { game: 3, order: 13, answer: 'WALLET', jumble: 'L T E W L A', hint: 'Used to carry money and cards', difficulty: 'MEDIUM', category: 'Daily Use', tiebreaker: false },
  { game: 3, order: 14, answer: 'KEYBOARD', jumble: 'B D E R Y O K A', hint: 'Used to type letters and commands into a computer', difficulty: 'MEDIUM', category: 'Technology', tiebreaker: false },
  { game: 3, order: 15, answer: 'NOTEBOOK', jumble: 'O K B O N E T O', hint: 'Students use this to write notes', difficulty: 'MEDIUM', category: 'College', tiebreaker: false },
  { game: 3, order: 16, answer: 'ELEPHANT', jumble: 'H E T L A N P E', hint: 'A very large animal with a trunk', difficulty: 'HARD', category: 'Animals', tiebreaker: false },
  { game: 3, order: 17, answer: 'PROJECTOR', jumble: 'J O P T R E O R C', hint: 'Used to display a computer screen on a large surface', difficulty: 'HARD', category: 'College', tiebreaker: false },
  { game: 3, order: 18, answer: 'UMBRELLA', jumble: 'L R U E M B A L', hint: 'Commonly used to protect you from rain', difficulty: 'HARD', category: 'Daily Use', tiebreaker: false },
  { game: 3, order: 19, answer: 'CALCULATOR', jumble: 'U O C R A T C L A L', hint: 'A device used to perform numerical calculations', difficulty: 'HARD', category: 'College', tiebreaker: false },
  { game: 3, order: 20, answer: 'HEADPHONES', jumble: 'N D E P O E S H A H', hint: 'Worn over or in the ears to listen to audio privately', difficulty: 'HARD', category: 'Daily Use', tiebreaker: false },

  // TIEBREAKERS (5 questions)
  { game: 1, order: 21, answer: 'WIZARD', jumble: 'D A R W I Z', hint: 'A person who practices magic', difficulty: 'EASY', category: 'Entertainment', tiebreaker: true },
  { game: 2, order: 21, answer: 'GALAXY', jumble: 'Y G A X A L', hint: 'A massive system of stars', difficulty: 'MEDIUM', category: 'General', tiebreaker: true },
  { game: 3, order: 21, answer: 'PHOENIX', jumble: 'H N P I E X O', hint: 'A mythical bird that rises from ashes', difficulty: 'MEDIUM', category: 'General', tiebreaker: true },
  { game: 1, order: 22, answer: 'LABYRINTH', jumble: 'B I Y R A H N L T', hint: 'An elaborate maze', difficulty: 'HARD', category: 'General', tiebreaker: true },
  { game: 2, order: 22, answer: 'RENAISSANCE', jumble: 'A I E N R S A E N C S', hint: 'A period of cultural rebirth in Europe', difficulty: 'HARD', category: 'General', tiebreaker: true },
];

function sortString(s) {
  return s.split('').sort().join('');
}

function getSamePositionCount(answer, jumble) {
  let count = 0;
  const minLen = Math.min(answer.length, jumble.length);
  for (let i = 0; i < minLen; i++) {
    if (answer[i] === jumble[i]) count++;
  }
  return count;
}

function diffPositions(answer, jumble) {
  const d = [];
  for (let i = 0; i < Math.min(answer.length, jumble.length); i++) {
    if (answer[i] !== jumble[i]) d.push(i);
  }
  return d;
}

const results = [];
let integrityPass = 0;
let shuffledPass = 0;
let weakPass = 0;
let failCount = 0;
const failures = [];
const warnings = [];

for (const q of questions) {
  const jumbleFlat = q.jumble.replace(/ /g, '');
  const answer = q.answer;

  const lengthOk = answer.length === jumbleFlat.length;
  const anagramOk = sortString(answer) === sortString(jumbleFlat);
  const integrityOk = lengthOk && anagramOk;

  const notEqual = answer !== jumbleFlat;
  const samePosCount = getSamePositionCount(answer, jumbleFlat);
  const samePosRatio = samePosCount / answer.length;
  const diffs = diffPositions(answer, jumbleFlat);
  const firstMoved = answer[0] !== jumbleFlat[0];
  const lastMoved = answer[answer.length - 1] !== jumbleFlat[jumbleFlat.length - 1];
  const noPrefix = answer.slice(0, 2) !== jumbleFlat.slice(0, 2);
  const noSuffix = answer.slice(-2) !== jumbleFlat.slice(-2);
  const notSimpleSwap = diffs.length > 2;
  const minLenOk = q.game === 3 && !q.tiebreaker ? answer.length >= 5 : true;

  const integrityOkFull = integrityOk && minLenOk;
  const shuffledOk = notEqual;
  const weakOk = notEqual && samePosRatio <= 0.5 && notSimpleSwap && firstMoved && lastMoved && noPrefix && noSuffix;

  const label = `G${q.game} Q${q.order}${q.tiebreaker ? ' (TB)' : ''}: ${answer}`;
  const flags = [];

  if (!lengthOk) flags.push(`LENGTH MISMATCH: answer=${answer.length} jumble=${jumbleFlat.length}`);
  if (!anagramOk) flags.push('ANAGRAM FAIL: sorted letters differ');
  if (!minLenOk) flags.push('MIN LENGTH: Game 3 word shorter than 5 letters');
  if (!notEqual) flags.push('CRITICAL: jumble equals answer (UNSHUFFLED)');
  if (samePosRatio > 0.6) flags.push(`WEAK SHUFFLE: samePositionCount=${samePosCount}/${answer.length} (${(samePosRatio * 100).toFixed(0)}%)`);
  if (!notSimpleSwap) flags.push('SIMPLE SWAP: 2 or fewer positions differ');
  if (!firstMoved) flags.push('FIRST LETTER UNMOVED');
  if (!lastMoved) flags.push('LAST LETTER UNMOVED');
  if (!noPrefix) flags.push('ORIGINAL PREFIX RETAINED');
  if (!noSuffix) flags.push('ORIGINAL SUFFIX RETAINED');

  const passed = integrityOkFull && shuffledOk && weakOk;
  const status = passed ? 'PASS' : 'FAIL';

  if (integrityOkFull) integrityPass++; else failCount++;
  if (shuffledOk) shuffledPass++;
  if (passed) weakPass++;
  if (!passed) failures.push(label + ': ' + flags.join('; '));
  if (passed && flags.length > 0) warnings.push(label + ': ' + flags.join('; '));

  results.push({ label, status, answer, answerLength: answer.length, jumbleFlat, jumbleSpaced: q.jumble, samePosCount, samePosRatio, diffs: diffs.length, flags, integrityOkFull, shuffledOk, weakOk, minLenOk });
}

// Print detailed results
console.log('='.repeat(84));
console.log('  WORD RUSH - QUESTION AUDIT REPORT (65 questions: G1 20 + G2 20 + G3 20 + TB 5)');
console.log('='.repeat(84));
console.log();

let block = null;
let blockName = '';
for (const r of results) {
  const gameLabel = r.label.startsWith('G1') ? 'GAME 1' : r.label.startsWith('G2') ? 'GAME 2' : (r.label.startsWith('G3') && !r.label.includes('TB')) ? 'GAME 3' : 'TIE BREAKER';
  if (gameLabel !== blockName) {
    console.log(`--- ${gameLabel} ---`);
    blockName = gameLabel;
  }

  const icon = r.status === 'PASS' ? 'PASS' : 'FAIL';
  console.log(`  ${icon === 'PASS' ? 'PASS' : 'FAIL'}  ${r.label}`);
  console.log(`      Answer:   ${r.answer} (${r.answerLength} chars)  |  Jumble: ${r.jumbleSpaced}`);
  console.log(`      Same pos: ${r.samePosCount}/${r.answerLength} (${(r.samePosRatio * 100).toFixed(0)}%)   Diffs: ${r.diffs}`);
  if (r.flags.length > 0) {
    for (const f of r.flags) console.log(`      !! ${f}`);
  }
  console.log();
}

console.log('='.repeat(84));
console.log('  SUMMARY');
console.log('='.repeat(84));
const total = results.length;
console.log(`  Total questions:                        ${total}`);
console.log(`  LETTER INTEGRITY PASS:                  ${integrityPass} / ${total}`);
console.log(`  ACTUALLY SHUFFLED PASS:                 ${shuffledPass} / ${total}`);
console.log(`  FULL PASS (integrity + shuffled + quality): ${weakPass} / ${total}`);
console.log(`  FAIL:                                   ${failCount + (shuffledPass === total ? 0 : total - shuffledPass)}`);
console.log();

if (failures.length > 0) {
  console.log('  FAILURES:');
  for (const f of failures) console.log(`    FAIL ${f}`);
  console.log();
}

const badExamples = results.filter(r => r.jumbleFlat === r.answer);
console.log('  UN-SHUFFLED EXAMPLES (must be zero):', badExamples.length);
const g3 = results.filter(r => r.label.startsWith('G3') && !r.label.includes('TB'));
const g3min = g3.filter(r => r.answerLength >= 5);
console.log(`  Game 3 words with >= 5 letters:         ${g3min.length} / 20`);

const duplicates = [];
for (let i = 0; i < results.length; i++) {
  for (let j = i + 1; j < results.length; j++) {
    if (results[i].jumbleFlat === results[j].jumbleFlat) {
      duplicates.push(`${results[i].label} == ${results[j].label}`);
    }
  }
}
console.log(duplicates.length ? `  DUPLICATE JUMBLES: ${duplicates.join(', ')}` : '  No duplicate jumbles found.');
console.log();
console.log(`  RESULT: ${(integrityPass === total && shuffledPass === total && weakPass === total) ? 'ALL 65 QUESTIONS VALID' : 'VALIDATION NOT FULLY PASSING'}`);
console.log('='.repeat(84));