%%% ==========================================================================
%%% background.pl  –  Aleph Background Knowledge for Wumpus Belief Update
%%% IAS 4A – ESIEA  |  HW2-ILP
%%%
%%% Purpose
%%% -------
%%%   Define the *mode declarations*, *determinations* and *helper predicates*
%%%   that Aleph uses as its background knowledge base when searching for a
%%%   hypothesis for the target predicate:
%%%
%%%     wumpus(+HunterPos, +EatWumpus, +Percepts, +CellToTest, #EpistemicValue)
%%%
%%%   where
%%%     HunterPos  = cell(X,Y)          – current hunter position
%%%     EatWumpus  = [eatwumpus(knownTrue,  List1),
%%%                   eatwumpus(knownFalse, List2),
%%%                   eatwumpus(orTrue,     List3)]
%%%     Percepts   = list of atoms among {stench, breeze, glitter, bump, scream}
%%%     CellToTest = cell(X,Y)
%%%     EpistemicValue = one of {knownTrue, knownFalse, orTrue, unknown}
%%%
%%% Libraries loaded (assumes SWI-Prolog + Aleph 5)
%%% The :- use_module calls are for standalone execution; when run inside
%%% Aleph they are simply ignored if the library is already loaded.
%%%
%%% IMPORTANT: Do NOT use imperative arithmetic, -> ; assert/retract.
%%%            Use CLP(FD) (#=, #>, etc.) and if_/3 from reif.
%%% ==========================================================================

:- use_module(library(clpfd)).
:- use_module(library(lists)).

%% --------------------------------------------------------------------------
%% 1. ALEPH SETTINGS
%% --------------------------------------------------------------------------

:- set(i, 4).          %% maximum clause length (# body literals)
:- set(minpos, 2).     %% minimum positive examples a clause must cover
:- set(noise, 2).      %% maximum negative examples a clause may cover
:- set(clauselength, 6).
:- set(search, bf).   %% breadth-first search (safe, complete for small h-space)
:- set(verbose, 1).

%% --------------------------------------------------------------------------
%% 2. MODE DECLARATIONS
%%    +  = input  (must be bound when called)
%%    -  = output (may be unbound, Aleph will instantiate)
%%    #  = constant (enumerated from background)
%% --------------------------------------------------------------------------

%% Target predicate head mode
:- modeh(1, wumpus(+cell, +eatwumpus_beliefs, +percepts_list, +cell, #epistemic)).

%% Body literals Aleph may use
:- modeb(1, hunter_position(+cell, -coord, -coord)).
:- modeb(1, cell_coords(+cell, -coord, -coord)).
:- modeb(1, adjacent_cell(+cell, +cell)).
:- modeb(*,  member_cell(+cell, +cell_list)).
:- modeb(1, in_known_true(+cell, +eatwumpus_beliefs)).
:- modeb(1, in_known_false(+cell, +eatwumpus_beliefs)).
:- modeb(1, in_or_true(+cell, +eatwumpus_beliefs)).
:- modeb(1, stench_in_percepts(+percepts_list)).
:- modeb(1, no_stench_in_percepts(+percepts_list)).
:- modeb(1, known_true_list(+eatwumpus_beliefs, -cell_list)).
:- modeb(1, known_false_list(+eatwumpus_beliefs, -cell_list)).
:- modeb(1, or_true_list(+eatwumpus_beliefs, -cell_list)).
:- modeb(1, same_cell(+cell, +cell)).

%% --------------------------------------------------------------------------
%% 3. DETERMINATION DECLARATIONS
%%    Tells Aleph which background predicates are relevant to the target
%% --------------------------------------------------------------------------

:- determination(wumpus/5, hunter_position/3).
:- determination(wumpus/5, cell_coords/3).
:- determination(wumpus/5, adjacent_cell/2).
:- determination(wumpus/5, member_cell/2).
:- determination(wumpus/5, in_known_true/2).
:- determination(wumpus/5, in_known_false/2).
:- determination(wumpus/5, in_or_true/2).
:- determination(wumpus/5, stench_in_percepts/1).
:- determination(wumpus/5, no_stench_in_percepts/1).
:- determination(wumpus/5, known_true_list/2).
:- determination(wumpus/5, known_false_list/2).
:- determination(wumpus/5, or_true_list/2).
:- determination(wumpus/5, same_cell/2).

%% --------------------------------------------------------------------------
%% 4. BACKGROUND PREDICATES  (the "oracle" the ILP engine may query)
%% --------------------------------------------------------------------------

%% -- 4.1  Cell & coordinate helpers ----------------------------------------

%% hunter_position(+HunterPos, -X, -Y)
%%   Extract the X,Y coordinates from a cell/2 term.
hunter_position(cell(X,Y), X, Y).

%% cell_coords(+Cell, -X, -Y)
cell_coords(cell(X,Y), X, Y).

%% same_cell(+A, +B)
%%   True when two cell/2 terms refer to the same grid square.
same_cell(cell(X,Y), cell(X,Y)).

%% adjacent_cell(+A, +B)
%%   True when cell B is a cardinal neighbour of cell A.
%%   Uses CLP(FD) to stay declarative.
adjacent_cell(cell(X,Y), cell(X,YN)) :-
    YN #= Y + 1.
adjacent_cell(cell(X,Y), cell(X,YN)) :-
    YN #= Y - 1.
adjacent_cell(cell(X,Y), cell(XN,Y)) :-
    XN #= X + 1.
adjacent_cell(cell(X,Y), cell(XN,Y)) :-
    XN #= X - 1.

%% -- 4.2  EatWumpus belief structure accessors  ----------------------------
%%
%%   The eatWumpus belief structure is encoded as:
%%     [eatwumpus(knownTrue, KTList),
%%      eatwumpus(knownFalse, KFList),
%%      eatwumpus(orTrue,     OTList)]
%%
%%   where each *List is a list of cell/2 terms.

%% known_true_list(+Beliefs, -List)
known_true_list([eatwumpus(knownTrue, L)|_], L).
known_true_list([_|T], L) :- known_true_list(T, L).

%% known_false_list(+Beliefs, -List)
known_false_list([eatwumpus(knownFalse, L)|_], L).
known_false_list([_|T], L) :- known_false_list(T, L).

%% or_true_list(+Beliefs, -List)
or_true_list([eatwumpus(orTrue, L)|_], L).
or_true_list([_|T], L) :- or_true_list(T, L).

%% member_cell(+Cell, +CellList)
%%   True when Cell is a member of CellList.
member_cell(C, [C|_]).
member_cell(C, [_|T]) :- member_cell(C, T).

%% -- 4.3  Direct epistemic value accessors ----------------------------------

%% in_known_true(+Cell, +Beliefs)
%%   True when Cell appears in the knownTrue list of the beliefs.
in_known_true(Cell, Beliefs) :-
    known_true_list(Beliefs, List),
    member_cell(Cell, List).

%% in_known_false(+Cell, +Beliefs)
in_known_false(Cell, Beliefs) :-
    known_false_list(Beliefs, List),
    member_cell(Cell, List).

%% in_or_true(+Cell, +Beliefs)
in_or_true(Cell, Beliefs) :-
    or_true_list(Beliefs, List),
    member_cell(Cell, List).

%% -- 4.4  Percept helpers --------------------------------------------------

%% stench_in_percepts(+Percepts)
%%   True when the stench percept is present.
stench_in_percepts(Percepts) :- member(stench, Percepts).

%% no_stench_in_percepts(+Percepts)
no_stench_in_percepts(Percepts) :- \+ member(stench, Percepts).

%% --------------------------------------------------------------------------
%% 5. EPISTEMIC VALUE CONSTANTS  (used in #EpistemicValue positions)
%% --------------------------------------------------------------------------

epistemic(knownTrue).
epistemic(knownFalse).
epistemic(orTrue).
epistemic(unknown).
