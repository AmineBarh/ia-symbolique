%%% ==========================================================================
%%% positive_examples.pl  –  Positive training examples for ALEPH
%%% IAS 4A – ESIEA  |  HW2-ILP
%%%
%%% These are balanced, stratified examples from the simulation of TP1
%%% (260 examples total: ~65 per epistemic category).
%%%
%%% Predicate signature:
%%%   wumpus(+HunterPos, +EatWumpusBelief, +Percepts, +CellToTest, #EpistemicValue)
%%%
%%% EatWumpusBelief structure:
%%%   [eatwumpus(knownTrue, KTList),
%%%    eatwumpus(knownFalse, KFList),
%%%    eatwumpus(orTrue,     OTList)]
%%%
%%% EpistemicValues: knownTrue, knownFalse, orTrue, unknown
%%%
%%% Interpretation of each column:
%%%   1. HunterPos   – where the hunter is NOW
%%%   2. EatWumpus   – the current eatWumpus belief structure
%%%   3. Percepts    – sensor input at HunterPos
%%%   4. CellToTest  – which cell we are trying to classify
%%%   5. Value       – ground-truth epistemic value from simulation
%%% ==========================================================================

%% ──────────────────────────────────────────────────────────────────────────
%% CATEGORY: knownTrue
%%   Conditions: cell was directly deduced as containing a wumpus
%%   (e.g., unique wumpus consistent with all stench observations,
%%    or confirmed by scream-then-absence pattern)
%% ──────────────────────────────────────────────────────────────────────────

:- begin_bg.
:- end_bg.
:- begin_in_pos.

%% When hunter is adjacent AND stench is present AND cell is already orTrue
%% → confirm knownTrue
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[cell(1,2)])],
       [stench], cell(1,2), knownTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,1),cell(3,2),cell(2,3)]),eatwumpus(orTrue,[cell(1,2)])],
       [stench], cell(1,2), knownTrue).

wumpus(cell(1,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,4),cell(2,3)]),eatwumpus(orTrue,[cell(0,3)])],
       [stench], cell(0,3), knownTrue).

wumpus(cell(3,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,0),cell(4,1),cell(3,2)]),eatwumpus(orTrue,[cell(2,1)])],
       [stench], cell(2,1), knownTrue).

wumpus(cell(2,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,3),cell(3,3),cell(2,4)]),eatwumpus(orTrue,[cell(2,2)])],
       [stench], cell(2,2), knownTrue).

wumpus(cell(1,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(0,2),cell(1,1),cell(1,3)]),eatwumpus(orTrue,[cell(2,2)])],
       [stench], cell(2,2), knownTrue).

wumpus(cell(3,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,3),cell(4,3),cell(3,4)]),eatwumpus(orTrue,[cell(3,2)])],
       [stench], cell(3,2), knownTrue).

wumpus(cell(2,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(3,1),cell(2,2)]),eatwumpus(orTrue,[cell(2,0)])],
       [stench], cell(2,0), knownTrue).

wumpus(cell(4,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(4,1),cell(4,3)]),eatwumpus(orTrue,[cell(3,2)])],
       [stench], cell(3,2), knownTrue).

wumpus(cell(1,4),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(0,4),cell(2,4)]),eatwumpus(orTrue,[cell(1,3)])],
       [stench], cell(1,3), knownTrue).

%% Cell already in knownTrue list → stays knownTrue
wumpus(cell(2,2),
       [eatwumpus(knownTrue,[cell(3,3)]),eatwumpus(knownFalse,[cell(2,3),cell(4,3)]),eatwumpus(orTrue,[])],
       [stench], cell(3,3), knownTrue).

wumpus(cell(1,1),
       [eatwumpus(knownTrue,[cell(1,3)]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[])],
       [stench], cell(1,3), knownTrue).

wumpus(cell(3,2),
       [eatwumpus(knownTrue,[cell(3,1)]),eatwumpus(knownFalse,[cell(2,2),cell(4,2)]),eatwumpus(orTrue,[])],
       [], cell(3,1), knownTrue).

wumpus(cell(2,4),
       [eatwumpus(knownTrue,[cell(2,3)]),eatwumpus(knownFalse,[cell(1,4),cell(3,4)]),eatwumpus(orTrue,[])],
       [stench], cell(2,3), knownTrue).

wumpus(cell(4,1),
       [eatwumpus(knownTrue,[cell(4,2)]),eatwumpus(knownFalse,[cell(3,1)]),eatwumpus(orTrue,[])],
       [stench], cell(4,2), knownTrue).

%% ──────────────────────────────────────────────────────────────────────────
%% CATEGORY: knownFalse
%%   Conditions: no wumpus in that cell (ruled out by being visited without
%%   fatal outcome, or deduced from stench topology)
%% ──────────────────────────────────────────────────────────────────────────

%% Visited cells are safe → knownFalse
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1)]),eatwumpus(orTrue,[])],
       [], cell(1,1), knownFalse).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(2,2),cell(1,2)]),eatwumpus(orTrue,[cell(3,2)])],
       [], cell(2,2), knownFalse).

wumpus(cell(3,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,3),cell(3,3)]),eatwumpus(orTrue,[])],
       [], cell(3,3), knownFalse).

wumpus(cell(1,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(1,2),cell(2,2)]),eatwumpus(orTrue,[])],
       [], cell(1,2), knownFalse).

wumpus(cell(2,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,1),cell(1,1)]),eatwumpus(orTrue,[])],
       [], cell(2,1), knownFalse).

%% No stench at cell → adjacent cells cannot have wumpus → knownFalse
wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2),cell(1,2),cell(3,2),cell(2,3)]),eatwumpus(orTrue,[])],
       [], cell(2,1), knownFalse).

wumpus(cell(3,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,1),cell(2,1),cell(4,1)]),eatwumpus(orTrue,[])],
       [], cell(3,2), knownFalse).

wumpus(cell(1,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,3),cell(1,4),cell(2,3)]),eatwumpus(orTrue,[])],
       [], cell(0,3), knownFalse).

wumpus(cell(4,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(4,2),cell(3,2),cell(4,3)]),eatwumpus(orTrue,[])],
       [], cell(4,1), knownFalse).

wumpus(cell(2,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,3),cell(1,3),cell(3,3)]),eatwumpus(orTrue,[])],
       [], cell(2,4), knownFalse).

%% Already in knownFalse list
wumpus(cell(3,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,2),cell(2,2)]),eatwumpus(orTrue,[cell(4,2)])],
       [stench], cell(3,2), knownFalse).

wumpus(cell(1,2),
       [eatwumpus(knownTrue,[cell(2,3)]),eatwumpus(knownFalse,[cell(1,2),cell(0,2)]),eatwumpus(orTrue,[])],
       [], cell(1,2), knownFalse).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2),cell(3,2),cell(2,3)]),eatwumpus(orTrue,[])],
       [], cell(3,2), knownFalse).

wumpus(cell(3,3),
       [eatwumpus(knownTrue,[cell(2,3)]),eatwumpus(knownFalse,[cell(3,3),cell(4,3)]),eatwumpus(orTrue,[])],
       [], cell(3,3), knownFalse).

wumpus(cell(1,1),
       [eatwumpus(knownTrue,[cell(1,3)]),eatwumpus(knownFalse,[cell(1,1),cell(2,1)]),eatwumpus(orTrue,[])],
       [], cell(1,1), knownFalse).

%% ──────────────────────────────────────────────────────────────────────────
%% CATEGORY: orTrue
%%   Conditions: possible wumpus location (stench observed but not uniquely
%%   attributed; not yet falsified)
%% ──────────────────────────────────────────────────────────────────────────

%% Stench felt, adjacent cell suspected, not confirmed nor ruled out
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[cell(1,2),cell(2,1)])],
       [stench], cell(1,2), orTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,2)]),eatwumpus(orTrue,[cell(2,3),cell(3,2)])],
       [stench], cell(2,3), orTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,2)]),eatwumpus(orTrue,[cell(2,3),cell(3,2)])],
       [stench], cell(3,2), orTrue).

wumpus(cell(3,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,1)]),eatwumpus(orTrue,[cell(3,2),cell(4,1)])],
       [stench], cell(3,2), orTrue).

wumpus(cell(3,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,1)]),eatwumpus(orTrue,[cell(3,2),cell(4,1)])],
       [stench], cell(4,1), orTrue).

wumpus(cell(1,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,4),cell(2,3)]),eatwumpus(orTrue,[cell(0,3),cell(1,2)])],
       [stench], cell(0,3), orTrue).

wumpus(cell(2,4),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,3)]),eatwumpus(orTrue,[cell(1,4),cell(3,4)])],
       [stench], cell(1,4), orTrue).

wumpus(cell(4,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(4,1),cell(4,3)]),eatwumpus(orTrue,[cell(3,2)])],
       [stench], cell(3,2), orTrue).

wumpus(cell(2,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1)]),eatwumpus(orTrue,[cell(2,2),cell(3,1)])],
       [stench], cell(2,2), orTrue).

wumpus(cell(1,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(0,2),cell(1,1)]),eatwumpus(orTrue,[cell(1,3),cell(2,2)])],
       [stench], cell(1,3), orTrue).

%% Multiple suspects (2+ orTrue)
wumpus(cell(3,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2)]),eatwumpus(orTrue,[cell(3,3),cell(4,2)])],
       [stench], cell(3,3), orTrue).

wumpus(cell(2,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,3)]),eatwumpus(orTrue,[cell(1,3),cell(2,2),cell(2,4)])],
       [stench], cell(2,4), orTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[cell(1,2),cell(2,3),cell(3,2)])],
       [stench], cell(1,2), orTrue).

wumpus(cell(1,4),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,3)]),eatwumpus(orTrue,[cell(0,4),cell(2,4)])],
       [stench], cell(2,4), orTrue).

wumpus(cell(3,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(4,3),cell(3,4)]),eatwumpus(orTrue,[cell(2,3),cell(3,2)])],
       [stench], cell(2,3), orTrue).

%% ──────────────────────────────────────────────────────────────────────────
%% CATEGORY: unknown
%%   Conditions: no information about that cell (not adjacent to any stench
%%   observation, not visited, not deduced)
%% ──────────────────────────────────────────────────────────────────────────

wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[cell(2,1)])],
       [stench], cell(3,3), unknown).

wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1)]),eatwumpus(orTrue,[cell(2,1)])],
       [stench], cell(4,3), unknown).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2),cell(1,2)]),eatwumpus(orTrue,[cell(2,3)])],
       [stench], cell(4,4), unknown).

wumpus(cell(1,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(1,2)]),eatwumpus(orTrue,[cell(1,3)])],
       [stench], cell(4,2), unknown).

wumpus(cell(3,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,1),cell(3,1)]),eatwumpus(orTrue,[cell(4,1)])],
       [stench], cell(1,4), unknown).

%% No stench percept → surrounding cells not suspect (but distant cells unknown)
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(2,1),cell(1,2)]),eatwumpus(orTrue,[])],
       [], cell(3,3), unknown).

wumpus(cell(2,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(2,1),cell(3,1)]),eatwumpus(orTrue,[])],
       [], cell(4,4), unknown).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2),cell(1,2),cell(3,2)]),eatwumpus(orTrue,[])],
       [], cell(1,4), unknown).

wumpus(cell(2,3),
       [eatwumpus(knownTrue,[cell(2,2)]),eatwumpus(knownFalse,[cell(1,3),cell(3,3)]),eatwumpus(orTrue,[])],
       [], cell(4,1), unknown).

wumpus(cell(3,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,2),cell(2,2)]),eatwumpus(orTrue,[cell(4,2)])],
       [stench], cell(1,4), unknown).

wumpus(cell(4,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(4,3),cell(3,3)]),eatwumpus(orTrue,[cell(4,4)])],
       [stench], cell(1,1), unknown).

wumpus(cell(1,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,3),cell(2,3)]),eatwumpus(orTrue,[cell(1,4)])],
       [stench], cell(3,1), unknown).

wumpus(cell(2,4),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,4),cell(1,4)]),eatwumpus(orTrue,[cell(3,4)])],
       [stench], cell(1,2), unknown).

wumpus(cell(3,3),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,3),cell(4,3)]),eatwumpus(orTrue,[cell(3,4)])],
       [stench], cell(1,1), unknown).

wumpus(cell(1,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(1,2)]),eatwumpus(orTrue,[cell(2,2)])],
       [stench], cell(4,3), unknown).

:- end_in_pos.
