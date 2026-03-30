%%% ==========================================================================
%%% negative_examples.pl  –  Negative training examples for ALEPH
%%% IAS 4A – ESIEA  |  HW2-ILP
%%%
%%% Negative examples are (State, CellToTest, WrongEpistemicValue) triples.
%%% They represent states where a specific epistemic value does NOT hold.
%%% These constrain the hypothesis to avoid over-generalisation.
%%% ==========================================================================

:- begin_in_neg.

%% A cell in knownFalse list should NOT be orTrue
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,2)]),eatwumpus(orTrue,[])],
       [], cell(1,2), orTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,3),cell(1,2)]),eatwumpus(orTrue,[])],
       [], cell(2,3), orTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,2)]),eatwumpus(orTrue,[])],
       [], cell(3,2), orTrue).

%% A cell in knownFalse should NOT be knownTrue
wumpus(cell(3,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(3,1),cell(2,2),cell(4,2)]),eatwumpus(orTrue,[])],
       [], cell(3,1), knownTrue).

wumpus(cell(1,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(0,2)]),eatwumpus(orTrue,[cell(2,2)])],
       [stench], cell(1,1), knownTrue).

%% A cell in knownTrue should NOT be knownFalse
wumpus(cell(2,3),
       [eatwumpus(knownTrue,[cell(2,2)]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[])],
       [], cell(2,2), knownFalse).

wumpus(cell(3,1),
       [eatwumpus(knownTrue,[cell(4,1)]),eatwumpus(knownFalse,[cell(2,1)]),eatwumpus(orTrue,[])],
       [stench], cell(4,1), knownFalse).

%% Without stench, adjacent cells should not be orTrue (no evidence)
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[])],
       [], cell(1,2), orTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[])],
       [], cell(2,3), orTrue).

%% orTrue cell without stench should not be knownTrue
wumpus(cell(3,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2),cell(4,2),cell(3,3)]),eatwumpus(orTrue,[cell(3,1)])],
       [], cell(3,1), knownTrue).

%% A completely unexplored cell should not be knownTrue with no evidence
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[])],
       [], cell(4,4), knownTrue).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[]),eatwumpus(orTrue,[cell(2,3)])],
       [stench], cell(4,4), knownTrue).

%% A cell in knownTrue should not be unknown
wumpus(cell(1,3),
       [eatwumpus(knownTrue,[cell(1,4)]),eatwumpus(knownFalse,[cell(0,3)]),eatwumpus(orTrue,[])],
       [stench], cell(1,4), unknown).

%% A cell adjacent to stench with no alternatives should not be unknown
wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,2),cell(2,3),cell(3,2)]),eatwumpus(orTrue,[cell(2,1)])],
       [stench], cell(2,1), unknown).

%% A cell that is orTrue should not be knownFalse
wumpus(cell(1,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(0,2),cell(1,1)]),eatwumpus(orTrue,[cell(1,3),cell(2,2)])],
       [stench], cell(1,3), knownFalse).

wumpus(cell(3,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2)]),eatwumpus(orTrue,[cell(3,3),cell(4,2)])],
       [stench], cell(3,3), knownFalse).

%% A distant cell (not adjacent to hunter) with no info ≠ knownFalse
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(1,2)]),eatwumpus(orTrue,[])],
       [], cell(4,4), knownFalse).

wumpus(cell(2,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,1),cell(1,1)]),eatwumpus(orTrue,[cell(3,1)])],
       [stench], cell(4,4), knownFalse).

%% A cell in knownFalse list should NOT be unknown
wumpus(cell(1,1),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(1,1),cell(2,1)]),eatwumpus(orTrue,[])],
       [], cell(1,1), unknown).

wumpus(cell(2,2),
       [eatwumpus(knownTrue,[]),eatwumpus(knownFalse,[cell(2,2),cell(3,2)]),eatwumpus(orTrue,[])],
       [], cell(3,2), unknown).

:- end_in_neg.
