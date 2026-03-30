:- use_module(library(clpfd)).
:- use_module(library(lists)).

:- set(i, 4).
:- set(minpos, 2).
:- set(noise, 2).
:- set(clauselength, 6).
:- set(search, bf).
:- set(verbose, 1).

:- modeh(1, wumpus(+cell, +eatwumpus_beliefs, +percepts_list, +cell, #epistemic)).

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

hunter_position(cell(X,Y), X, Y).

cell_coords(cell(X,Y), X, Y).

same_cell(cell(X,Y), cell(X,Y)).

adjacent_cell(cell(X,Y), cell(X,YN)) :-
    YN #= Y + 1.
adjacent_cell(cell(X,Y), cell(X,YN)) :-
    YN #= Y - 1.
adjacent_cell(cell(X,Y), cell(XN,Y)) :-
    XN #= X + 1.
adjacent_cell(cell(X,Y), cell(XN,Y)) :-
    XN #= X - 1.

known_true_list([eatwumpus(knownTrue, L)|_], L).
known_true_list([_|T], L) :- known_true_list(T, L).

known_false_list([eatwumpus(knownFalse, L)|_], L).
known_false_list([_|T], L) :- known_false_list(T, L).

or_true_list([eatwumpus(orTrue, L)|_], L).
or_true_list([_|T], L) :- or_true_list(T, L).

member_cell(C, [C|_]).
member_cell(C, [_|T]) :- member_cell(C, T).

in_known_true(Cell, Beliefs) :-
    known_true_list(Beliefs, List),
    member_cell(Cell, List).

in_known_false(Cell, Beliefs) :-
    known_false_list(Beliefs, List),
    member_cell(Cell, List).

in_or_true(Cell, Beliefs) :-
    or_true_list(Beliefs, List),
    member_cell(Cell, List).

stench_in_percepts(Percepts) :- member(stench, Percepts).

no_stench_in_percepts(Percepts) :- \+ member(stench, Percepts).

epistemic(knownTrue).
epistemic(knownFalse).
epistemic(orTrue).
epistemic(unknown).
