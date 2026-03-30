%% wumpus_cbr.pl
%% Case-Based Reasoning replacement for the hand-coded wumpus/5 rules
%% (lines 650-670 in hunter.pl).
%%
%% ── HOW TO INTEGRATE INTO hunter.pl ─────────────────────────────────────────
%%   1. Delete lines 650-670 from hunter.pl (the wumpus/5 block).
%%   2. At the top of hunter.pl, replace:
%%        :- use_module('theory_wumpus.pl', []).
%%      with:
%%        :- use_module('wumpus_cbr', [wumpus/5]).
%%   3. Place wumpus_cbr.pl next to hunter.pl,
%%      positive_examples_generated.pl, and negative_examples_generated.pl.
%%
%% ── HOW IT WORKS ─────────────────────────────────────────────────────────────
%%   For a query wumpus(HunterPos, Beliefs, Percepts, Cell, ?EV):
%%     1. All examples are loaded once at startup into cbr_example/6 facts.
%%     2. A similarity score (0-10) is computed between the query and each
%%        stored example using 4 weighted features.
%%     3. The K=7 nearest neighbours are selected.
%%     4. Votes are tallied per EV label:
%%          positive neighbour  -> +1 vote for its label
%%          negative neighbour  -> -1 vote for its label
%%     5. The EV with the highest net vote (if > 0) is returned.
%%        Falls back to `unknown` when all scores <= 0.
%%
%% ── SIMILARITY FEATURES ──────────────────────────────────────────────────────
%%   +4  cell_partition  : queried cell is in the same belief bucket
%%                         (knownTrue / knownFalse / orTrue / none)
%%   +3  stench_match    : both percept lists agree on presence of stench
%%   +2  adjacency_match : queried cell is adjacent to hunter in both cases
%%   +1  hunter_proximity: hunter positions are <= 1 step apart

:- module(wumpus_cbr, [wumpus/5]).

:- use_module(library(lists)).
:- use_module(library(aggregate)).

%% ── K parameter ──────────────────────────────────────────────────────────────

k_neighbours(7).

%% ── Example storage ──────────────────────────────────────────────────────────

:- dynamic cbr_example/6.
%% cbr_example(+Sign, +HunterPos, +Beliefs, +Percepts, +Cell, +EV)
%% Sign = pos | neg

:- dynamic cbr_loaded/0.

load_cbr_examples :-
    cbr_loaded, !.
load_cbr_examples :-
    load_examples_from_file('positive_examples_generated.pl', pos),
    load_examples_from_file('negative_examples_generated.pl', neg),
    assertz(cbr_loaded),
    aggregate_all(count, cbr_example(pos,_,_,_,_,_), NPos),
    aggregate_all(count, cbr_example(neg,_,_,_,_,_), NNeg),
    format(user_error,
        '[wumpus_cbr] Loaded ~w positive + ~w negative examples.~n',
        [NPos, NNeg]).

load_examples_from_file(File, Sign) :-
    setup_call_cleanup(
        open(File, read, Stream),
        read_and_store(Stream, Sign),
        close(Stream)
    ).

read_and_store(Stream, Sign) :-
    read_term(Stream, Term, []),
    ( Term == end_of_file
    -> true
    ;  ( Term = wumpus(HP, EW, P, C, EV)
       -> assertz(cbr_example(Sign, HP, EW, P, C, EV))
       ;  true
       ),
       read_and_store(Stream, Sign)
    ).

%% ── Main entry point ─────────────────────────────────────────────────────────

wumpus(HunterPos, Beliefs, Percepts, Cell, EV) :-
    load_cbr_examples,
    (nonvar(EV) -> 
        knn_classify(HunterPos, Beliefs, Percepts, Cell, BestEV), EV = BestEV
    ;   knn_classify(HunterPos, Beliefs, Percepts, Cell, EV)
    ).

%% ── KNN classification ───────────────────────────────────────────────────────

knn_classify(HunterPos, Beliefs, Percepts, Cell, BestEV) :-
    findall(Sim-Sign-ExEV,
        ( cbr_example(Sign, ExHP, ExBeliefs, ExPercepts, ExCell, ExEV),
          similarity(HunterPos, Beliefs, Percepts, Cell,
                     ExHP,      ExBeliefs, ExPercepts, ExCell,
                     Sim)
        ),
        AllScored),

    sort(1, @>=, AllScored, Sorted),
    k_neighbours(K),
    ( length(Sorted, Len), Len >= K
    -> length(Neighbours, K), append(Neighbours, _, Sorted)
    ;  Neighbours = Sorted
    ),

    ev_labels(Labels),
    maplist(net_vote(Neighbours), Labels, NetScores),
    pairs_keys_values(Pairs, NetScores, Labels),
    sort(1, @>=, Pairs, [BestScore-BestEV0|_]),

    ( BestScore > 0 -> BestEV = BestEV0 ; BestEV = unknown ),

    format(user_error,
        '[cbr] wumpus(~w,...,~w) => ~w  (best net=~w)~n',
        [HunterPos, Cell, BestEV, BestScore]).

ev_labels([knownTrue, knownFalse, orTrue, unknown]).

%% net_vote(+Neighbours, +Label, -Net)
net_vote(Neighbours, Label, Net) :-
    findall(W,
        ( member(_Sim-Sign-ExEV, Neighbours),
          ExEV = Label,
          ( Sign = pos -> W = 1 ; W = -1 )
        ),
        Ws),
    sumlist(Ws, Net).

%% ── Similarity ───────────────────────────────────────────────────────────────

similarity(HP,   Beliefs,   Percepts,   Cell,
           ExHP, ExBeliefs, ExPercepts, ExCell,
           Score) :-
    %% Feature 1 (+4): same belief partition for the tested cell
    cell_part_code(Cell,   Beliefs,   Code1),
    cell_part_code(ExCell, ExBeliefs, Code2),
    ( Code1 =:= Code2 -> S1 = 4 ; S1 = 0 ),

    %% Feature 2 (+3): stench agreement
    stench_flag(Percepts,   SF1),
    stench_flag(ExPercepts, SF2),
    ( SF1 =:= SF2 -> S2 = 3 ; S2 = 0 ),

    %% Feature 3 (+2): adjacency agreement
    adj_flag(HP,   Cell,   AdjQ),
    adj_flag(ExHP, ExCell, AdjEx),
    ( AdjQ =:= AdjEx -> S3 = 2 ; S3 = 0 ),

    %% Feature 4 (+1): hunter proximity
    hunter_dist(HP, ExHP, D),
    ( D =< 1 -> S4 = 1 ; S4 = 0 ),

    Score is S1 + S2 + S3 + S4.

%% Encode belief partition as integer: 0=none, 1=knownTrue, 2=knownFalse, 3=orTrue
cell_part_code(Cell, Beliefs, Code) :-
    ( beliefs_member(knownTrue,  Beliefs, Cell) -> Code = 1
    ; beliefs_member(knownFalse, Beliefs, Cell) -> Code = 2
    ; beliefs_member(orTrue,     Beliefs, Cell) -> Code = 3
    ; Code = 0
    ).

beliefs_member(EV, [eatwumpus(EV, L)|_], Cell) :- member(Cell, L), !.
beliefs_member(EV, [_|T], Cell) :- beliefs_member(EV, T, Cell).

stench_flag(Percepts, 1) :- member(stench, Percepts), !.
stench_flag(_, 0).

adj_flag(HP, Cell, 1) :- cbr_adj(HP, Cell), !.
adj_flag(_, _, 0).

cbr_adj(cell(X,Y), cell(X,Y1)) :- Y1 is Y+1.
cbr_adj(cell(X,Y), cell(X,Y1)) :- Y1 is Y-1.
cbr_adj(cell(X,Y), cell(X1,Y)) :- X1 is X+1.
cbr_adj(cell(X,Y), cell(X1,Y)) :- X1 is X-1.
cbr_adj(D, C) :- is_dict(D), !, cbr_adj(cell(D.x,D.y), C).
cbr_adj(C, D) :- is_dict(D), !, cbr_adj(C, cell(D.x,D.y)).

hunter_dist(cell(X1,Y1), cell(X2,Y2), D) :- !,
    D is abs(X1-X2) + abs(Y1-Y2).
hunter_dist(HP1, HP2, D) :-
    to_cell(HP1, C1), to_cell(HP2, C2),
    hunter_dist(C1, C2, D).

to_cell(cell(X,Y), cell(X,Y)) :- !.
to_cell(D, cell(X,Y)) :- is_dict(D), !, X = D.x, Y = D.y.

%% ── Utilities ────────────────────────────────────────────────────────────────

sumlist([], 0).
sumlist([H|T], S) :- sumlist(T, S0), S is S0 + H.
