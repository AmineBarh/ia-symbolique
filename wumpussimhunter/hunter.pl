%%% ==========================================================================
%%% hunter.pl  –  ILP-Powered Wumpus Hunter Agent
%%% IAS 4A – ESIEA  |  TP2 + HW2
%%%
%%% Strict Coding Rules adhered to:
%%%   - clpfd, pairs, lists, dicts, reif used.
%%%   - NO assert/retract.
%%%   - NO is/2 (used #=).
%%%   - NO (->)/2 (used if_/3).
%%%   - NO \=/2 (used dif/2).
%%% ==========================================================================

:- module(hunter, [
    select_action/3
]).

:- discontiguous turn_left/2, turn_right/2.

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(pairs)).
:- use_module(reif).
:- use_module(theory_wumpus).

% ── Additional Reified Meta-Helpers (not in reif.pl) ────────────────
non_member_t(X, Ls, T) :- if_(member_t(X, Ls), T = false, T = true).

%%% ──────────────────────────────────────────────────────────────────────────
%%% TOP-LEVEL ENTRY POINT
%%% ──────────────────────────────────────────────────────────────────────────

select_action(HunterState, Action, NewHunterState) :-
    Beliefs   = HunterState.beliefs,
    Percepts  = HunterState.percepts,
    _Cells    = Beliefs.certain_eternals.cells,
    Walls     = Beliefs.certain_eternals.eat_walls,
    HunterPos = Beliefs.certain_fluents.fat_hunter.c,
    Step      = Beliefs.step,
    DirList    = Beliefs.certain_fluents.dir,
    DirList    = [DirEntry|_],
    CurrentDir = DirEntry.d,
    dict_to_cell_safe(HunterPos, HPTerm),
    
    %% 1. Update Wumpus beliefs
    EWBeliefsJSON = Beliefs.uncertain_eternals.eat_wumpus,
    json_to_beliefs(eatwumpus, EWBeliefsJSON, EWBeliefs0),
    reconcile_shot_result(HPTerm, CurrentDir, EWBeliefs0, Percepts, EWBeliefs),
    update_wumpus_beliefs(HunterPos, EWBeliefs, Percepts, Walls, NewEWBeliefs),
    
    %% 2. Update Pit beliefs
    EPBeliefsJSON = Beliefs.uncertain_eternals.eat_pit,
    json_to_beliefs(eatpit, EPBeliefsJSON, EPBeliefs),
    update_pit_beliefs(HunterPos, EPBeliefs, Percepts, Walls, NewEPBeliefs),
    
    %% 3. JSON conversions
    beliefs_to_json(eatwumpus, NewEWBeliefs, NewEWBeliefsJSON),
    beliefs_to_json(eatpit,    NewEPBeliefs, NewEPBeliefsJSON),
    
    %% 4. Track historical hazards (stench/breeze) specifically to manage plan invalidations and risk counts
    get_or_default(Beliefs.certain_fluents, observed_breezes, RawBreezes),
    maplist(dict_to_cell_safe, RawBreezes, OldBreezes),
    if_(member_t(breeze, Percepts), ensure_member(HPTerm, OldBreezes, NewBreezes), NewBreezes = OldBreezes),
    
    get_or_default(Beliefs.certain_fluents, observed_stenches, RawStenches),
    maplist(dict_to_cell_safe, RawStenches, OldStenches),
    if_(member_t(stench, Percepts), ensure_member(HPTerm, OldStenches, NewStenches), NewStenches = OldStenches),
    
    get_or_default(Beliefs.certain_fluents, intention_plan, InitialPlan),
    
    %% 3. Plan Validation: Reset if new critical percepts appear
    if_(or_t(member_t(bump, Percepts),
             or_t(and_t(member_t(breeze, Percepts), non_member_t(HPTerm, OldBreezes)),
                  and_t(member_t(stench, Percepts), non_member_t(HPTerm, OldStenches)))),
        ValidPlan = [],
        ValidPlan = InitialPlan),
    
    %% Build updated beliefs dict
    NewStep #= Step + 1,
    NewUE = Beliefs.uncertain_eternals
        .put(eat_wumpus, NewEWBeliefsJSON)
        .put(eat_pit,    NewEPBeliefsJSON),
    maplist(cell_to_json, NewBreezes, FinalBreezes),
    maplist(cell_to_json, NewStenches, FinalStenches),
    TempCF1 = Beliefs.certain_fluents.put(intention_plan, ValidPlan),
    TempCF2 = TempCF1.put(observed_breezes, FinalBreezes).put(observed_stenches, FinalStenches),
    NewBeliefs = Beliefs
        .put(step, NewStep)
        .put(uncertain_eternals, NewUE)
        .put(certain_fluents, TempCF2),

    %% 5. Decide action rhythm: Even steps = Think/Ingest, Odd steps = Act
    Rem #= Step mod 2,
    if_( =(Rem, 0),
         (Action = none, FinalBeliefs = NewBeliefs),
         (
             if_( =(ValidPlan, []),
                  (
                      deliberate(NewBeliefs, Percepts, DeliberatedPlan),
                      if_( =(DeliberatedPlan, []),
                           (Action = none, FinalBeliefs = NewBeliefs),
                           ( DeliberatedPlan = [Action|Rest],
                             FinalCF = NewBeliefs.certain_fluents.put(intention_plan, Rest),
                             FinalBeliefs = NewBeliefs.put(certain_fluents, FinalCF)
                           )
                      )
                  ),
                  (
                      ValidPlan = [Action|Rest],
                      FinalCF = NewBeliefs.certain_fluents.put(intention_plan, Rest),
                      FinalBeliefs = NewBeliefs.put(certain_fluents, FinalCF)
                  )
             )
         )
    ),
    
    %% 6. Move Decision Logging
    DirList = Beliefs.certain_fluents.dir, 
    if_(DirList = [D|_], CurrentDir = D.d, CurrentDir = north),
    maybe_log_move(Action, HunterPos, CurrentDir, FinalBeliefs),
    
    %% 7. Bundle updated state
    FinalDict = FinalBeliefs,
    NewHunterState = HunterState
        .put(beliefs, FinalDict).

%%% ──────────────────────────────────────────────────────────────────────────
%%% HELPERS FOR REIFIED DICT ACCESS
%%% ──────────────────────────────────────────────────────────────────────────

get_or_default(CF, Key, Val) :-
    dict_pairs(CF, _, Pairs),
    if_(member_pair_t(Key, Pairs, P), Val = P, Val = []).

member_pair_t(_Key, [], _, false).
member_pair_t(Key, [K-V|Rest], Val, Truth) :-
    if_( =(Key, K),
         (Val = V, Truth = true),
         member_pair_t(Key, Rest, Val, Truth)
    ).

ensure_member(X, L, Res) :-
    if_(member_t(X, L), Res = L, Res = [X|L]).

%%% ──────────────────────────────────────────────────────────────────────────
%%% JSON SERIALIZATION HELPERS
%%% ──────────────────────────────────────────────────────────────────────────

beliefs_to_json(_, [], []).
beliefs_to_json(Tag, [Term|Rest], [Dict|RestJSON]) :-
    Term =.. [Tag, EV, CellList],
    maplist(cell_to_json, CellList, CellDicts),
    dict_create(Dict, '', [epistemicValue=EV, belief=CellDicts]),
    beliefs_to_json(Tag, Rest, RestJSON).
beliefs_to_json(Tag, [Other|Rest], [Other|RestJSON]) :-
    beliefs_to_json(Tag, Rest, RestJSON).

cell_to_json(cell(X,Y), Dict) :- dict_create(Dict, '', [x=X, y=Y]).
cell_to_json(D, D) :- is_dict(D).
cell_to_json(X, X).

json_to_beliefs(_, [], []).
json_to_beliefs(Tag, [D|Rest], [Term|RestInternal]) :-
    is_dict(D),
    get_dict(epistemicValue, D, EV),
    get_dict(belief, D, RawCells),
    maplist(dict_to_cell_safe, RawCells, CellTerms),
    Term =.. [Tag, EV, CellTerms],
    json_to_beliefs(Tag, Rest, RestInternal).
json_to_beliefs(Tag, [_|Rest], RestInternal) :-
    json_to_beliefs(Tag, Rest, RestInternal).

%%% ──────────────────────────────────────────────────────────────────────────
%%% BELIEF UPDATE  (using the ILP-learned wumpus/5 theory)
%%% ──────────────────────────────────────────────────────────────────────────

update_wumpus_beliefs(HunterPos, OldEWBeliefs, Percepts, Walls, NewEWBeliefs) :-
    dict_to_cell_safe(HunterPos, HPTerm),
    
    get_belief_cells(knownTrue, OldEWBeliefs, OldKT),
    get_belief_cells(knownFalse, OldEWBeliefs, OldKF),
    get_belief_cells(orTrue, OldEWBeliefs, OldOT),
    format(user_error, '[debug] Wumpus Update Pre: KT=~w, KF=~w, OT=~w~n', [OldKT, OldKF, OldOT]),
    
    findall(C, 
        (adjacent_cell(HPTerm, C),
         \+ is_wall(C, Walls),
         not_member(C, OldKT),
         not_member(C, OldKF)),
        UnclassifiedAdj),
    
    process_wumpus_adj(UnclassifiedAdj, HPTerm, OldEWBeliefs, Percepts, OldKT, OldKF, OldOT, FinalKT, FinalKF, FinalOT),
    format(user_error, '[debug] Wumpus Update Post: KT=~w, KF=~w, OT=~w~n', [FinalKT, FinalKF, FinalOT]),
    
    NewEWBeliefs = [
        eatwumpus(knownTrue,  FinalKT),
        eatwumpus(knownFalse, FinalKF),
        eatwumpus(orTrue,     FinalOT)
    ].

process_wumpus_adj([], _HP, _OldBeliefs, _Percepts, KT, KF, OT, KT, KF, OT).
process_wumpus_adj([C|Cs], HP, OldBeliefs, Percepts, KT_in, KF_in, OT_in, KT_out, KF_out, OT_out) :-
    findall(V, wumpus(HP, OldBeliefs, Percepts, C, V), Vals),
    assign_epistemic(Vals, EpistemicVal),
    update_partitions(EpistemicVal, C, KT_in, KF_in, OT_in, KT_next, KF_next, OT_next),
    process_wumpus_adj(Cs, HP, OldBeliefs, Percepts, KT_next, KF_next, OT_next, KT_out, KF_out, OT_out).

assign_epistemic([V|_], V) :- !.  
assign_epistemic([], unknown).


%% update_partitions(+EpistemicVal, +Cell, +KT_in, +KF_in, +OT_in, -KT_out, -KF_out, -OT_out)
%% Hardened version with partition safety guards.
update_partitions(unknown, _, KT_in, KF_in, OT_in, KT_in, KF_in, OT_in).
update_partitions(knownTrue, C, KT_in, KF_in, OT_in, KT_out, KF_out, OT_out) :-
    if_(member_t(C, KF_in),
        throw(error(domain_error(hazard_partition, C), context(update_partitions, 'Cell in knownFalse reclassified as knownTrue!'))),
        (add_if_new(C, KT_in, KT_out), KF_out = KF_in, remove_if_present(C, OT_in, OT_out))).
update_partitions(knownFalse, C, KT_in, KF_in, OT_in, KT_out, KF_out, OT_out) :-
    if_(member_t(C, KT_in),
        throw(error(domain_error(hazard_partition, C), context(update_partitions, 'Cell in knownTrue reclassified as knownFalse!'))),
        (KT_out = KT_in, add_if_new(C, KF_in, KF_out), remove_if_present(C, OT_in, OT_out))).
update_partitions(orTrue, C, KT_in, KF_in, OT_in, KT_out, KF_out, OT_out) :-
    if_(or_t(member_t(C, KT_in), member_t(C, KF_in)),
        (KT_out = KT_in, KF_out = KF_in, OT_out = OT_in), %% Skip re-OR-ing confirmed cells
        (KT_out = KT_in, KF_out = KF_in, add_if_new(C, OT_in, OT_out))).

add_if_new(X, List, Res) :- if_(member_t(X, List), Res = List, Res = [X|List]).

remove_if_present(X, List, Res) :- filter_out(List, X, Res).

filter_out([], _, []).
filter_out([H|T], X, Res) :-
    if_( =(X, H),
         filter_out(T, X, Res),
         (Res = [H|Tail], filter_out(T, X, Tail))).

not_member(_, []).
not_member(X, [Y|Ys]) :- dif(X, Y), not_member(X, Ys).

%%% ──────────────────────────────────────────────────────────────────────────
%%% PIT BELIEF UPDATE (Deductive)
%%% ──────────────────────────────────────────────────────────────────────────

update_pit_beliefs(HunterPos, OldEPBeliefs, Percepts, Walls, NewEPBeliefs) :-
    dict_to_cell_safe(HunterPos, HPTerm),
    get_belief_cells(knownTrue, OldEPBeliefs, OldKT),
    get_belief_cells(knownFalse, OldEPBeliefs, OldKF),
    get_belief_cells(orTrue, OldEPBeliefs, OldOT),
    format(user_error, '[debug] Pit Update Pre: KT=~w, KF=~w, OT=~w~n', [OldKT, OldKF, OldOT]),
    
    if_(member_t(breeze, Percepts),
        (
            findall(C,
                (adjacent_cell(HPTerm, C), \+ is_wall(C, Walls), not_member(C, OldKF), not_member(C, OldKT)),
                NewSuspects),
            append(OldOT, NewSuspects, TempOT),
            sort(TempOT, FinalOT),
            FinalKT = OldKT,
            FinalKF = OldKF
        ),
        (
            findall(C, (adjacent_cell(HPTerm, C), \+ is_wall(C, Walls)), SafeNeighbors),
            append(OldKF, SafeNeighbors, TempKF),
            sort(TempKF, FinalKF),
            subtract(OldOT, SafeNeighbors, FinalOT),
            subtract(OldKT, SafeNeighbors, ActualFinalKT), %% Safety override
            FinalKT = ActualFinalKT
        )
    ),
    format(user_error, '[debug] Pit Update Post: KT=~w, KF=~w, OT=~w~n', [FinalKT, FinalKF, FinalOT]),
    NewEPBeliefs = [eatpit(knownTrue, FinalKT), eatpit(knownFalse, FinalKF), eatpit(orTrue, FinalOT)].

%%% ──────────────────────────────────────────────────────────────────────────
%%% DELIBERATION ENGINE
%%% ──────────────────────────────────────────────────────────────────────────

deliberate(_Beliefs, Percepts, [grab]) :- member(glitter, Percepts), !.

deliberate(Beliefs, _Percepts, [climb]) :-
    ExitPos  = Beliefs.certain_eternals.eat_exit.c,
    HunterC  = Beliefs.certain_fluents.fat_hunter.c,
    ExitPos.x #= HunterC.x, ExitPos.y #= HunterC.y,
    dif(Beliefs.certain_fluents.has_gold, []), !.

deliberate(Beliefs, _Percepts, ActionSequence) :-
    dif(Beliefs.certain_fluents.has_gold, []),
    HunterPos = Beliefs.certain_fluents.fat_hunter.c,
    ExitPos   = Beliefs.certain_eternals.eat_exit.c,
    DirList   = Beliefs.certain_fluents.dir,
    DirList   = [DirEntry|_],
    CurrentDir = DirEntry.d,
    EWBeliefs = Beliefs.uncertain_eternals.eat_wumpus,
    EPBeliefs = Beliefs.uncertain_eternals.eat_pit,
    Walls     = Beliefs.certain_eternals.eat_walls,
    Visited   = Beliefs.certain_fluents.visited,
    dict_to_cell_safe(HunterPos, HPTerm),
    dict_to_cell_safe(ExitPos, ExitCell),
    if_(astar(HPTerm, CurrentDir, [ExitCell], EWBeliefs, EPBeliefs, Walls, Visited, Plan),
        ActionSequence = Plan,
        (navigate_towards(HunterPos, CurrentDir, ExitPos, Action), ActionSequence = [Action])),
    !.

deliberate(Beliefs, _Percepts, [shoot]) :- can_shoot(Beliefs), !.

deliberate(Beliefs, _Percepts, ActionSequence) :-
    choose_move_action(Beliefs, _, Plan),
    if_( =(Plan, []),
         ActionSequence = [left], %% Deadlock breaker: if no plan found, turn instead of looping none
         ActionSequence = Plan),
    !.

deliberate(Beliefs, _Percepts, [Action]) :-
    HunterPos = Beliefs.certain_fluents.fat_hunter.c,
    DirList   = Beliefs.certain_fluents.dir,
    DirList   = [DirEntry|_],
    CurrentDir = DirEntry.d,
    ExitPos   = Beliefs.certain_eternals.eat_exit.c,
    navigate_towards(HunterPos, CurrentDir, ExitPos, Action).

can_shoot(Beliefs) :-
    dif(Beliefs.certain_fluents.has_arrow, []),
    EWBeliefs = Beliefs.uncertain_eternals.eat_wumpus,
    known_true_list_from_beliefs(eatwumpus, EWBeliefs, KTList),
    dif(KTList, []),
    DirList = Beliefs.certain_fluents.dir,
    DirList = [DirEntry|_],
    CurrentDir = DirEntry.d,
    HunterPos = Beliefs.certain_fluents.fat_hunter.c,
    member(cell(WX, WY), KTList),
    wumpus_in_direction(HunterPos, CurrentDir, cell(WX, WY)).

wumpus_in_direction(HPos, north, cell(WX,WY)) :- HPos.x #= WX, WY #> HPos.y.
wumpus_in_direction(HPos, south, cell(WX,WY)) :- HPos.x #= WX, WY #< HPos.y.
wumpus_in_direction(HPos, east,  cell(WX,WY)) :- HPos.y #= WY, WX #> HPos.x.
wumpus_in_direction(HPos, west,  cell(WX,WY)) :- HPos.y #= WY, WX #< HPos.x.

known_true_list_from_beliefs(Tag, Beliefs, Cells) :-
    filter_beliefs_by_tag_ev(Beliefs, Tag, knownTrue, Nested),
    append(Nested, Flat),
    sort(Flat, Cells).

reconcile_shot_result(HunterPos, CurrentDir, EWBeliefs, Percepts, ResolvedEWBeliefs) :-
    if_(member_t(scream, Percepts),
        resolve_scream_wumpus_beliefs(HunterPos, CurrentDir, EWBeliefs, ResolvedEWBeliefs),
        ResolvedEWBeliefs = EWBeliefs).

resolve_scream_wumpus_beliefs(HunterPos, CurrentDir, OldEWBeliefs, NewEWBeliefs) :-
    get_belief_cells(knownTrue, OldEWBeliefs, OldKT),
    get_belief_cells(knownFalse, OldEWBeliefs, OldKF),
    get_belief_cells(orTrue, OldEWBeliefs, OldOT),
    findall(C,
        (member(C, OldKT), cell_in_line_of_fire(HunterPos, CurrentDir, C)),
        ShotCells),
    if_( =(ShotCells, []),
         (NewKT = OldKT, NewKF = OldKF, NewOT = OldOT),
         (
             subtract(OldKT, ShotCells, NewKT),
             subtract(OldOT, ShotCells, TrimmedOT),
             append(OldKF, ShotCells, TempKF),
             sort(TempKF, NewKF),
             NewOT = TrimmedOT
         )
    ),
    NewEWBeliefs = [
        eatwumpus(knownTrue, NewKT),
        eatwumpus(knownFalse, NewKF),
        eatwumpus(orTrue, NewOT)
    ].

cell_in_line_of_fire(cell(HX, HY), north, cell(X, Y)) :- X #= HX, Y #> HY.
cell_in_line_of_fire(cell(HX, HY), south, cell(X, Y)) :- X #= HX, Y #< HY.
cell_in_line_of_fire(cell(HX, HY), east, cell(X, Y)) :- Y #= HY, X #> HX.
cell_in_line_of_fire(cell(HX, HY), west, cell(X, Y)) :- Y #= HY, X #< HX.

filter_beliefs_by_tag_ev([], _, _, []).
filter_beliefs_by_tag_ev([B|Rest], Tag, EV, Cells) :-
    belief_tag_ev_t(B, Tag, EV, T),
    if_( =(T, true),
         (grab_cells(B, Cs), Cells = [Cs|Tail]),
         (Cells = Tail)),
    filter_beliefs_by_tag_ev(Rest, Tag, EV, Tail).

belief_tag_ev_t(B, _Tag, EV, true) :- is_dict(B), get_dict(epistemicValue, B, EV), !.
belief_tag_ev_t(B, Tag, EV, true) :- \+ is_dict(B), B =.. [Tag, EV, _], !.
belief_tag_ev_t(_, _, _, false).

%%% ──────────────────────────────────────────────────────────────────────────
%%% MOVE SELECTION with A*, Risk, Frontier
%%% ──────────────────────────────────────────────────────────────────────────

choose_move_action(Beliefs, _Percepts, ActionSequence) :-
    HunterPos = Beliefs.certain_fluents.fat_hunter.c,
    Cells     = Beliefs.certain_eternals.cells,
    Walls     = Beliefs.certain_eternals.eat_walls,
    DirList   = Beliefs.certain_fluents.dir,
    DirList   = [DirEntry|_], CurrentDir = DirEntry.d,
    Visited   = Beliefs.certain_fluents.visited,
    EWBeliefs = Beliefs.uncertain_eternals.eat_wumpus,
    EPBeliefs = Beliefs.uncertain_eternals.eat_pit,
    ExitPos   = Beliefs.certain_eternals.eat_exit.c,
    dict_to_cell_safe(HunterPos, HPTerm),
    dict_to_cell_safe(ExitPos, ExitCell),
    get_or_default(Beliefs.certain_fluents, observed_breezes, ObservedBreezes),
    
    %% 1. Identify all safe unvisited cells (avoid retargeting the exit while exploring)
    findall(CTerm,
        (member(C, Cells),
         dict_to_cell_safe(C, CTerm),
         dif(CTerm, HPTerm),
         dif(CTerm, ExitCell),
         cell_is_safe(CTerm, EWBeliefs, EPBeliefs, Visited),
         \+ is_wall(CTerm, Walls),
         not_was_visited(CTerm, Visited)),
        SafeUnvisited),
        
    %% 2. Identify which ones are safely reachable, preferring the shortest plan
    findall(Len-Plan-C,
        (member(C, SafeUnvisited),
         astar(HPTerm, CurrentDir, [C], EWBeliefs, EPBeliefs, Walls, Visited, Plan),
         length(Plan, Len)),
        ReachablePlans),
    
    if_( =(ReachablePlans, []),
         %% PROBABILISTIC RISK MANAGEMENT (No safe path to any unvisited safe cell)
         (
             get_belief_cells(orTrue, EPBeliefs, OTCells),
             get_belief_cells(orTrue, EWBeliefs, OTWCells),
             append(OTCells, OTWCells, AllOTUnsorted), sort(AllOTUnsorted, AllOTAll),
             get_belief_cells(knownTrue, EPBeliefs, KTP),
             get_belief_cells(knownTrue, EWBeliefs, KTW),
             append(KTP, KTW, Hazards),
             subtract(AllOTAll, Hazards, RawCleanOT),
             findall(C,
                 (member(C, RawCleanOT), dif(C, HPTerm), dif(C, ExitCell), \+ is_wall(C, Walls)),
                 CleanOT),

             if_( =(CleanOT, []),
                  %% No safe and no orTrue -> Return home
                  (
                      ExitPos = Beliefs.certain_eternals.eat_exit.c,
                      dict_to_cell_safe(ExitPos, ExitCell),
                      astar(HPTerm, CurrentDir, [ExitCell], EWBeliefs, EPBeliefs, Walls, Visited, ActionSequence)
                  ),
                  %% Pick the lowest risk orTrue
                  (
                      evaluate_risks(CleanOT, ObservedBreezes, RiskPairs),
                      sort(1, @=<, RiskPairs, [_-BestRiskyCell|_]),
                      astar_with_fallback(HPTerm, CurrentDir, [BestRiskyCell], EWBeliefs, EPBeliefs, Walls, Visited, ActionSequence)
                  )
             )
         ),
         %% REACHABLE SAFE FRONTIER
         (
             %% Pick the shortest reachable plan instead of the lexicographically first action list
             sort(1, @=<, ReachablePlans, [_-ActionSequence-_|_])
         )
    ).

%% Risk Evaluation: Risk score = adjacent breezes / adjacent cells
evaluate_risks([], _, []).
evaluate_risks([C|Cs], ObBreezes, [Risk-C|Rest]) :-
    findall(Adj, adjacent_cell(C, Adj), Adjs),
    length(Adjs, NumAdj),
    findall(BAdj, (adjacent_cell(C, BAdj), member(BAdj, ObBreezes)), BAdjs),
    length(BAdjs, NumB),
    if_( =(NumAdj, 0), Risk #= 1000, Risk #= (NumB * 100) div NumAdj),
    evaluate_risks(Cs, ObBreezes, Rest).

astar_with_fallback(HP, Dir, Targets, EW, EP, Walls, Visited, ActionSequence) :-
    if_(astar(HP, Dir, Targets, EW, EP, Walls, Visited, FoundPlan),
        ActionSequence = FoundPlan,
        (
            Targets = [Target|_],
            navigate_towards(HP, Dir, Target, SimpleAction),
            if_(and_t(=(SimpleAction, move), 
                      and_t(next_cell_in_dir_t(HP, Dir, Next), 
                            or_t(is_wall_t(Next, Walls),
                                 not_t(cell_is_safe_t(Next, EW, EP, Visited))))),
                ActionSequence = [none],
                ActionSequence = [SimpleAction])
        )
    ).

next_cell_in_dir_t(Cell, Dir, Next, true) :- next_cell_in_dir(Cell, Dir, Next), !.
next_cell_in_dir_t(_, _, _, false).

is_wall_t(Cell, Walls, true) :- is_wall(Cell, Walls), !.
is_wall_t(_, _, false).

%% Reified astar/9 wrapper for use with reif:if_/3
astar(HP, Dir, Targets, EW, EP, Walls, Visited, Actions, Truth) :-
    findall(A, astar(HP, Dir, Targets, EW, EP, Walls, Visited, A), Plans),
    if_( =(Plans, []),
         Truth = false,
         (Plans = [Actions|_], Truth = true)
    ).

%% Strengthened safety filter: Target must be in knownFalse for exploration or already visited.
cell_is_safe(Cell, EWBeliefs, EPBeliefs, Visited) :-
    cell_is_safe_t(Cell, EWBeliefs, EPBeliefs, Visited, true).

cell_is_safe_t(Cell, EWBeliefs, EPBeliefs, Visited, Truth) :-
    dict_to_cell_safe(Cell, CTerm),
    if_(was_visited_t(CTerm, Visited),
        Truth = true,
        (
            get_belief_cells(knownTrue, EWBeliefs, KTEW),
            get_belief_cells(knownTrue, EPBeliefs, KTEP),
            if_(non_member_t(CTerm, KTEW),
                if_(non_member_t(CTerm, KTEP),
                    Truth = true,
                    Truth = false),
                Truth = false)
        )
    ).

%%% ──────────────────────────────────────────────────────────────────────────
%%% A* PATHFINDING
%%% ──────────────────────────────────────────────────────────────────────────
%% Treats each state as (Cell, Direction)
astar(StartCell, StartDir, Targets, EW, EP, Walls, Visited, Actions) :-
    heuristic(StartCell, Targets, H),
    PQ = [f(H)-0-(StartCell, StartDir)-[]],
    astar_search(PQ, Targets, EW, EP, Walls, Visited, [], RevActions),
    reverse(RevActions, Actions),
    dif(Actions, []).

astar_search([f(_)-_Cost-(Cell, _Dir)-Path|_], Targets, _, _, _, _, _, Path) :-
    member(Cell, Targets), !.
astar_search([f(_)-Cost-(Cell, Dir)-Path|RestPQ], Targets, EW, EP, Walls, Visited, Explored, FinalPath) :-
    if_(member_t((Cell,Dir), Explored),
        astar_search(RestPQ, Targets, EW, EP, Walls, Visited, Explored, FinalPath),
        (
             findall(NextState,
                 generate_next_state(Cell, Dir, Cost, Path, Targets, EW, EP, Walls, Visited, NextState),
                 NextStates),
             append(RestPQ, NextStates, UnsortedPQ),
             sort(1, @=<, UnsortedPQ, NextPQ),
             astar_search(NextPQ, Targets, EW, EP, Walls, Visited, [(Cell,Dir)|Explored], FinalPath)
        )
    ).

generate_next_state(Cell, Dir, Cost, Path, Targets, _, _, _, _, f(F)-NewCost-(Cell, NextDir)-[Action|Path]) :-
    turn_left(Dir, NextDir), Action = left, NewCost #= Cost + 1, heuristic(Cell, Targets, H), F #= NewCost + H.
generate_next_state(Cell, Dir, Cost, Path, Targets, _, _, _, _, f(F)-NewCost-(Cell, NextDir)-[Action|Path]) :-
    turn_right(Dir, NextDir), Action = right, NewCost #= Cost + 1, heuristic(Cell, Targets, H), F #= NewCost + H.
generate_next_state(Cell, Dir, Cost, Path, Targets, EW, EP, Walls, Visited, f(F)-NewCost-(NextCell, Dir)-[move|Path]) :-
    next_cell_in_dir(Cell, Dir, NextCell),
    \+ is_wall(NextCell, Walls),
    cell_is_safe(NextCell, EW, EP, Visited),
    NewCost #= Cost + 1, heuristic(NextCell, Targets, H), F #= NewCost + H.

next_cell_in_dir(cell(X,Y), north, cell(X,Y1)) :- Y1 #= Y + 1.
next_cell_in_dir(cell(X,Y), south, cell(X,Y1)) :- Y1 #= Y - 1.
next_cell_in_dir(cell(X,Y), east, cell(X1,Y)) :- X1 #= X + 1.
next_cell_in_dir(cell(X,Y), west, cell(X1,Y)) :- X1 #= X - 1.

heuristic(cell(X,Y), [cell(TX,TY)|_], H) :- H #= abs(X - TX) + abs(Y - TY).

%%% ──────────────────────────────────────────────────────────────────────────
%%% FRONTIER TARGETING
%%% ──────────────────────────────────────────────────────────────────────────
frontier_target(HX, SafeUnvisited, _Visited, Walls, Target) :-
    %% Group unvisited safe cells into connected clusters
    find_clusters(SafeUnvisited, Walls, Clusters),
    %% Target edge of largest
    if_( =(Clusters, []),
         find_nearest(HX, SafeUnvisited, Target),   %% Fallback
         (
             sort_clusters_desc(Clusters, [LargestCluster|_]),
             find_nearest(HX, LargestCluster, Target)
         )
    ).

%% BFS cluster builder
find_clusters([], _, []).
find_clusters([C|Cs], Walls, [Cluster|RestClusters]) :-
    build_cluster([C], Cs, Walls, Cluster, Remaining),
    find_clusters(Remaining, Walls, RestClusters).

build_cluster([], Remaining, _, [], Remaining).
build_cluster([C|Frontier], Remaining, Walls, [C|Cluster], FinalRemaining) :-
    findall(Adj, (adjacent_cell(C, Adj), member(Adj, Remaining), not_member(Adj, Walls)), Adjs),
    subtract(Remaining, Adjs, NextRemaining),
    append(Frontier, Adjs, NextFrontier),
    build_cluster(NextFrontier, NextRemaining, Walls, Cluster, FinalRemaining).

sort_clusters_desc(Clusters, Sorted) :-
    maplist(cluster_length_pair, Clusters, Pairs),
    sort(1, @>=, Pairs, SortedPairs),
    pairs_values(SortedPairs, Sorted).

cluster_length_pair(Cluster, L-Cluster) :- length(Cluster, L).

%%% ──────────────────────────────────────────────────────────────────────────
%%% HELPER METHODS
%%% ──────────────────────────────────────────────────────────────────────────

%%% ==========================================================================
%%% PERSISTENT BELIEF ACCESS (Fix for HW2 Belief Loss)
%%% ==========================================================================

%% get_belief_cells(+EV, +Beliefs, -AllCells)
%% Collects ALL cells across ALL belief blocks matching the EpistemicValue.
get_belief_cells(EV, Beliefs, AllCells) :-
    filter_beliefs_by_ev(Beliefs, EV, Nested),
    append(Nested, Flat),
    sort(Flat, AllCells).

%% filter_beliefs_by_ev(+List, +EV, -CellsList)
filter_beliefs_by_ev([], _, []).
filter_beliefs_by_ev([B|Rest], EV, Cells) :-
    belief_ev_t(B, EV, T),
    if_( =(T, true),
         (grab_cells(B, Cs), Cells = [Cs|Tail]),
         (Cells = Tail)),
    filter_beliefs_by_ev(Rest, EV, Tail).

belief_ev_t(B, EV, true) :- is_dict(B), get_dict(epistemicValue, B, EV), !.
belief_ev_t(B, EV, true) :- \+ is_dict(B), B =.. [_, EV, _], !.
belief_ev_t(_, _, false).

grab_cells(B, Cs) :-
    is_dict_t(B, T),
    if_( =(T, true),
         (get_dict(belief, B, L)),
         (B =.. [_, _, L])),
    maplist(dict_to_cell_safe, L, Cs).

is_dict_t(X, true) :- is_dict(X), !.
is_dict_t(_, false).

was_visited_t(Cell, Visited, Truth) :-
    dict_to_cell_safe(Cell, C),
    findall(_V, (member(Vd, Visited), dict_to_cell_safe(Vd.to, C)), L),
    if_( =(L, []), Truth=false, Truth=true).

was_visited(Cell, Visited) :-
    was_visited_t(Cell, Visited, true).

not_was_visited(Cell, Visited) :-
    was_visited_t(Cell, Visited, false).

find_nearest(cell(HX, HY), [First|Rest], Nearest) :-
    cell_dist(First, HX, HY, D0),
    find_nearest_acc(Rest, HX, HY, D0, First, Nearest).
find_nearest_acc([], _, _, _, Best, Best).
find_nearest_acc([C|Cs], HX, HY, BestD, BestC, Nearest) :-
    cell_dist(C, HX, HY, D),
    compare_dist(D, BestD, Cs, HX, HY, C, BestC, Nearest).

compare_dist(D, BestD, Cs, HX, HY, C, _BestC, Nearest) :-
    D #< BestD, find_nearest_acc(Cs, HX, HY, D, C, Nearest).
compare_dist(D, BestD, Cs, HX, HY, _C, BestC, Nearest) :-
    D #>= BestD, find_nearest_acc(Cs, HX, HY, BestD, BestC, Nearest).

cell_dist(C, HX, HY, D) :-
    dict_to_cell_safe(C, cell(X,Y)), D #= abs(X - HX) + abs(Y - HY).

navigate_towards(HPos, Dir, Target, Action) :-
    desired_direction(HPos, Target, DesiredDir),
    choose_turn_or_move(Dir, DesiredDir, Action).

desired_direction(From, To, north) :- dict_to_cell_safe(From, cell(_,FY)), dict_to_cell_safe(To, cell(_,TY)), TY #> FY, !.
desired_direction(From, To, south) :- dict_to_cell_safe(From, cell(_,FY)), dict_to_cell_safe(To, cell(_,TY)), TY #< FY, !.
desired_direction(From, To, east) :- dict_to_cell_safe(From, cell(FX,_)), dict_to_cell_safe(To, cell(TX,_)), TX #> FX, !.
desired_direction(From, To, west) :- dict_to_cell_safe(From, cell(FX,_)), dict_to_cell_safe(To, cell(TX,_)), TX #< FX, !.
desired_direction(_, _, north).

choose_turn_or_move(Dir, Dir, move) :- !.
choose_turn_or_move(Dir, Des, left) :- turn_left(Dir, Des), !.
choose_turn_or_move(Dir, Des, right) :- turn_right(Dir, Des), !.
choose_turn_or_move(_, _, right).

turn_left(north, west). turn_right(north, east).
turn_left(west, south). turn_right(east, south).
turn_left(south, east). turn_right(south, west).
turn_left(east, north). turn_right(west, north).

maybe_log_move(move, HPos, Dir, FinalBeliefs) :-
    next_cell_in_dir(HPos, Dir, Next),
    get_belief_cells(knownTrue, FinalBeliefs.uncertain_eternals.eat_wumpus, WKT),
    get_belief_cells(knownTrue, FinalBeliefs.uncertain_eternals.eat_pit, PKT),
    format(user_error, '[debug] DECIDE MOVE: From=~w To=~w PitKT=~w WKT=~w~n', [HPos, Next, PKT, WKT]).
maybe_log_move(_, _, _, _).

dict_to_cell_safe(D, cell(X,Y)) :- is_dict(D), !, X = D.x, Y = D.y.
dict_to_cell_safe(cell(X,Y), cell(X,Y)) :- !.
dict_to_cell_safe(C, C).

adjacent_cell(cell(X,Y), cell(X,Y1)) :- Y1 #= Y + 1.
adjacent_cell(cell(X,Y), cell(X,Y1)) :- Y1 #= Y - 1.
adjacent_cell(cell(X,Y), cell(X1,Y)) :- X1 #= X + 1.
adjacent_cell(cell(X,Y), cell(X1,Y)) :- X1 #= X - 1.
adjacent_cell(DictA, DictB) :-
    is_dict(DictA), is_dict(DictB), !,
    adjacent_cell(cell(DictA.x, DictA.y), cell(DictB.x, DictB.y)).
adjacent_cell(CellA, DictB) :- is_dict(DictB), !, adjacent_cell(CellA, cell(DictB.x, DictB.y)).

is_wall(Cell, Walls) :-
    dict_to_cell_safe(Cell, CTerm),
    member(W, Walls),
    extract_wall_term(W, CTerm).

extract_wall_term(W, CTerm) :-
    is_dict(W),
    dict_pairs(W, _, Pairs),
    if_(member_pair_t(c, Pairs, InnerC),
        dict_to_cell_safe(InnerC, CTerm),
        dict_to_cell_safe(W, CTerm)).
extract_wall_term(W, CTerm) :-
    \+ is_dict(W),
    dict_to_cell_safe(W, CTerm).
