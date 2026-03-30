:- module(theory_wumpus, [wumpus/5, adjacent_cell/2]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).

wumpus(_HunterPos, EatWumpus, _Percepts, CellToTest, knownTrue) :-
    in_known_true(CellToTest, EatWumpus).

wumpus(HunterPos, EatWumpus, Percepts, CellToTest, knownTrue) :-
    stench_in_percepts(Percepts),
    in_or_true(CellToTest, EatWumpus),
    or_true_list(EatWumpus, OrTrueList),
    OrTrueList = [CellToTest],
    adjacent_cell(HunterPos, CellToTest).

wumpus(_HunterPos, EatWumpus, _Percepts, CellToTest, knownFalse) :-
    in_known_false(CellToTest, EatWumpus).

wumpus(HunterPos, _EatWumpus, Percepts, CellToTest, knownFalse) :-
    no_stench_in_percepts(Percepts),
    adjacent_cell(HunterPos, CellToTest).

wumpus(_HunterPos, EatWumpus, _Percepts, CellToTest, orTrue) :-
    in_or_true(CellToTest, EatWumpus),
    \+ in_known_true(CellToTest, EatWumpus),
    \+ in_known_false(CellToTest, EatWumpus).

wumpus(_HunterPos, EatWumpus, _Percepts, CellToTest, unknown) :-
    \+ in_known_true(CellToTest, EatWumpus),
    \+ in_known_false(CellToTest, EatWumpus),
    \+ in_or_true(CellToTest, EatWumpus).

in_known_true(Cell, [eatwumpus(knownTrue, L)|_]) :- member(Cell, L), !.
in_known_true(Cell, [_|T]) :- in_known_true(Cell, T).

in_known_false(Cell, [eatwumpus(knownFalse, L)|_]) :- member(Cell, L), !.
in_known_false(Cell, [_|T]) :- in_known_false(Cell, T).

in_or_true(Cell, [eatwumpus(orTrue, L)|_]) :- member(Cell, L), !.
in_or_true(Cell, [_|T]) :- in_or_true(Cell, T).

or_true_list([eatwumpus(orTrue, L)|_], L) :- !.
or_true_list([_|T], L) :- or_true_list(T, L).

known_true_list([eatwumpus(knownTrue, L)|_], L) :- !.
known_true_list([_|T], L) :- known_true_list(T, L).

known_false_list([eatwumpus(knownFalse, L)|_], L) :- !.
known_false_list([_|T], L) :- known_false_list(T, L).

stench_in_percepts(Percepts) :- member(stench, Percepts).

no_stench_in_percepts(Percepts) :- \+ member(stench, Percepts).

adjacent_cell(cell(X,Y), cell(X,Y1)) :- Y1 #= Y + 1.
adjacent_cell(cell(X,Y), cell(X,Y1)) :- Y1 #= Y - 1.
adjacent_cell(cell(X,Y), cell(X1,Y)) :- X1 #= X + 1.
adjacent_cell(cell(X,Y), cell(X1,Y)) :- X1 #= X - 1.
